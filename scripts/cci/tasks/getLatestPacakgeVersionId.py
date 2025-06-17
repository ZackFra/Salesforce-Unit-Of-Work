from cumulusci.core.exceptions import DependencyLookupError
from cumulusci.tasks.github.base import BaseGithubTask
from cumulusci.tasks.salesforce.BaseSalesforceApiTask import BaseSalesforceApiTask
from cumulusci.salesforce_api.utils import get_simple_salesforce_connection
from cumulusci.core.config.util import get_devhub_config


class GetLatestPacakgeVersionId(BaseSalesforceApiTask, BaseGithubTask):
    """Gets the latest package version id from a package name. Only Validated packages are supported."""

    task_options = {
        "package_name": {
            "description": "Name of the package to get the version id for",
            "required": True,
        },
        "released": {
            "description": "Whether to get the released version or Beta/Released Version",},
    }

    def _init_options(self, kwargs):
        super()._init_options(kwargs)
        self.package_name = self.options.get("package_name")
        self.released = self.options.get("released", True)

    def _run_task(self):
        version_id = self._get_version_id(self.package_name, self.released)
        self.return_values = {"version_id": version_id}

    def _get_version_id(self, package_name, released):
        """Get the latest package version id for a given package name."""

        tooling = get_simple_salesforce_connection(
            self.project_config,
            get_devhub_config(self.project_config),
            self.project_config.project__package__api_version,
            base_url="tooling",
        )

        res = tooling.query(
            f"SELECT Package2.Id, SubscriberPackageVersionId, MajorVersion, MinorVersion, PatchVersion, BuildNumber " 
            f"FROM Package2Version " 
            f"WHERE Package2.Name='{package_name}' AND IsReleased={released} AND ValidationSkipped = False " 
            f"ORDER BY CreatedDate DESC "
            f"LIMIT 1"
        )
        if res["records"]:
            latest_package_version = res["records"][0]
            self.logger.info(
                f"Latest package version id for package '{self.package_name}' is {latest_package_version['SubscriberPackageVersionId']}"
                f" with version {latest_package_version['MajorVersion']}.{latest_package_version['MinorVersion']}.{latest_package_version['PatchVersion']}.{latest_package_version['BuildNumber']}"
            )
            return latest_package_version["SubscriberPackageVersionId"]
        else:
            raise DependencyLookupError(
                f"Could not find package version id for package '{self.package_name}' and released={self.released}"
            )
