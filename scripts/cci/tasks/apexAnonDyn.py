import os
from cumulusci.core.exceptions import (
    ApexCompilationException,
    ApexException,
    SalesforceException,
    TaskOptionsError,
)
from cumulusci.tasks.apex.anon import AnonymousApexTask


class ApexAnonDyn(AnonymousApexTask):
    task_options = AnonymousApexTask.task_options.copy()
    task_options.pop("param1", None)
    task_options.pop("param2", None)
    task_options["transforms"] = {
        "description": "List of find_replace transforms using env vars.",
        "required": False,
        "type": "list",  
        "default": [],
    }

    def _validate_options(self):
        super()._validate_options()
        if not self.options.get("path") and not self.options.get("apex"):
            raise TaskOptionsError(
                "You must specify either the `path` or `apex` option."
            )

    def _run_task(self):
        apex = self._process_apex_from_path(self.options.get("path"))
        apex += self._process_apex_string(self.options.get("apex"))

        apex = self._prepare_apex(apex)
        apex = self._apply_transforms(apex)

        self.logger.info("Executing anonymous Apex")
        result = self.tooling._call_salesforce(
            method="GET",
            url=f"{self.tooling.base_url}executeAnonymous",
            params={"anonymousBody": apex},
        )
        self._check_result(result)
        self.logger.info("Anonymous Apex Executed Successfully!")

    def _apply_transforms(self, apex: str) -> str:
        transforms = self.options.get("transforms") or []

        for transform in transforms:
            if transform.get("transform") != "find_replace":
                continue

            patterns = transform.get("options", {}).get("patterns", [])
            for pattern in patterns:
                find = pattern.get("find")
                env_var = pattern.get("replace_env")

                if not find or not env_var:
                    raise TaskOptionsError(
                        f"Missing `find` or `replace_env` in pattern: {pattern}"
                    )

                env_value = os.getenv(env_var)
                if env_value is None:
                    raise TaskOptionsError(
                        f"Environment variable '{env_var}' not found"
                    )

                token = f"{find}"
                if token not in apex:
                    raise TaskOptionsError(
                        f"Token '{token}' not found in Apex source"
                    )

                apex = apex.replace(token, env_value)

        return apex