#!/usr/bin/env bash
set -e

################ USAGE ################
# Assumes you're already loggedin to the CLI
# chmod +x utils/deploy/calculateFlowCoverage.sh
# utils/deploy/calculateFlowCoverage.sh PNGQA ../arn-sfdx/src/main/default

# INFO: Calculate Folow Coverage";
# FILE_PATH="$(WORK_DIR)/scripts/flow-coverage/calculateFlowCoverage.sh"
# $SF_USERNAME target-org
# $SRC_PATH WORK_DIR/force-app/main/default
# $RUN_TESTS_TYPE=ALL_LOCAL_TESTS,ONLY_LOCAL_FLOW_APEX_TESTS,NO_TESTS
# $NAMESPACE=namespace in case of package development in namespace. Otherwise, leave it empty
# $FLOW_IND_COVERAGE=Individual minimal coverage for each flow. 

################ USAGE ################

SF_USERNAME=$1
SRC_PATH=$2
RUN_TESTS_TYPE=$3
NAMESPACE=$4
FLOW_IND_COVERAGE=$5
if [[ -n "$NAMESPACE" ]]; then
  NAMESPACE="${NAMESPACE}__"
fi

FLOWS_PATH="$SRC_PATH/flows"
FLOW_COVERAGE_FOLDER="test-results-flowCoverage"
FLOW_COVERAGE_RESULT_FILE="$FLOW_COVERAGE_FOLDER/flowCoverageResults.csv"
FLOW_ELEMENTS_COVERED_FILE="$FLOW_COVERAGE_FOLDER/flowElementsCovered.csv"
FLOWS_WITH_NO_COVERAGE_FILE="$FLOW_COVERAGE_FOLDER/flowsWithNoCoverage.csv"
FLOWS_WITH_COVERAGE_FILE="$FLOW_COVERAGE_FOLDER/flowsWithCoverage.csv"
FLOW_TOTAL_COVERAGE_FILE="$FLOW_COVERAGE_FOLDER/flowTotalCoverage.csv"
FLOWS_TEMP_FILE="$FLOW_COVERAGE_FOLDER/flowsTemp.xml"

echo ""
echo "======================================="
echo "Flow Code Coverage"
echo "======================================="
echo "";

rm -rf $FLOW_COVERAGE_FOLDER/ && mkdir $FLOW_COVERAGE_FOLDER/

