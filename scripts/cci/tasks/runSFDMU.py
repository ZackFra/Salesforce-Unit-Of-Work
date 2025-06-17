

from cumulusci.core.config import ScratchOrgConfig
from cumulusci.core.tasks import BaseSalesforceTask
from cumulusci.tasks.sfdx import SFDXBaseTask

SFDX_CLI = "sf"


class RunSfdmu(SFDXBaseTask, BaseSalesforceTask):
    """Call the sfdx cli with a workspace username"""

    task_options = {
        "source": {
            "description": "Source. Can be current default Org (ORG), local csv files (csvfile), or a Salesforce Username",
            "required": True,
        },"target": {
            "description": "Target. Can be current default Org (ORG), local csv files (csvfile), or a Salesforce Username",
            "required": True,
        },"export_json_path": {
            "description": "Location of the export.json file",
            "required": True,
        }
    }

    def _get_command(self):
        command = super()._get_command()
        source = self.options.get("source")
        target = self.options.get("target")
        export_json_path = self.options.get("export_json_path")

        command += " --path {export_json_path}".format(export_json_path=export_json_path)

        # For scratch orgs, just pass the username in the command line
        if isinstance(self.org_config, ScratchOrgConfig):
            if source == "ORG":
                command += " --sourceusername {username}".format(username=self.org_config.username)
            elif source == "csvfile":
                command += " --sourceusername csvfile"
            else:
                command += " --sourceusername {source}".format(source=source)

            if target == "ORG":
                command += " --targetusername {username}".format(username=self.org_config.username)
            elif target == "csvfile":
                command += " --targetusername csvfile"
            else:
                command += " --targetusername {target}".format(target=target)
        return command

    def _get_env(self):
        env = super(RunSfdmu, self)._get_env()
        if not isinstance(self.org_config, ScratchOrgConfig):
            # For non-scratch keychain orgs, pass the access token via env var
            env["SF_ORG_INSTANCE_URL"] = self.org_config.instance_url
            env["SF_TARGET_ORG"] = self.org_config.access_token
        return env
