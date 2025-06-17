from cumulusci.core.tasks import BaseTask
from cumulusci.core.exceptions import TaskOptionsError, CommandException
import subprocess

class RunESLintTests(BaseTask):
    """Custom task to run ESLint scans with custom rules"""

    task_options = {
        "format": {
            "description": "Output format for ESLint report. Must be 'html', 'csv', 'junit', or 'table'.",
            "required": True,
        }
    }

    def _run_task(self):
        output_format = self.options.get("format")

        valid_formats = ("html", "csv", "junit", "table")
        if output_format not in valid_formats:
            raise TaskOptionsError(f"Invalid format. Must be one of: {', '.join(valid_formats)}")

        commands = [
            "rm -rf test-results-eslint/ && mkdir test-results-eslint/",
        ]

        # Build the main scan command
        scan_cmd = (
            'sf scanner run --target "./force-app/**/*.js" '
            '--eslintconfig "./scripts/eslint/.eslintrc.json" '
            f'--format "{output_format}" --engine "eslint-lwc" '
            '--severity-threshold "1"'
        )

        # Conditionally add --outfile
        if output_format not in ("table"):
            if output_format in ("junit"):
                scan_cmd += f' --outfile="test-results-eslint/eslint-report.xml"'
            else:
                scan_cmd += f' --outfile="test-results-eslint/eslint-report.{output_format}"'

        commands.append(scan_cmd)

        for cmd in commands:
            self.logger.info(f"Running: {cmd}")
            result = subprocess.run(cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)

            stdout_output = result.stdout.decode("utf-8")
            stderr_output = result.stderr.decode("utf-8")

            if stdout_output:
                self.logger.info(f"[stdout]\n{stdout_output}")
            if stderr_output:
                self.logger.error(f"[stderr]\n{stderr_output}")

            if result.returncode != 0:
                raise CommandException(f"Command failed with exit code {result.returncode}: {cmd}")