if [ "$RUN_TESTS_TYPE" = "ONLY_LOCAL_FLOW_APEX_TESTS" ]; then
    echo "INFO: Check flows folder to check if any flows exist or is empty"

    if [ -d "$FLOWS_PATH" ] && [ "$(ls -A "$FLOWS_PATH")" ]; then
        TEST_CLASS_STRING=""
        MASTER_LABEL_STRING=""
        SCHEDULED_TRIGGER_ID_STRING=""
        ERROR_MESSAGE_STR=""

        echo "INFO: Flows folder exists and there are flows in the folder: $FLOWS_PATH";
        echo ""
        echo "Gather flow names to identify test class names to run";

        for FILENAME_FULL_PATH in "$FLOWS_PATH"/*; do
            FILENAME=$(basename -- "$FILENAME_FULL_PATH")
            EXTENSION="${FILENAME##*.}"
            FILENAME_NO_EXTENSION="${FILENAME%.*}"
            FILENAME_NO_EXTENSION="${FILENAME_NO_EXTENSION%.*}"
            TEST_CLASS_NAME="${FILENAME_NO_EXTENSION}Test"
            echo ""
            echo "===================="
            echo "Found: $FILENAME. "
            echo "===================="


            ## replace xmlns with nothing. This will disrupt xmllint command
            perl -i -0777 -pe "s| xmlns=\"http://soap.sforce.com/2006/04/metadata\"||g" "$FILENAME_FULL_PATH"

            ## GET triggerType
            TRIGGER_TYPE=$(xmllint --xpath '//Flow/start/triggerType' $FILENAME_FULL_PATH);
            TRIGGER_TYPE="${TRIGGER_TYPE//<triggerType>/}"    
            TRIGGER_TYPE="${TRIGGER_TYPE//<\/triggerType>/ }"
            TRIGGER_TYPE="$(echo "$(sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'<<<"${TRIGGER_TYPE}")"
    )"
            echo "Trigger Type:'$TRIGGER_TYPE'"

            LABEL=$(xmllint --xpath '//Flow/label' $FILENAME_FULL_PATH);
            LABEL="${LABEL//<label>/}"    
            LABEL="${LABEL//<\/label>/ }"
            LABEL="$(echo "$(sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'<<<"${LABEL}")"
    )"
            echo "Label:'$LABEL'"

            echo "Retrive Record from Target Org"
            QUERY="SELECT Id,FullName, MasterLabel,ProcessType,Status, IsTemplate, ManageableState, RunInMode, VersionNumber,Metadata FROM Flow WHERE MasterLabel = '$LABEL' Limit 1"
            CMD=`sf data query --query "$QUERY" --target-org $SF_USERNAME --use-tooling-api -r json`
            SEARCH_RESULT="$(echo $CMD)"

            for row in $(echo "${SEARCH_RESULT}" | jq -r '.result.records[] | @base64'); do
                _jq() {
                    echo ${row} | base64 --decode | jq -r ${1}
                }
                MASTER_LABEL="$(echo $(_jq '.MasterLabel'))"
                RECORD_ID="$(echo $(_jq '.Id'))"
                FULL_NAME="$(echo $(_jq '.FullName'))"
            done
            #echo "MASTER_LABEL: $MASTER_LABEL"
            #echo "RECORD_ID: $RECORD_ID"
            #echo "FULL_NAME: $FULL_NAME"


            if [ "$TRIGGER_TYPE" == "Scheduled" ] ; then
                echo "Trigger Type is Scheduled. No Flow Test Coverage Required."
                MASTER_LABEL_STRING="${MASTER_LABEL_STRING},${MASTER_LABEL}"
                SCHEDULED_TRIGGER_ID_STRING="${SCHEDULED_TRIGGER_ID_STRING},${RECORD_ID}"
            else
                echo "Assuming test class ${TEST_CLASS_NAME}.cls exists to run."
                sf apex run test --synchronous -o $SF_USERNAME --code-coverage --result-format human --class-names "${TEST_CLASS_NAME}"
                TEST_CLASS_STRING="${TEST_CLASS_STRING},${TEST_CLASS_NAME}"
            fi
        done

        ## Remove leading comma
        TEST_CLASS_STRING="${TEST_CLASS_STRING:1}"
        MASTER_LABEL_STRING="${MASTER_LABEL_STRING:1}"
        SCHEDULED_TRIGGER_ID_STRING="${SCHEDULED_TRIGGER_ID_STRING:1}"

        echo ""
        echo "Flow Test Classes run:'$TEST_CLASS_STRING'"
        echo "Scheduled Trigger Master Label String: '$MASTER_LABEL_STRING'"
        echo "Scheduled Trigger ID String: '$SCHEDULED_TRIGGER_ID_STRING'"
    else
        echo "INFO: Flows folder does not exist or does not have flows: $SRC_PATH/flows";
        exit 0;
    fi
elif [ "$RUN_TESTS_TYPE" = "ALL_LOCAL_TESTS" ]; then
    echo "Running all local tests, inclunding Apex Tests for Apex Classes and Flows"
    sf apex run test --synchronous -o $SF_USERNAME --code-coverage --result-format human --test-level RunLocalTests
fi

echo ""
echo "========================================"
echo "Retrieving flows with 0% Code Coverage."
echo "========================================"
echo "";
QUERY="SELECT Id,MasterLabel,ProcessType,VersionNumber,FullName,Status,IsTemplate, ManageableState, RunInMode FROM Flow WHERE Status = 'Active' AND (ProcessType = 'AutolaunchedFlow' OR ProcessType = 'Workflow' OR ProcessType = 'CustomEvent' OR ProcessType = 'InvocableProcess') AND Id NOT IN ( SELECT FlowVersionId FROM FlowTestCoverage )"
#sf data query --query "$QUERY" --target-org $SF_USERNAME --use-tooling-api
sf data query --query "$QUERY" --target-org $SF_USERNAME --use-tooling-api -r csv > "$FLOWS_WITH_NO_COVERAGE_FILE"

if [ ! -s "$FLOWS_WITH_NO_COVERAGE_FILE" ] || ! grep -q '[^[:space:]]' "$FLOWS_WITH_NO_COVERAGE_FILE"; then
    echo "No flows with 0% flow coverage found, either because there are no flows or all flows have more than 0% coverage."
else
    echo "Flows with 0% flow coverage found, please check the flows and create test classes for them: "
    echo ""
    echo "";
    cat "$FLOWS_WITH_NO_COVERAGE_FILE"
    echo ""
fi

while read row; do
    ROW_ID="$(echo $row | cut -d',' -f1)"
    ROW_MASTER_LABEL="$(echo $row | cut -d',' -f2)"
    ROW_FLOWTYPE="$(echo $row | cut -d',' -f3)"
    ROW_VERSION_NUMBER="$(echo $row | cut -d',' -f4)"
    ROW_API_NAME="$(echo $row | cut -d',' -f5)"
    ROW_API_NAME_CLEAN=$(echo "$ROW_API_NAME" | sed "s/$NAMESPACE//")   

    if [[ "$ROW_ID" != "Id" && "$row" != "" && "$row" != "Your query returned no results." ]];then

        SCHEDULED_TRIGGER_QUERY="SELECT Id, ActiveVersionId, IsActive, Label, ProcessType, TriggerType from FlowDefinitionView WHERE IsActive = true AND TriggerType='Scheduled' AND ProcessType='AutoLaunchedFlow' AND ActiveVersionId = '$ROW_ID'"
        SCHEDULED_TRIGGER_CMD=`sf data query --query "$SCHEDULED_TRIGGER_QUERY" --target-org $SF_USERNAME -r json`
        SCHEDULED_TRIGGER_SEARCH_RESULT="$(echo $SCHEDULED_TRIGGER_CMD)"
        
        IS_TRIGGER_FLOW='false'
        for row in $(echo "${SCHEDULED_TRIGGER_SEARCH_RESULT}" | jq -r '.result.records[] | @base64'); do
            _jq() {
                echo ${row} | base64 --decode | jq -r ${1}
            }
            IS_TRIGGER_FLOW='true'
        done
        

        #if [ "$SCHEDULED_TRIGGER_ID_STRING" == "$ROW_ID" ] || [ "$SCHEDULED_TRIGGER_ID_STRING" == *"$ROW_ID"* ]; then
        if [ "$IS_TRIGGER_FLOW" == "true" ]; then
            echo "Skipping Scheduled Record Trigger Flow (${ROW_API_NAME_CLEAN}) which doesn't require coverage."
        else
            ERROR_MSG="\n======================================="
            ERROR_MSG="$ERROR_MSG\nERROR: Please create Apex Class (with name ${ROW_API_NAME_CLEAN}Test.cls). This test class have a coverage >= $FLOW_IND_COVERAGE % on the flow it is covering for $ROW_FLOWTYPE named $ROW_MASTER_LABEL ($ROW_API_NAME_CLEAN) "
            ERROR_MSG="$ERROR_MSG\n======================================="
            echo -e $ERROR_MSG

            ERROR_MESSAGE_STR="${ERROR_MESSAGE_STR}\n${ERROR_MSG}"
            THROW_ERROR="true"
        fi
    fi
done < "$FLOWS_WITH_NO_COVERAGE_FILE"

echo ""
echo "======================================"
echo "Retrieving flows with Code Coverage to check % covered"
echo "======================================"
echo "";

QUERY="SELECT Id,MasterLabel,ProcessType,Status,FullName FROM Flow WHERE Status = 'Active' AND (ProcessType = 'AutolaunchedFlow' OR ProcessType = 'Workflow' OR ProcessType = 'CustomEvent' OR ProcessType = 'InvocableProcess') AND Id IN ( SELECT FlowVersionId FROM FlowTestCoverage )"
sf data query --query "$QUERY" --target-org $SF_USERNAME --use-tooling-api -r csv > "$FLOWS_WITH_COVERAGE_FILE"

QUERY="SELECT Id,FlowVersionId, FlowVersion.MasterLabel, FlowVersion.FullName,ApexTestClass.FullName,NumElementsCovered,NumElementsNotCovered,TestMethodName FROM FlowTestCoverage where FlowVersion.Status = 'Active'"
sf data query --query "$QUERY" --target-org $SF_USERNAME --use-tooling-api -r csv > "$FLOW_COVERAGE_RESULT_FILE"

QUERY="SELECT Id, Elementname, FlowVersionId, FlowVersion.MasterLabel, FlowVersion.FullName, FlowTestCoverageId, FlowTestCoverage.NumElementsCovered, FlowTestCoverage.NumElementsNotCovered,  FlowTestCoverage.ApexTestClass.FullName, FlowTestCoverage.TestMethodName  FROM FlowElementTestCoverage where FlowVersion.Status = 'Active'"
sf data query --query "$QUERY" --target-org $SF_USERNAME --use-tooling-api -r csv > "$FLOW_ELEMENTS_COVERED_FILE"

if [ ! -s "$FLOW_COVERAGE_RESULT_FILE" ] || ! grep -q '[^[:space:]]' "$FLOW_COVERAGE_RESULT_FILE"; then
  echo "No flows with flow coverage found, either because there are no flows or all flows have 0% coverage."
else
    #To calculate the total coverage, we need to sum the number of elements covered and not covered for each FlowVersionId, taking into account the test classes that were executed
    # and then calculate the total number of elements covered and not covered for each FlowVersionId
    # The output will be written to flowTotalCoverage.csv

    INPUT_FILE="$FLOW_ELEMENTS_COVERED_FILE"
    OUTPUT_FILE="$FLOW_TOTAL_COVERAGE_FILE"

    # Write output header
    echo "FlowVersionId,FlowVersion.MasterLabel,FlowVersion.FullName,TotalNumElementsCovered,TotalNumElementsNotCovered" > "$OUTPUT_FILE"

    # Extract header
    header=$(head -n1 "$INPUT_FILE")
    IFS=',' read -r -a columns <<< "$header"

    # Find column indexes
    get_idx() {
    for i in "${!columns[@]}"; do
        if [[ "${columns[$i]}" == "$1" ]]; then
        echo $((i+1))
        return
        fi
    done
    echo "Error: Column not found: $1" >&2
    exit 1
    }

    idx_element=$(get_idx "ElementName")
    idx_flow_version=$(get_idx "FlowVersionId")
    idx_label=$(get_idx "FlowVersion.MasterLabel")
    idx_fullname=$(get_idx "FlowVersion.FullName")
    idx_cov=$(get_idx "FlowTestCoverage.NumElementsCovered")
    idx_uncov=$(get_idx "FlowTestCoverage.NumElementsNotCovered")

    # Process with awk (BSD-compatible)
    tail -n +2 "$INPUT_FILE" | awk -F',' -v OFS=',' \
    -v idx_element="$idx_element" \
    -v idx_flow_version="$idx_flow_version" \
    -v idx_label="$idx_label" \
    -v idx_fullname="$idx_fullname" \
    -v idx_cov="$idx_cov" \
    -v idx_uncov="$idx_uncov" '
    BEGIN {
    # Use `seen` to track FlowVersionId|ElementName pairs
    }
    {
    fv_id = $idx_flow_version
    label = $idx_label
    fullname = $idx_fullname
    element = $idx_element
    cov = $idx_cov
    uncov = $idx_uncov

    key = fv_id "|" label "|" fullname
    combined_key = key "|" element

    if (!(combined_key in seen)) {
        seen[combined_key] = 1
        element_count[key]++
    }

    # Just store total (cov + uncov) once
    if (!(key in totalsum)) {
        totalsum[key] = cov + uncov
    }
    }
    END {
    for (key in element_count) {
        split(key, parts, "|")
        id = parts[1]
        label = parts[2]
        fullname = parts[3]

        covered = element_count[key]
        total = totalsum[key]
        not_covered = total - covered

        print id, label, fullname, covered, not_covered
    }
    }' >> "$OUTPUT_FILE"

    # Create output file with header
    {
        IFS= read -r header
        echo "$header,ElementNamesCovered"
    } < "$FLOW_TOTAL_COVERAGE_FILE" > "$FLOWS_TEMP_FILE"

    while read row; do
        ROW_FLOWVERSIONID="$(echo $row | cut -d',' -f1)"
        ROWFLOW_FLOW_NAME="$(echo $row | cut -d',' -f2)"
        ROWFLOW_API_NAME="$(echo $row | cut -d',' -f3)"
        ROW_NUMELEMENTSCOVERED="$(echo $row | cut -d',' -f4)"
        ROW_NUMELEMENTSNOTCOVERED="$(echo $row | cut -d',' -f5)"
        ROWFLOW_API_NAME_CLEAN=$(echo "$ROWFLOW_API_NAME" | sed "s/$NAMESPACE//") 

        if [[ "$ROW_FLOWVERSIONID" != "FlowVersionId" && "$row" != "" && "$row" != "Your query returned no results." ]];then
            # Calculate coverage
            COVERAGE=$(awk -v a="$ROW_NUMELEMENTSNOTCOVERED" -v b="$ROW_NUMELEMENTSCOVERED" 'BEGIN {print (100*(b / (b+a)))}')

            ROWEL_ELEMENT_NAMES=""
            while read rowElement; do
                ROWEL_ID="$(echo $rowElement | cut -d',' -f3)"
                ROWEL_ELEMENT_NAME="$(echo $rowElement | cut -d',' -f2)"

                if [ "$ROWEL_ID" == "$ROW_FLOWVERSIONID" ];then
                    if [[ ",${ROWEL_ELEMENT_NAMES}," != *",${ROWEL_ELEMENT_NAME},"* ]]; then
                        # first element?
                        if [[ -z ${ROWEL_ELEMENT_NAMES} ]]; then
                            ROWEL_ELEMENT_NAMES="${ROWEL_ELEMENT_NAME}"
                        else
                            ROWEL_ELEMENT_NAMES="${ROWEL_ELEMENT_NAMES},${ROWEL_ELEMENT_NAME}"
                        fi
                    fi
                fi
            done < "$FLOW_ELEMENTS_COVERED_FILE"
            ROWEL_ELEMENT_NAMES="${ROWEL_ELEMENT_NAMES:1}"

            echo "Flow '$ROWFLOW_FLOW_NAME' ($ROWFLOW_API_NAME_CLEAN) has $COVERAGE % coverage";

            if awk -v a="$COVERAGE" -v c="$FLOW_IND_COVERAGE" 'BEGIN {exit !(a < c)}'; then
                echo ""
                ERROR_MSG="\n======================================="
                ERROR_MSG="$ERROR_MSG\nERROR: Flow '$ROWFLOW_FLOW_NAME' ($ROWFLOW_API_NAME_CLEAN) has $ROW_NUMELEMENTSNOTCOVERED elements which does not have enough code coverage (expected $FLOW_IND_COVERAGE %). ($ROW_NUMELEMENTSCOVERED elements coverd)"
                ERROR_MSG="$ERROR_MSG\nElements covered in this flow are: $ROWEL_ELEMENT_NAMES"
                ERROR_MSG="$ERROR_MSG\n======================================="
                ERROR_MESSAGE_STR="${ERROR_MESSAGE_STR}\n${ERROR_MSG}"
                THROW_ERROR="true"
            fi

            # Write the row with the new column to the output file
            echo "$row,${ROWEL_ELEMENT_NAMES//,/;}" >> "$FLOWS_TEMP_FILE"

        fi
    done < "$FLOW_TOTAL_COVERAGE_FILE"

    # We overwrite the original file with the new one
    # and remove the temporary file
    mv "$FLOWS_TEMP_FILE" "$FLOW_TOTAL_COVERAGE_FILE"

fi

if [ "$THROW_ERROR" == "true" ];then
    echo "";
    echo "";
    echo "=============================================================================="
    echo "ERROR: Please fix up the Flow Code Coverage Errors below"
    echo "=============================================================================="
    echo -e $ERROR_MESSAGE_STR
    echo "";
    echo "";
    exit 200;
fi

echo "";
echo "";

exit 0;