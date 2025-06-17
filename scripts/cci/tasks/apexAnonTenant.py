import os
import json
from pathlib import Path
from cumulusci.core.exceptions import TaskOptionsError
from scripts.cci.tasks.apexAnonDyn import ApexAnonDyn  # Assuming correct path

class ApexAnonTenant(ApexAnonDyn):
    task_options = ApexAnonDyn.task_options.copy()
    task_options["path_deploy_settings"] = {
        "description": "Path to JSON file containing tenant configuration.",
        "required": True,
    }
    task_options["transforms_tenant"] = {
        "description": "Find/replace transforms for tenant-specific placeholders.",
        "required": False,
        "type": "list",
        "default": [],
    }

    def _run_task(self):
        path_json = Path(self.options["path_deploy_settings"])
        if not path_json.is_file():
            raise TaskOptionsError(f"File not found: {path_json}")

        with open(path_json) as f:
            config = json.load(f)

        tenants = config.get("tenants", [])
        if not tenants:
            self.logger.warning("No tenants found in JSON. Skipping execution.")
            return

        for tenant in tenants:
            apex = self._process_apex_from_path(self.options.get("path"))
            apex += self._process_apex_string(self.options.get("apex"))
            apex = self._prepare_apex(apex)
            apex = self._apply_transforms(apex)
            apex = self._apply_tenant_transforms(apex, tenant)

            self.logger.info(f"Executing Apex for tenant: {tenant.get('tenantCode')}")
            result = self.tooling._call_salesforce(
                method="GET",
                url=f"{self.tooling.base_url}executeAnonymous",
                params={"anonymousBody": apex},
            )
            self._check_result(result)

        self.logger.info("All tenant Apex executions completed.")

    def _apply_tenant_transforms(self, apex: str, tenant: dict) -> str:
        transforms = self.options.get("transforms_tenant") or []

        for transform in transforms:
            if transform.get("transform") != "find_replace":
                continue

            patterns = transform.get("options", {}).get("patterns", [])
            for pattern in patterns:
                find = pattern.get("find")
                attribute_name = pattern.get("replace_env")

                tenant_code = tenant.get("tenantCode")
                tenant_id = tenant.get("tenantId")
                tenant_settings = tenant.get("tenantSettings", {})

                if not tenant_id or not attribute_name:
                    raise TaskOptionsError("Missing tenantCode or replace_env in pattern")

                env_var = f"TEN_{tenant_id}__{attribute_name}"
                env_value = os.getenv(env_var)
                if env_value is None:
                    raise TaskOptionsError(f"Missing environment variable: {env_var}")

                if find not in apex:
                    raise TaskOptionsError(f"Token '{find}' not found in Apex source")

                apex = apex.replace(find, env_value)

        return apex