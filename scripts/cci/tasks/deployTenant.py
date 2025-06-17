import os
import shutil
import json
import re

from cumulusci.tasks.salesforce import DeployBundles
from cumulusci.core.exceptions import TaskOptionsError

class DeployTenant(DeployBundles):
    task_options = {
        **DeployBundles.task_options,
        "path": {
            "description": "Overridden internally with generated temp path",
            "required": False,
        },
        "path_deploy_settings": {
            "description": "Path to the JSON file containing tenant deployment settings",
            "required": True,
        },
        "path_tenant_template": {
            "description": "Path to the template folder to clone for each tenant",
            "required": True,
        },
        "transforms_tenant": {
            "description": "List of filename transforms to apply (e.g., find_replace).",
            "required": False,
        },
    }

    def _run_task(self):
        tenant_template_path = self.options["path_tenant_template"]
        path_deploy_settings = self.options["path_deploy_settings"]
        temp_path = os.path.join(os.path.dirname(tenant_template_path), "temp")

        self.logger.info(f"Loading deploy settings from: {path_deploy_settings}")
        with open(path_deploy_settings, "r") as f:
            settings = json.load(f)

        returnCode, message = self._validate_settings(settings)
        if returnCode == 0: 
            self.logger.info(message)
            return
        elif returnCode == 1:
            raise TaskOptionsError(message)

        # Prepare temp folder
        if os.path.exists(temp_path):
            self.logger.info(f"Cleaning existing temp folder: {temp_path}")
            shutil.rmtree(temp_path)
        os.makedirs(temp_path)

        # Load find_replace patterns if any
        find_replace_patterns = []
        if "transforms_tenant" in self.options and self.options["transforms_tenant"]:
            for transform_config in self.options["transforms_tenant"]:
                if transform_config.get("transform") == "find_replace":
                    patterns = transform_config.get("options", {}).get("patterns", [])
                    find_replace_patterns.extend(patterns)

        tenants = settings.get("tenants", [])
        self.logger.info(f"Cloning template for each tenant into: {temp_path}")
        for tenant in tenants:
            tid = tenant["tenantId"]
            safe_id = tid.replace(" ", "_")
            tenant_path = os.path.join(temp_path, safe_id)
            shutil.copytree(tenant_template_path, tenant_path)

            for root, dirs, files in os.walk(tenant_path, topdown=False):
                for filename in files:
                    new_filename = filename
                    for pattern in find_replace_patterns:
                        find_str = pattern["find"]
                        replace_env = pattern["replace_env"]
                        env_var_name = f"TEN_{tid}__{replace_env}"
                        env_val = os.environ.get(env_var_name)
                        if env_val:
                            new_filename = new_filename.replace(find_str, env_val)
                        else:
                            self.logger.warning(
                                f"Env var '{env_var_name}' not found for replacement in {filename}"
                            )

                    # Rename file if needed
                    old_path = os.path.join(root, filename)
                    new_path = os.path.join(root, new_filename)
                    if new_filename != filename:
                        self.logger.info(f"Renaming: {filename} → {new_filename}")
                        os.rename(old_path, new_path)
                    else:
                        new_path = old_path

                    # Replace content in file
                    try:
                        with open(new_path, "r", encoding="utf-8") as f:
                            content = f.read()
                    except UnicodeDecodeError:
                        self.logger.debug(f"Skipping binary file: {new_path}")
                        continue

                    original_content = content
                    for pattern in find_replace_patterns:
                        find_str = pattern["find"]
                        replace_env = pattern["replace_env"]
                        env_var_name = f"TEN_{tid}__{replace_env}"
                        env_val = os.environ.get(env_var_name)
                        if env_val:
                            content = content.replace(find_str, env_val)
                        else:
                            self.logger.warning(
                                f"Env var '{env_var_name}' not found for replacement in {new_path}"
                            )

                    if content != original_content:
                        self.logger.info(f"Updated content in: {new_path}")
                        with open(new_path, "w", encoding="utf-8") as f:
                            f.write(content)

        # Set dynamic deploy path
        self.options["path"] = os.path.relpath(temp_path, os.getcwd())
        super()._run_task()

    def _validate_settings(self, settings):

        tenants = settings.get("tenants", [])
        if not tenants:
            return  0, "No tenants found in deployment settings. Skipping deployment."
        
        # Validate uniqueness of tenantIds
        tenant_ids = [c["tenantId"] for c in tenants]
        if len(tenant_ids) != len(set(tenant_ids)):
            return  1, "Duplicate tenantId found in deploy settings."
        
        #Validate mandatory tenant fields
        for tenant in tenants:
            if not tenant.get("tenantId"):
                return  1, "tenantId is mandatory for each tenant."
            if not tenant.get("tenantCode"):
                return  1, "customerSettings is mandatory for each tenant."
            
        return None, None