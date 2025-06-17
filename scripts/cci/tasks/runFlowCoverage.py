import subprocess
import csv
import os
from pathlib import Path
from cumulusci.tasks.sfdx import SFDXOrgTask
import xml.etree.ElementTree as ET


class runFlowCoverage(SFDXOrgTask):
    task_options = {
        "src_path": {
            "description": "Path to the source code folder",
            "required": True,
        },
        "run_tests_type": { 
            "description": "Type of test execution (ALL_LOCAL_TESTS - to run all local tests, ONLY_LOCAL_FLOW_APEX_TESTS - to run only flow apex tests based on naming convention on the flows present locally, NO_TESTS - will not run tests and instead query coverage from last apex test execution)",
            "required": True,
        },
        "script_path": {
            "description": "Path to the flow coverage script to run. Usually in the form of ./scripts/flow-coverage/calculateFlowCoverage.sh",
            "required": True,
        },
        "namespace": {
            "description": "Namespace of the package to be used so it can be stripped from the queroes done in Salesforce",
            "required": False,
        },
        "flow_individual_coverage": {
            "description": "Minimal individual flow coverage to be considered as a pass, for each flow ",
            "required": True,
        }
    } 

    def _run_task(self):
        destFilePath = "test-results-flowCoverage"
        file_path_flow_with_no_coverage = Path(f"{destFilePath}/flowsWithNoCoverage.csv")
        file_path_flow_with_coverage = Path(f"{destFilePath}/flowsWithCoverage.csv")
        file_path_flow_total_covered = Path(f"{destFilePath}/flowTotalCoverage.csv")
        extracted_data = []
        username = self.org_config.username
        src_path = self.options["src_path"]
        run_tests_type = self.options["run_tests_type"]
        script_path = self.options["script_path"]
        namespace = self.options["namespace"] if "namespace" in self.options else ""
        flow_individual_coverage = self.options["flow_individual_coverage"]
        error_info = None

        cmd = [
            "bash",
            script_path,
            username,
            src_path,
            run_tests_type,
            namespace,
            flow_individual_coverage
        ]

        self.logger.info(f"Running flow coverage script with the following inputs - this might take a few minutes...: {cmd}")

        try:
            result = subprocess.run(
                cmd,
                check=False,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
            )
            if result.returncode != 0:
                error_info = {
                    "returncode": result.returncode,
                    "stdout": result.stdout,
                    "stderr": result.stderr,
                }
            else:
                self.logger.info(result.stdout)
                

            if  file_path_flow_with_no_coverage.is_file() :
                flowsWithoutCoverage = self.extract_ids_with_labels(file_path_flow_with_no_coverage)
            else:
                flowsWithoutCoverage = {}
         
            if file_path_flow_with_coverage.is_file() :
                flowsCoverage = self.extract_ids_with_labels(file_path_flow_with_coverage)
            else:
                flowsCoverage = {}
             
            merged_all_flow_data = {**flowsCoverage, **flowsWithoutCoverage}
            if merged_all_flow_data == {}:
                self.logger.info("No flows found in the org.")
                return
           
            if file_path_flow_total_covered.is_file() :
                extracted_data = self.extract_flow_coverage_data(file_path_flow_total_covered, merged_all_flow_data)
                
                # Write the JUnit XML
                junit_xml = self._generate_junit_xml(extracted_data, flow_individual_coverage)

            
            xml_output_path = "flowscoverage-report.xml"
            try:
                with open(os.path.join(destFilePath,xml_output_path), "w") as f:
                    f.write(junit_xml)
                self.logger.info(f"JUnit XML saved to {os.path.join(destFilePath,xml_output_path)}")
            except Exception as e:
                self.logger.error(f"Failed to write JUnit XML: {e}")
                raise
           
            if error_info["returncode"] == 200:
                self.logger.error(error_info['stdout'])
                raise Exception("Some flows have coverage below the threshold. Please check the report for details.")
            elif error_info["returncode"] != 200:
                self.logger.error(error_info['stdout'])
                self.logger.error("STDERR:")
                self.logger.error(error_info['stderr'])
                raise Exception("There was an error running the flow coverage script. Please contact devOps team.")

        except subprocess.CalledProcessError as e :      
            self.logger.error("An error occurred during the flow coverage task.")
            self.logger.exception(e)
            raise


    def extract_ids_with_labels(self, file_path):
        id_label_map = {}
        with open(file_path, mode='r', encoding='utf-8-sig') as file:
            reader = csv.DictReader(file)
            for row in reader:
                flow_id = row.get('Id')
                label = row.get('FullName')
                if flow_id and label:
                    id_label_map[flow_id] = label
        return id_label_map

    def extract_flow_coverage_data(self, csv_file_path, merged_dict):
        results = {}
        with open(csv_file_path, mode='r', encoding='utf-8-sig') as file:
            reader = csv.DictReader(file)
            for row in reader:
                flow_id = row.get('FlowVersionId')
                if flow_id in merged_dict.keys():
                        extracted_data = {'Id': flow_id}
                        extracted_data['TotalNumElementsNotCovered'] = row.get('TotalNumElementsNotCovered')
                        extracted_data['TotalNumElementsCovered'] = row.get('TotalNumElementsCovered')
                        extracted_data['Label'] = row.get('FlowVersion.FullName')
                        extracted_data['hasApexTestClass'] = True
                        if(row.get('ElementNamesCovered')):
                            elenames = row.get('ElementNamesCovered')
                            extracted_data['ElementNamesCovered'] = elenames.split(';')
                        
                        total = int(row.get('TotalNumElementsCovered')) + int(row.get('TotalNumElementsNotCovered'))
                        if total > 0:
                            extracted_data['Coverage'] = f"{int(row.get('TotalNumElementsCovered')) / total * 100}%"
                        else :
                            extracted_data['Coverage'] = "0%"
                            
                        results[flow_id] = extracted_data
           
            for Id in merged_dict:
                if Id not in results:
                    results[Id] = {
                        'Id': Id,
                        'Coverage': '0%',
                        'hasApexTestClass': False,
                        'Label' : merged_dict[Id]
                    }
            return results



    def _generate_junit_xml(self, data, flow_individual_coverage):
        testsuites = ET.Element("testsuites")
       
        for id_, eachItem in data.items(): 
            testsuite = ET.SubElement(testsuites, "testsuite")
            testsuite.attrib['name'] = eachItem.get('Label').replace(self.project_config.project__package__namespace+"__", "")+".flow-meta.xml"
            testcase = ET.SubElement(testsuite, "testcase")
            testcase.attrib['name'] = "Flow Coverage Details"
            testcase.attrib['classname'] = eachItem.get('Label').replace(self.project_config.project__package__namespace+"__", "")+".flow-meta.xml"
            elements = eachItem.get('ElementNamesCovered')
            print ('elements', elements)
            coverage =  eachItem.get('Coverage')          
            hasApexTestClass = eachItem.get('hasApexTestClass')     
            if (coverage < (flow_individual_coverage+"%") and hasApexTestClass):
                failure = ET.SubElement(testcase, "failure", message="Insufficient Coverage")
                failure.text = f"\n Flow Coverage is below threshold: {coverage}"
                failure.text += f"\n Total Number of Elements Uncovered {eachItem.get('TotalNumElementsNotCovered')}"
                failure.text += f"\n Total Number of Elements Covered {eachItem.get('TotalNumElementsCovered')}"
                failure.text += f"\n Elements Covered : {eachItem.get('ElementNamesCovered',None)}"
            elif (coverage < (flow_individual_coverage+"%") and not hasApexTestClass):
                failure = ET.SubElement(testcase, "failure", message="Insufficient Coverage")
                failure.text = f"\n This flow is not covered by any Apex Test Class. Please craete an Apex Class with name flowApiNameTest.cls and commit it to the repository. The Apex Test Class should cover at least {flow_individual_coverage}% of the elements of the flow."
            else:
                testcase.text = f"\n Flow Coverage is {coverage}"
                testcase.text += f"\n Total Number of Elements Uncovered {eachItem.get('TotalNumElementsNotCovered')}"
                testcase.text += f"\n Total Number of Elements Covered {eachItem.get('TotalNumElementsCovered')}"
                testcase.text += f"\n Elements Covered : {eachItem.get('ElementNamesCovered',None)}"
       
        tree = ET.ElementTree(testsuites)
                        
        ET.indent(tree, space="\t", level=0)
        return ET.tostring(testsuites, encoding='unicode')

    
    