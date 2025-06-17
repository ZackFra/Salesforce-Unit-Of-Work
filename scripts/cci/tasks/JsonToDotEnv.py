from cumulusci.core.tasks import BaseTask
import os
import json

class JsonToDotEnv(BaseTask):
    task_options = {
        "json_path": {
            "description": "Path to the JSON file",
            "required": True,
        },
        "env_path": {
            "description": "Optional path to the .env output file. Defaults to './.env'",
            "required": False,
        }
    }

    def _run_task(self):
        json_path = self.options["json_path"]
        output_file = self.options.get("env_path", ".env")

        self.logger.info(f"Loading settings from JSON: {json_path}")
        self.logger.info(f"Writing environment variables to: {output_file}")

        try:
            with open(json_path, "r") as f:
                data = json.load(f)

            env_lines = []

            # Process orgSettings
            org_settings = data.get("orgSettings")
            if not isinstance(org_settings, dict):
                raise ValueError("'orgSettings' must be a JSON object at the root level.")

            for key, value in org_settings.items():
                if isinstance(value, (str, int, float, bool)) or value is None:
                    str_value = str(value)
                    os.environ[key] = str_value

                    display_value = str_value
                    self.logger.info(f"Set env var: {key}={display_value}")

                    safe_value = str_value.replace('"', '\\"').replace('\n', '\\n')
                    env_lines.append(f'export {key}="{safe_value}"')
                else:
                    self.logger.debug(f"Skipping nested orgSettings key: {key}")

            # Process tenants array
            tenants = data.get("tenants", [])
            if not isinstance(tenants, list):
                self.logger.warning("'tenants' is not a list. Skipping tenant settings.")
            else:
                for tenant in tenants:
                    tenant_id = tenant.get("tenantId")
                    tenant_code = tenant.get("tenantCode")
                    settings = tenant.get("tenantSettings", {})

                    if not tenant_id:
                        self.logger.warning(f"Skipping tenant entry without 'tenantId': {tenant}")
                        continue
                    if not tenant_code:
                        self.logger.warning(f"Skipping tenant entry without 'tenantCode': {tenant}")
                        continue
                    if not isinstance(settings, dict):
                        self.logger.debug(f"Skipping tenant '{tenant_id}' due to invalid 'tenantsettings'.")
                        continue

                    for attr, val in settings.items():
                        if isinstance(val, (str, int, float, bool)) or val is None:
                            env_key = f"TEN_{tenant_id}__{attr}"
                            str_val = str(val)
                            os.environ[env_key] = str_val

                            display_val = str_val
                            self.logger.info(f"Set env var: {env_key}={display_val}")

                            safe_val = str_val.replace('"', '\\"').replace('\n', '\\n')
                            env_lines.append(f'export {env_key}="{safe_val}"')
                        else:
                            self.logger.debug(f"Skipping nested/non-primitive setting: {tenant_id}.{attr}")

            # Ensure output directory exists
            os.makedirs(os.path.dirname(output_file) or ".", exist_ok=True)

            # Write env file
            with open(output_file, "w") as env_file:
                env_file.write("\n".join(env_lines) + "\n")

        except Exception as e:
            self.logger.error(f"Failed to process JSON file '{json_path}': {e}")
            raise