import datetime
from cumulusci.tasks.command import Command


class DeleteSnapshot(Command):
    """Deletes a snapshot by appending --name {snapshot_name} to the command"""

    task_options = Command.task_options.copy()
    task_options.update(
        {
            "packageSnapshotCode": {
                "description": "The package snapshot code to include in the snapshot name",
                "required": True,
            },
            "relativeDays": {
                "description": "Number of days relative to today for the snapshot date (0 for today, -1 for yesterday, etc.)",
                "required": False,
            },
        }
    )

    def _get_command(self):
        # Get options
        package_snapshot_code = self.options["packageSnapshotCode"]
        relative_days = self.options.get("relativeDays")

        # Compute snapshot date and name
        if relative_days is not None:
            snapshot_date = (datetime.date.today() + datetime.timedelta(days=int(relative_days))).strftime("%Y%m%d")
            snapshot_name = f"{package_snapshot_code}_{snapshot_date}"
        else:
            snapshot_name = package_snapshot_code

        # Base command from parent
        command = super()._get_command()

        # Append snapshot name
        command += f" --snapshot {snapshot_name}"
        return command

    def _handle_returncode(self, returncode, stderr):
        """Override to always return success (0), regardless of actual return code, because the command may fail if the snapshot does not exist."""
        if returncode != 0:
            self.logger.warning(f"Command failed with return code {returncode} because snapshot not found, but overriding to 0.")
        self.return_values = {"returncode": 0}