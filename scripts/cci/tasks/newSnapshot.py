import json
import datetime
from cumulusci.tasks.sfdx import SFDXOrgTask

class NewSnapshot(SFDXOrgTask):
    """Create an SFDX snapshot with a dynamically generated name."""

    task_options = {
        "packageSnapshotCode": {
            "description": "The package code to include in the snapshot name.",
            "required": True,
        },
        "relativeDays": {
            "description": "Number of days relative to today to include in the snapshot name.", 
            "required": False,
        },
    }

    def _get_command(self):
        # Get options
        package_code = self.options["packageSnapshotCode"]
        relative_days = self.options.get("relativeDays")
        
        # Compute snapshot date and name
        if relative_days is not None:
            snapshot_date = (datetime.date.today() + datetime.timedelta(days=relative_days)).strftime("%Y%m%d")
            snapshot_name = f"{package_code}_{snapshot_date}"
        else:
            snapshot_name = package_code

        # Base command from parent
        command = super()._get_command()

        # Append snapshot name
        command += f" --name {snapshot_name}"
        return command
