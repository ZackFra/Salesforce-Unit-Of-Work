import os
import subprocess
from cumulusci.tasks.command import Command


class runJestTests(Command):
    """Run a command only if JS files exist inside any 'lwc' folder under source_path."""

    task_options = Command.task_options.copy()
    task_options.update({
        "source_path": {
            "description": "Root path to search for JS files inside 'lwc' folders.",
            "required": True,
        }
    })

    def _run_task(self):
        source_path = self.options["source_path"]

        if self._has_js_in_lwc(source_path):
            self.logger.info("JS files found inside an 'lwc' folder. Installing dependencies...")
            self._npm_install(source_path)
            self.logger.info("Running JEST command.")
            super()._run_task()
        else:
            self.logger.info("No JS files found inside any 'lwc' folder. Skipping command.")

    def _has_js_in_lwc(self, root_path):
        for dirpath, dirnames, filenames in os.walk(root_path):
            # Normalize and split the directory path into components
            path_parts = dirpath.replace("\\", "/").split("/")
            if "lwc" in path_parts:
                if any(fname.endswith(".js") for fname in filenames):
                    return True
        return False
    
    def _npm_install(self, path):
        try:
            subprocess.run(["npm", "install"], cwd=path, check=True)
        except subprocess.CalledProcessError as e:
            self.logger.error(f"npm install failed with exit code {e.returncode}")
            raise