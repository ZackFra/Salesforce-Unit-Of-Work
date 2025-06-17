from pathlib import Path
from cumulusci.tasks.command import Command
import json
import os
import xml.etree.ElementTree as ET


class SfFlowScan(Command):
    task_options = {
        "src_path": {
            "description": "Path to the source input for sf flow scan.",
            "required": True,
        },
        "destination_path": {
            "description": "Path where the output should be saved.",
            "required": True,
        },
        "configuration_file": {
            "description": "Path to the configuration file for sf flow scan.",
            "required": True,
        },
    }

    def _run_task(self):
        src_path = self.options["src_path"]
        destination_path = self.options["destination_path"]
        configuration_file = self.options["configuration_file"]

        os.makedirs(destination_path, exist_ok=True)
    
        self.options['command'] = f"sf flow scan -c {configuration_file} -d {src_path} --failon never --json > {destination_path}/scanner.json"
        # Execute the command
        super()._run_task()
        file_path = Path(f"{destination_path}/scanner.json")
        self.logger.info(f"file, {file_path}")
        if file_path.is_file() :
            # Read the JSON output
            try:
                self.logger.info(f"inside")

                with open(f"{destination_path}/scanner.json", "r") as f:
                    data = json.load(f)
            except Exception as e:
                self.logger.error(f"Failed to read JSON output: {e}")
                raise

            # generate JUnit XML from data
            junit_xml = self._generate_junit_xml(data)

            # Write the JUnit XML
            xml_output_path = "flowscan-report.xml"
            self.logger.error(f"xml_output_path: {xml_output_path}")
            try:
                with open(os.path.join(destination_path,xml_output_path), "w") as f:
                    f.write(junit_xml)
                self.logger.info(f"JUnit XML saved to {xml_output_path}")
            except Exception as e:
                self.logger.error(f"Failed to write JUnit XML: {e}")
                raise

            if(data["result"]["summary"]["results"] != None and data["result"]["summary"]["results"] != 0):
                raise Exception("Violations found in flow scan. Please review them in Tests tab of the scanner report.")
        else:
            raise Exception("Execution failed. Couldn't found the scanner.json file. Please contact devOps team.")

    def _generate_junit_xml(self, data):
      
            testsuites = ET.Element('testsuites')

            results = data.get('result', {}).get('results', [])
          
            flowApiNames = [items.get('flowApiName') for items in results]
            flowApiNamesSet = list(dict.fromkeys(flowApiNames))
            
            for testsuiteItem in flowApiNamesSet:
                testsuite = ET.SubElement(testsuites, 'testsuite')
                testsuite.attrib['name'] = testsuiteItem
                # self.logger.error(f"testsuiteItem: {testsuiteItem}")
                for testcaseItem in results:
                    if testsuiteItem == testcaseItem.get('flowApiName'):
                        testcase = ET.SubElement(testsuite, 'testcase')
                        testcase.attrib['classname'] = testcaseItem.get('flowApiName')
                        testcase.attrib['name'] = testcaseItem.get('rule')
                                            
                        failure = ET.SubElement(testcase, 'failure')
                      
                        failure.attrib['message'] = testcaseItem.get('rule')
                        failure.text = f"\n Flow Element : {testcaseItem.get('violation',{}).get('element',{}).get('name','')}"
                        failure.text += f"\n Description : {testcaseItem.get('ruleDescription')}"
                        failure.text +=f"\n Severity: {testcaseItem.get('severity')}"
                        
                        # Create the tree and write it to a string
                        tree = ET.ElementTree(testsuites)
                        
                        ET.indent(tree, space="\t", level=0)
                        
            return ET.tostring(testsuites, encoding='unicode')