from cumulusci.tasks.github.commit_status import (
    GetPackageDataFromCommitStatus,
)
from cumulusci.core.github import get_version_id_from_commit
from cumulusci.core.exceptions import DependencyLookupError

class GetPackageDataFromCommitStatusWithCommit(GetPackageDataFromCommitStatus):
    task_options = {
        **GetPackageDataFromCommitStatus.task_options,
        "commit_id": {
            "description": "Optional commit SHA to override the default one from project config",
            "required": False,
        },
    }

    def _run_task(self):
        self.api_version = self.project_config.project__api_version
        repo = self.get_repo()
        context = self.options["context"]
        # Use user-supplied commit_id if present, else fall back to project_config
        commit_sha = self.options.get("commit_id") or self.project_config.repo_commit

        dependencies = []
        version_id = self.options.get("version_id")
        if version_id is None:
            try:
                version_id = get_version_id_from_commit(repo, commit_sha, context)
            except DependencyLookupError as e:
                self.logger.error(e)
                self.logger.error(
                    "This error usually means your local commit has not been pushed "
                    "or that a feature test package has not yet been built."
                )

        if version_id:
            dependencies = self._get_dependencies(version_id)
        else:
            raise DependencyLookupError(
                f"Could not find package version id in '{context}' commit status for commit {commit_sha}."
            )

        self.return_values = {"dependencies": dependencies, "version_id": version_id}