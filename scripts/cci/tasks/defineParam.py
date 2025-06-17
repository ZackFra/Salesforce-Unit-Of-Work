from cumulusci.core.tasks import BaseTask

class DefineParam(BaseTask):
    task_options = {
        "input": {
            "description": "Allows to set an output parameter that cane be used in other tasks and flows",
            "required": True,
        }
    }

    def _run_task(self):
        input_value = self.options["input"]
        self.logger.info(f"Setting output to: {input_value}")
        
        # Set the output
        self.return_values = {
            "value": input_value
        }