from cumulusci.tasks.create_package_version import CreatePackageVersion, PackageConfig
from pydantic import PrivateAttr
from cumulusci.core.dependencies.resolvers import get_static_dependencies, RESOLVER_CLASSES, GitHubReleaseTagResolver
from cumulusci.core.dependencies.dependencies import BaseGitHubDependency, StaticDependency, PackageVersionIdDependency, PackageNamespaceVersionDependency
from cumulusci.core.config.project_config import BaseProjectConfig
from cumulusci.core.exceptions import TaskOptionsError
from simple_salesforce import SalesforceMalformedRequest
from cumulusci.salesforce_api.utils import get_simple_salesforce_connection
from cumulusci.core.config.util import get_devhub_config
from typing import Optional, Tuple
from cumulusci.core.dependencies.github import (
    get_remote_project_config,
    get_repo,
)
from cumulusci.core.github import find_latest_release
from cumulusci.core.versions import PackageType

class CustomPackageConfig(PackageConfig):
    _real_package_name: Optional[str] = PrivateAttr(default=None)
    _package_name_suffix: Optional[str] = PrivateAttr(default=None)

class CreateTestPackageVersion(CreatePackageVersion):
    BETA_RELEASE_TAG = "latest_beta"
    RELEASE_TAG = "latest_release"

    """Creates a package version using a composed package name."""

    task_options = CreatePackageVersion.task_options.copy()
    # Remove the original package_name option
    task_options.pop("package_name", None)
    # Add the new required fields
    task_options.update({
        "real_package_name": {
            "description": "The base name of the package",
            "required": True,
        },
        "package_name_suffix": {
            "description": "The suffix to append to the package name",
            "required": True,
        }
    })

    def _init_options(self, kwargs):
        super()._init_options(kwargs)  

        real_name = self.options.get("real_package_name")
        suffix = self.options.get("package_name_suffix")

        # Update package name in package_config
        package_config = getattr(self, "package_config", None)
        if package_config:
            package_config.package_name = f"{real_name} {suffix}"

        if isinstance(self.package_config, PackageConfig):
            package_dict = self.package_config.dict()
            custom_config = CustomPackageConfig(**package_dict)
            custom_config._real_package_name = real_name
            custom_config._package_name_suffix = suffix
            self.package_config = custom_config

        # Continue with parent class logic
        super(CreatePackageVersion, self)._init_options(self.options)

    def _get_dependencies(self):
        """Override to inject custom resolver."""
        # 🔁 Replace resolver temporarily
        original_resolver_beta = RESOLVER_CLASSES.get(self.BETA_RELEASE_TAG)
        RESOLVER_CLASSES[self.BETA_RELEASE_TAG] = CustomGitHubReleaseTagResolver

        original_resolver_release = RESOLVER_CLASSES.get(self.RELEASE_TAG)
        RESOLVER_CLASSES[self.RELEASE_TAG] = CustomGitHubBetaTagResolver

        try:
            # Resolve dependencies into SubscriberPackageVersionIds (04t prefix)
            dependencies = get_static_dependencies(
                self.project_config,
                resolution_strategy=self.options.get("resolution_strategy") or "production",
            )
        finally:
            # ♻️ Restore original to avoid side effects
            RESOLVER_CLASSES[self.BETA_RELEASE_TAG] = original_resolver_beta
            RESOLVER_CLASSES[self.RELEASE_TAG] = original_resolver_release

        # If any dependencies are expressed as a 1gp namespace + version,
        # convert those to 04t package version ids
        if self._has_1gp_namespace_dependency(dependencies):
            dependencies = self.org_config.resolve_04t_dependencies(dependencies)

        # Convert dependencies to correct format for Package2VersionCreateRequest
        dependencies = self._convert_project_dependencies(dependencies)

        # Build additional packages for local unpackaged/pre
        dependencies = self._get_unpackaged_pre_dependencies(dependencies)

        return dependencies
    
class CustomGitHubReleaseTagResolver(GitHubReleaseTagResolver):

    #We overwrite resolve to add logic to resolve dependencies for TEST package versions
    def resolve(
        self, dep: BaseGitHubDependency, context: BaseProjectConfig
    ) -> Tuple[Optional[str], Optional[StaticDependency]]:

        repo = get_repo(dep.github, context)
        release = find_latest_release(repo, include_beta=self.include_beta)
        tag = repo.tag(repo.ref(f"tags/{release.tag_name}").object.sha)
        ref = tag.object.sha
        package_config = get_remote_project_config(repo, ref)

        self.tooling = get_simple_salesforce_connection(
            context,
            get_devhub_config(context),
            api_version=context.project__package__api_version,
            base_url="tooling",
        )
        package_name, namespace = self.custom_get_package_data(package_config)
        version_id, package_type, version_number = self.custom_get_package_version_id(package_config)

        install_unmanaged = (
            dep.is_unmanaged  # We've been told to use this dependency unmanaged
            or not (
                # We will install managed if:
                namespace  # the package has a namespace
                or version_id  # or is a non-namespaced Unlocked Package
            )
        )

        if install_unmanaged:
            return ref, None
        else:
            if package_type is PackageType.SECOND_GEN:
                package_dep = PackageVersionIdDependency(
                    version_id=version_id,
                    version_number=version_number,
                    package_name=package_name,
                )
            else:
                package_dep = PackageNamespaceVersionDependency(
                    namespace=namespace,
                    version=version_number,
                    package_name=package_name,
                    version_id=version_id,
                )
            return (ref, package_dep)

        return (None, None)
    
    def custom_get_package_data(self, config: BaseProjectConfig):
        namespace = config.project__package__namespace
        package_name = config.project__package__name + " " + "Test"

        return package_name, namespace
        
    def custom_get_package_version_id(self, config: BaseProjectConfig):
        query = (
            f"SELECT SubscriberPackageVersionId, IsReleased, MajorVersion, MinorVersion, PatchVersion, BuildNumber "
            f"FROM Package2Version "
            f"WHERE Package2.Name='" + config.project__package__name + " " + "Test' "
            f"and ValidationSkipped = false " 
            f"order by CreatedDate DESC"
        )

        try:
            res = self.tooling.query(query)
        except SalesforceMalformedRequest as err:
            if "Object type 'Package2' is not supported" in err.content[0]["message"]:
                raise TaskOptionsError(
                    "This org does not have a Dev Hub with 2nd-generation packaging enabled. "
                    "Make sure you are using the correct org and/or check the Dev Hub settings in Setup."
                )
            raise  # pragma: no cover
        if res["size"] > 1:
            raise TaskOptionsError(
                f"Found {res['size']} packages with the same name, namespace, and package_type"
            )
        if res["size"] == 0:
            raise TaskOptionsError(
                f"No TEST package versions found"
            )
            
        package2_version = res["records"][0]
        return package2_version["SubscriberPackageVersionId"], "2GP",str(package2_version["MajorVersion"])+"."+str(package2_version["MinorVersion"])+"."+str(package2_version["PatchVersion"])+"."+str(package2_version["BuildNumber"])

class CustomGitHubBetaTagResolver(CustomGitHubReleaseTagResolver):
    """Resolver that identifies a ref by finding the latest GitHub release, including betas."""

    name = "GitHub Release Resolver (Betas)"
    include_beta = True