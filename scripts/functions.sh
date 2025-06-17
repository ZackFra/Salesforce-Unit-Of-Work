#!/bin/bash

# "=========================================================================================================="
# "THIS .SH FILE IS USED TO STORE FUNCTIONS THAT CAN BE USED AROUND THE SCRIPTS IN THE PIPELINE"
# "=========================================================================================================="

CARRIAGE_RETURN=$'\r'

# retry function
# Retry command to combat bitbucket timeout errors 
retry() {
  local n=0
  local max=10
  local delay=10
  while true; do
    "$@" && break || {
      if [[ $n -lt $max ]]; then
        ((n++))
        echo "Attempt $n/$max ..."
        sleep $delay;
      else
        echo "Reached maximum number of retries ($max), exiting."
        break
      fi
    }
  done
}

print_ElapsedTime_H1() {
    local start_time=$1
    local description=$2
    local end_time=$SECONDS
    local elapsed_time=$(( end_time - start_time ))
    # Calculate minutes and seconds
    local minutes=$(( elapsed_time / 60 ))
    local seconds=$(( elapsed_time % 60 ))
    MSG="Elapsed time for '$description': $minutes minute(s) and $seconds second(s)"
    print_H2 "$MSG"
    ELAPSEDTIME_STRING="${ELAPSEDTIME_STRING}\n${MSG}"  # Append message to ELAPSEDTIME_STRING
    echo "##[endgroup]"
}

print_ElapsedTime() {
    local start_time=$1
    local description=$2
    local end_time=$SECONDS
    local elapsed_time=$(( end_time - start_time ))
    # Calculate minutes and seconds
    local minutes=$(( elapsed_time / 60 ))
    local seconds=$(( elapsed_time % 60 ))
    MSG="Elapsed time for '$description': $minutes minute(s) and $seconds second(s)"
    print_H2 "$MSG"
    ELAPSEDTIME_STRING="${ELAPSEDTIME_STRING}\n${MSG}"  # Append message to ELAPSEDTIME_STRING
}

print_H1() {
    local message="$1"
    echo " "
    echo "=======================================================================================";
    echo "##[group]${message}"; 
    echo "=======================================================================================";
}
print_H2() {
    local message="$1"
    echo " "
    echo "============================================================";
    echo "$message"; 
    echo "============================================================";
}
print_H3() {
    local message="$1"
    echo " "
    echo "-----------------------";
    echo "$message"; 
    echo "-----------------------";
}
print_ERRSTYLE() {
    local message="$1"
    echo " "
    echo "############################################################";
    echo "$message"; 
    echo "############################################################";
    echo " "
}
handle_error() {
    error_message=$1
    echo "Caught an error: $error_message"
    ERROR_CAUGHT=true
    ERROR_DETAILS="$error_message"
    MSG_STRING="${MSG_STRING}\nError: ${ERROR_DETAILS}"
}
# Simulate try-catch by checking the exit status of commands
try() {
    "$@"
    status=$?
    if [ $status -ne 0 ]; then
        handle_error "Command '$*' failed with status $status"
    fi
}
print_ERROR() {
    local message="$1"
    print_ERRSTYLE "Error: ${message}"   # Ensure print_H3 is defined
    THROW_ERROR=true
    MSG_STRING="${MSG_STRING}\nError: ${message}"  # Append message to MSG_STRING
}
fail_build_on_error() {
    if [ $SHOULD_THROW_ERROR = true -a $THROW_ERROR = true ]; then
        print_H1 "Error detected. Please review below errors. Exiting.";
        echo -e $MSG_STRING
        echo -e "$MSG_STRING" | while IFS= read -r line; do
            # Only process if the line is not empty
            if [ ! -z "$line" ]; then
                echo "##vso[task.logissue type=error]$line"
            fi
        done
        exit 1;
    fi
}
print_warnings() {
    if [ $THROW_ERROR = true ]; then
        print_H1 "Errors detected. Please review below errors. ";
        echo -e $MSG_STRING
        echo -e "$MSG_STRING" | while IFS= read -r line; do
            # Only process if the line is not empty
            if [ ! -z "$line" ]; then
                echo "##vso[task.logissue type=warning]$line"
            fi
        done
    fi
}


##########################
## GENERAL
##########################
trim_spaces() {
    local input_string="$1"    # Input string to be trimmed
    trimmed_string=$(trim_spaces_function "$input_string")
    trimmed_string=$(trim_spaces_function "$trimmed_string")
    echo "$trimmed_string"     # Return the trimmed string
}

trim_spaces_function() {
    local input_string="$1"    # Input string to be trimmed
    # Remove leading spaces
    local trimmed_string="${input_string#"${input_string%%[![:space:]]*}"}"
    # Remove trailing spaces
    trimmed_string="${trimmed_string%"${trimmed_string##*[![:space:]]}"}"
    echo "$trimmed_string"     # Return the trimmed string
}

# Function to convert a string to lowercase
lowercase_string() {
    local input="$1"
    input=$(trim_spaces "$input")  # First trim spaces
    echo "$input" | tr '[:upper:]' '[:lower:]'  # Then convert to lowercase
}

is_valid_string() {
    local STRING_VALUE="$1"

    # Check if STRING_VALUE is not empty and doesn't equal a carriage return
    if [ -n "$STRING_VALUE" ] && [ "$STRING_VALUE" != "$CARRIAGE_RETURN" ] && [ "$STRING_VALUE" != " " ] && [ "$STRING_VALUE" != "null" ]; then
        return 0  # Return true (success)
    else
        return 1  # Return false (failure)
    fi
}

array_to_string() {
    local -n array_ref="$1"
    local result=""
    # Loop through each value in the array and format the string
    for array_record in "${!array_ref[@]}"; do
        result+="'$array_record', "
    done
    # Remove trailing comma and space
    result="${result%, }"
    echo "$result"
}

replace_spaces_and_semicolons() {
    local inputString="$1"
    local outputString
    # Replace spaces with underscores
    outputString=${inputString// /_}
    # Replace semicolons with newlines
    outputString=${outputString//;/$'\n'}
    echo "$outputString"
}

##########################
## USERS
##########################

get_persona_field() {
    local PersonaNameRef="$1"
    local FieldNumberRef="$2"

    # Use grep and cut to extract the desired field by PersonaName and column number
    local FieldValue=$(grep "^$PersonaNameRef," "$USER_PERSONA_COMPONENTS_CSV" | cut -d',' -f"$FieldNumberRef")
    
    # Return the extracted value
    FieldValue=$(trim_spaces "$FieldValue")
    echo "$FieldValue"
}

print_arr_names() {
    if [ -z "$1" ]; then
        return
    fi

    local title="$1"
    shift  # Shift to get the next argument (the associative array)
    local -n array_ref="$1"  # Use nameref to refer to the associative array

    print_H2 "Collected $title"
    for name in "${!array_ref[@]}"; do
        echo "$title: '$name'"
    done
}


# USERS UPLOAD CSV
users_list_csv_header() {
    echo "FirstName,LastName,User Name, Email Address,Persona" > "$USERS_LIST_CSV";
}

# Function to add a row to the CSV file
users_list_csv_add_row() {
    local FirstName="${1}"
    local LastName="${2}"
    local UserName="${3}"
    local EmailAddress="${4}"
    local Persona="${5}"

    echo "$FirstName,$LastName,$UserName,$EmailAddress,$Persona" >> "$USERS_LIST_CSV"
}

active_users_csv_header() {
    echo "Id,nmspc_test__User_Persona__c,FirstName,LastName,Alias,FederationIdentifier,Username,Email,ProfileID,UserRoleID,LocaleSidKey,LanguageLocaleKey,EmailEncodingKey,TimezoneSidKey,Department,UserPermissionsMarketingUser,UserPermissionsKnowledgeUser,UserPermissionsInteractionUser,UserPermissionsSupportUser,IsActive" > "$USERS_UPLOAD_CSV";
}
deactivate_users_csv_header() {
    echo "Username,IsActive" > "$USERS_UPLOAD_CSV";
}

# Function to add a row to the CSV file
active_users_csv_add_row() {
    local Id="${1}"
    local nmspc_test__User_Persona__c="${2}"
    local FirstName="${3}"
    local LastName="${4}"
    local Alias="${5}"
    local FederationIdentifier="${6}"
    local Username="${7}"
    local Email="${8}"
    local ProfileID="${9}"
    local UserRoleID="${10}"
    local LocaleSidKey="${11}"
    local LanguageLocaleKey="${12}"
    local EmailEncodingKey="${13}"
    local TimezoneSidKey="${14}"
    local Department="${15}"
    local UserPermissionsMarketingUser="${16}"
    local UserPermissionsKnowledgeUser="${17}"
    local UserPermissionsInteractionUser="${18}"
    local UserPermissionsSupportUser="${19}"
    local IsActive="${20}"

    echo "$Id,$nmspc_test__User_Persona__c,$FirstName,$LastName,$Alias,$FederationIdentifier,$Username,$Email,$ProfileID,$UserRoleID,$LocaleSidKey,$LanguageLocaleKey,$EmailEncodingKey,$TimezoneSidKey,$Department,$UserPermissionsMarketingUser,$UserPermissionsKnowledgeUser,$UserPermissionsInteractionUser,$UserPermissionsSupportUser,$IsActive" >> "$USERS_UPLOAD_CSV"
}

deactivate_users_csv_add_row() {
    local Username="${1}"
    local IsActive="${2}"
    echo "$Username,$IsActive" >> "$USERS_UPLOAD_CSV"
}



load_permission_sets() {
    if [ -z "$1" ]; then
        print_H3 "PERMSET_STRING is empty. No Permission Sets Found for Assignment"
        return
    fi
    local STRING="$1" 
    STRING=${STRING%,}
    echo "PERMSET_STRING: $STRING"
    echo "Make new copy of Permission set assignments Apex file to transform and load"
    SOURCE_FILEPATH="$USERS_JOB_DIR/user-assign-permission-sets.apex"
    DEPLOY_FILEPATH="$USERS_JOB_DIR/user-assign-permission-sets-Update.apex"
    cp $SOURCE_FILEPATH $DEPLOY_FILEPATH
    echo "Update Tags"
    sed -i "s/{USERID_PERMSET_SET}/$STRING/g" $DEPLOY_FILEPATH
    echo "Load Assignments"
    sf apex run --target-org "$SF_USERNAME" --file $DEPLOY_FILEPATH
    echo "Done"
    
}
load_permission_set_groups() {
    if [ -z "$1" ]; then
        print_H3 "PERMSET_GROUP_STRING is empty. No Permission Set Groups found for Assignment"
        return
    fi
    local STRING="$1" 
    STRING=${STRING%,}
    echo "PERMSET_GROUP_STRING: $STRING"
    echo "Make new copy of Permission set assignments Apex file to transform and load"
    SOURCE_FILEPATH="$USERS_JOB_DIR/user-assign-permission-set-groups.apex"
    DEPLOY_FILEPATH="$USERS_JOB_DIR/user-assign-permission-set-groups-Update.apex"
    cp $SOURCE_FILEPATH $DEPLOY_FILEPATH
    echo "Update Tags"
    sed -i "s/{USERID_PERMSET_SET}/$STRING/g" $DEPLOY_FILEPATH
    echo "Load Assignments"
    sf apex run --target-org "$SF_USERNAME" --file $DEPLOY_FILEPATH
    echo "Done"
    
}
load_public_groups() {
    if [ -z "$1" ]; then
        print_H3 "PUBLIC_GROUP_STRING is empty. No Pubic Groups found for Assignment"
        return
    fi
    local STRING="$1" 
    STRING=${STRING%,}
    echo "PUBLIC_GROUP_STRING: $STRING"
    echo "Make new copy of Group assignments Apex file to transform and load"
    SOURCE_FILEPATH="$USERS_JOB_DIR/user-assign-groups.apex"
    DEPLOY_FILEPATH="$USERS_JOB_DIR/user-assign-groups-Update.apex"
    cp $SOURCE_FILEPATH $DEPLOY_FILEPATH
    echo "Update Tags"
    sed -i "s|{GROUP_STRING}|$STRING|g" $DEPLOY_FILEPATH
    echo "Load Assignments"
    sf apex run --target-org "$SF_USERNAME" --file $DEPLOY_FILEPATH
    echo "Done"
    
}
load_queues() {
    if [ -z "$1" ]; then
        print_H3 "QUEUE_STRING is empty. No Queues found for Assignment"
        return
    fi
    local STRING="$1" 
    STRING=${STRING%,}
    echo "QUEUE_STRING: $STRING"
    echo "Make new copy of Group assignments Apex file to transform and load"
    SOURCE_FILEPATH="$USERS_JOB_DIR/user-assign-groups.apex"
    DEPLOY_FILEPATH="$USERS_JOB_DIR/user-assign-groups-Update.apex"
    cp $SOURCE_FILEPATH $DEPLOY_FILEPATH
    echo "Update Tags"
    sed -i "s|{GROUP_STRING}|$STRING|g" $DEPLOY_FILEPATH
    echo "Load Assignments"
    sf apex run --target-org "$SF_USERNAME" --file $DEPLOY_FILEPATH >/dev/null
    echo "Done"
    
}



configure_aws() {

    echo "AWS Cli Version"
    aws --version

    local AWS_PROFILE_NAME="default"
    
    # Variables
    ROLE_ARN="$AWS_ROLE_ARN"
    ROLE_SESSION_NAME="DevOps"
    AWS_REGION="ap-southeast-2"

    # Set your default AWS credentials (replace with your permanent credentials)
    AWS_ACCESS_KEY_ID="$AWS_ACCESS_KEY_ID"
    AWS_SECRET_ACCESS_KEY="$AWS_SECRET_ACCESS_KEY"

    echo "AWS_ACCESS_KEY_ID: '$AWS_ACCESS_KEY_ID'"
    echo "AWS_SECRET_ACCESS_KEY: '$AWS_SECRET_ACCESS_KEY'"

    # Step 1: Configure the AWS CLI with the default profile
    aws configure set aws_access_key_id "$AWS_ACCESS_KEY_ID" --profile $AWS_PROFILE_NAME
    aws configure set aws_secret_access_key "$AWS_SECRET_ACCESS_KEY" --profile $AWS_PROFILE_NAME
    aws configure set region "$AWS_REGION" --profile $AWS_PROFILE_NAME
    aws configure set output json --profile $AWS_PROFILE_NAME


    # Assume the role
    ASSUME_ROLE_OUTPUT=$(aws sts assume-role \
    --role-arn "$ROLE_ARN" \
    --role-session-name "$ROLE_SESSION_NAME" \
    --region "$AWS_REGION" \
    --output json)

    # Check if the assume-role command was successful
    if [ $? -ne 0 ]; then
        echo "Error: Failed to assume role"
        exit 1
    fi

    # Extract credentials from the JSON output
    ACCESS_KEY_ID=$(echo $ASSUME_ROLE_OUTPUT | jq -r '.Credentials.AccessKeyId')
    SECRET_ACCESS_KEY=$(echo $ASSUME_ROLE_OUTPUT | jq -r '.Credentials.SecretAccessKey')
    SESSION_TOKEN=$(echo $ASSUME_ROLE_OUTPUT | jq -r '.Credentials.SessionToken')

    # Check if the keys were extracted successfully
    if [ -z "$ACCESS_KEY_ID" ] || [ -z "$SECRET_ACCESS_KEY" ] || [ -z "$SESSION_TOKEN" ]; then
        echo "Error: Failed to extract credentials"
        exit 1
    fi

    # Step 4: Export the temporary credentials to environment variables
    export AWS_ACCESS_KEY_ID
    export AWS_SECRET_ACCESS_KEY
    export AWS_SESSION_TOKEN

    echo "Assumed role successfully! Temporary credentials set for AWS session."
    echo "AWS_ACCESS_KEY_ID: $AWS_ACCESS_KEY_ID"
    echo "AWS_SECRET_ACCESS_KEY: $AWS_SECRET_ACCESS_KEY"
    echo "AWS_SESSION_TOKEN: $AWS_SESSION_TOKEN"

    # Step 5: Verify the credentials by making an AWS API call (e.g., getting the current identity)
    aws sts get-caller-identity

    if [ $? -eq 0 ]; then
        echo "Authenticated successfully using assumed role."
    else
        echo "Failed to authenticate with the assumed role."
    fi

}


run_apex_update_priority() {
    local USER_ID_REF=$1

    # Create a temporary file to store Apex code
    APEX_FILE=$(mktemp)

    # Write the anonymous Apex code to the temporary file
    cat <<EOF > "$APEX_FILE"
try {
    AWSUserProficienciesCallout.updateAgentPriority('$USER_ID_REF');
    System.debug('Success: Agent priority updated for user: $USER_ID_REF');
} catch (Exception e) {
    System.debug('Error: ' + e.getMessage());
}
EOF

    # Run anonymous Apex using Salesforce CLI
    APEX_RESULT=$(sf apex run -o $SF_USERNAME -f "$APEX_FILE")

    # Remove the temporary file
    rm "$APEX_FILE"

    # Check if the execution was successful
    if echo "$APEX_RESULT" | grep -q "Success"; then
        echo "Agent priority updated successfully for user: '$USER_ID_REF'."
    else
        ERROR_MESSAGE=$(echo "$APEX_RESULT" | grep "Error" | sed 's/.*Error: //')
        print_ERROR "Agent priority not updated with error: '$ERROR_MESSAGE'."
    fi

    
}

print_apex_errors() {
    local APEX_FILE=$1

    # Log the Salesforce username and Apex file being used
    echo "Executing Apex with Salesforce username: $SF_USERNAME"
    echo "Apex file: $APEX_FILE"

    # Run the sf apex run command and log it
    echo "Running: sf apex run -o $SF_USERNAME -f $APEX_FILE"
    APEX_RESULT=$(sf apex run -o $SF_USERNAME -f "$APEX_FILE")
    
    # Log the raw output of the command
    echo "Command Output:"
    echo "$APEX_RESULT"

    # Check if the execution was successful
    if echo "$APEX_RESULT" | grep -q "Error"; then
        ERROR_MESSAGE=$(echo "$APEX_RESULT" | grep "Error" | sed 's/.*Error: //')
        print_ERROR "'$ERROR_MESSAGE'."
    else
        echo "Apex executed successfully."
    fi
}

rename_user_quickconnect() {
    local USER_ID_REF=$1

    # Step 1: Retrieve the Quick connect id and name of a salesforce user.
    echo "Retrieving AWS user ARN for USER_ID_REF: $USER_ID_REF"
    USER_AWS_ARN_QUERY="SELECT ExternalId, QuickConnect, ReferenceRecord.Name, ReferenceRecord.Alias from CallCenterRoutingMap where ReferenceRecordId = '${USER_ID_REF}' LIMIT 1"
    USER_AWS_ARN_INFO=$(sf data query -o $SF_USERNAME -q "$USER_AWS_ARN_QUERY" --json)
    USER_AWS_ARN=$(echo $USER_AWS_ARN_INFO | jq -r '.result.records[0].ExternalId')
    USER_AWS_QUICKCONNECT_ID=$(echo $USER_AWS_ARN_INFO | jq -r '.result.records[0].QuickConnect')
    USER_AWS_REF_NAME=$(echo $USER_AWS_ARN_INFO | jq -r '.result.records[0].ReferenceRecord.Name')
    USER_AWS_REF_ALIAS=$(echo $USER_AWS_ARN_INFO | jq -r '.result.records[0].ReferenceRecord.Alias')

    IFS='/' read -r part1 AC_INSTANCE_ID part3 AWS_USER_ID_REF <<< "$USER_AWS_ARN"

    echo "USER_AWS_ARN: '$USER_AWS_ARN'"
    echo "AC_INSTANCE_ID: '$AC_INSTANCE_ID'"
    echo "AWS_USER_ID_REF: '$AWS_USER_ID_REF'"

    # Update Name
    UPDATE_QUICK_CONNECT_INFO=$(aws connect update-quick-connect-name --instance-id $AC_INSTANCE_ID --quick-connect-id $USER_AWS_QUICKCONNECT_ID --name "$USER_AWS_REF_NAME/$USER_AWS_REF_ALIAS" --profile default --output json)

    # Step 6: Check and print the result of the update
    if [ -z "${UPDATE_QUICK_CONNECT_INFO}" ]; then
        echo "Successfully updated name with '$USER_AWS_REF_NAME/$USER_AWS_REF_ALIAS'"
    else
        print_ERROR "Unable to update name '$USER_AWS_REF_NAME/$USER_AWS_REF_ALIAS' with reason: '$ASSIGN_QUEUE_QUICK_CONNECT_INFO'"
    fi
}

add_user_quickconnect_to_all_queues() {
    local USER_ID_REF=$1

     # Step 1: Execute the following SOQL to retrieve the Quick connect id and name of a salesforce user.
    echo "Retrieving AWS user ARN for USER_ID_REF: $USER_ID_REF"
    USER_AWS_ARN_QUERY="SELECT ExternalId, QuickConnect, ReferenceRecord.Name, ReferenceRecord.Alias from CallCenterRoutingMap where ReferenceRecordId = '${USER_ID_REF}' LIMIT 1"
    USER_AWS_ARN_INFO=$(sf data query -o $SF_USERNAME -q "$USER_AWS_ARN_QUERY" --json)
    USER_AWS_ARN=$(echo $USER_AWS_ARN_INFO | jq -r '.result.records[0].ExternalId')
    USER_AWS_QUICKCONNECT_ID=$(echo $USER_AWS_ARN_INFO | jq -r '.result.records[0].QuickConnect')
    IFS='/' read -r part1 AC_INSTANCE_ID part3 AWS_USER_ID_REF <<< "$USER_AWS_ARN"

    echo "USER_AWS_ARN: '$USER_AWS_ARN'"
    echo "AC_INSTANCE_ID: '$AC_INSTANCE_ID'"
    echo "AWS_USER_ID_REF: '$AWS_USER_ID_REF'"




    # Step 2: Execute the following AWS CLI to get the list of queue id
    echo "Get the list of queues"
    QUEUE_LIST_INFO=$(aws connect list-queues --instance-id $AC_INSTANCE_ID --no-paginate --queue-types="STANDARD" --query "QueueSummaryList[?Name!='BasicQueue'].Id" --profile default --output json)

    #echo "QUEUE_LIST_INFO: $QUEUE_LIST_INFO"

    # Iterate over the array using jq and a for loop
    for value in $(echo "$QUEUE_LIST_INFO" | jq -r '.[]'); do
        #echo "Queue: $value"
        ASSIGN_QUEUE_QUICK_CONNECT_INFO=$(aws connect associate-queue-quick-connects --instance-id $AC_INSTANCE_ID --queue-id $value --quick-connect-ids $USER_AWS_QUICKCONNECT_ID --profile default --output json)

        # Step 6: Check and print the result of the update
        if [ -z "${ASSIGN_QUEUE_QUICK_CONNECT_INFO}" ]; then
            echo "Successfully updated queue with Id: '$value'"
        else
            print_ERROR "Unable to update queue with Id: '$value' with reason: '$ASSIGN_QUEUE_QUICK_CONNECT_INFO'"
        fi
    done
}

update_user_aws_security_profile() {
    local USER_ID_REF=$1

    # Step 1: Execute SOQL to retrieve the user’s corresponding AWS user’s ARN
    echo "Retrieving AWS user ARN for USER_ID_REF: $USER_ID_REF"
    USER_AWS_ARN_QUERY="SELECT ExternalId, ReferenceRecord.Name from CallCenterRoutingMap where ReferenceRecordId = '${USER_ID_REF}' LIMIT 1"
    USER_AWS_ARN_INFO=$(sf data query -o $SF_USERNAME -q "$USER_AWS_ARN_QUERY" --json)

    USER_AWS_ARN=$(echo $USER_AWS_ARN_INFO | jq -r '.result.records[0].ExternalId')
    IFS='/' read -r part1 AC_INSTANCE_ID part3 AWS_USER_ID_REF <<< "$USER_AWS_ARN"

    echo "USER_AWS_ARN: '$USER_AWS_ARN'"
    echo "AC_INSTANCE_ID: '$AC_INSTANCE_ID'"
    echo "AWS_USER_ID_REF: '$AWS_USER_ID_REF'"

    # Step 2: Execute SOQL to retrieve User Persona and other user details
    echo "Retrieving User Persona and details for USER_ID_REF: $USER_ID_REF"
    USER_RECORD_QUERY="SELECT Id, Name, Alias, nmspc_test__User_Persona__c FROM User Where Id = '${USER_ID_REF}' LIMIT 1"
    USER_RECORD_INFO=$(sf data query -o $SF_USERNAME -q "$USER_RECORD_QUERY" --json)

    USER_PERSONA=$(echo $USER_RECORD_INFO | jq -r '.result.records[0].nmspc_test__User_Persona__c')
    USER_ALIAS=$(echo $USER_RECORD_INFO | jq -r '.result.records[0].Alias')
    USER_FIRSTLASTNAME=$(echo $USER_RECORD_INFO | jq -r '.result.records[0].Name')

    echo "USER_PERSONA: '$USER_PERSONA'"
    echo "USER_ALIAS: '$USER_ALIAS'"
    echo "USER_FIRSTLASTNAME: '$USER_FIRSTLASTNAME'"

    # Step 3: Retrieve profile mapping for AWS_PROFILE
    declare -A PROF_ARRAY
    persona_profile_mapping
    AWS_PROFILE=${PROF_ARRAY["${USER_PERSONA// /_}"]}
    echo "AWS_PROFILE: '$AWS_PROFILE'"

    if [ -z "${AWS_PROFILE}" ]; then
        print_ERROR "AWS_PROFILE is blank. Persona '$USER_PERSONA' is not found in Voice_Persona_Configuration__mdt and does not have an assigned AWS User Profile to assign user '$$USER_ID_REF'"
    fi

    # Step 4: Retrieve the security profile ID from AWS
    echo "Retrieving security profile ID for AWS_PROFILE: $AWS_PROFILE"
    USER_RECORD_INFO=$(aws connect list-security-profiles --instance-id $AC_INSTANCE_ID --query "SecurityProfileSummaryList[?Name=='$AWS_PROFILE'].Id" --no-paginate --profile default --output json)
    SECURITY_PROFILE_ID=$(echo $USER_RECORD_INFO | jq -r '.[0]')
    echo "SECURITY_PROFILE_ID: $SECURITY_PROFILE_ID"

    # Step 5: Update the user's AWS security profile
    echo "Updating AWS security profile for USER_ID_REF: $AWS_USER_ID_REF"
    AWS_UPDATE_PROFILE_INFO=$(aws connect update-user-security-profiles --instance-id $AC_INSTANCE_ID --user-id $AWS_USER_ID_REF --security-profile-ids $SECURITY_PROFILE_ID --profile default --output json)

    # Step 6: Check and print the result of the update
    if [ -z "${AWS_UPDATE_PROFILE_INFO}" ]; then
        echo "Successfully updated profile for user $USER_FIRSTLASTNAME"
    else
        print_ERROR "Unable to update profile for user $USER_FIRSTLASTNAME with reason: '$AWS_UPDATE_PROFILE_INFO'"
    fi
}


check_routing_profile() {
    local USER_ID_REF=$1

    # Get the Contact Center Group id for provisioned user, get the group id. if group member record not found for a contact in sfUserIds report an error / retry for that user.
    echo "Retrieving GroupId for USER_ID_REF: $USER_ID_REF"
    USER_CC_GROUP_QUERY="SELECT GroupId from GroupMember WHERE Group.Type = 'ContactCenterGroup' AND UserOrGroupId = '${USER_ID_REF}' LIMIT 1"
    USER_CC_GROUP_INFO=$(sf data query -o $SF_USERNAME -q "$USER_CC_GROUP_QUERY" --json)
    USER_CC_GROUP_ID=$(echo $USER_CC_GROUP_INFO | jq -r '.result.records[0].GroupId')
  
    # Get the ARN (ExternalID) for all the groups in setup 1 above, extract the routing profile id from the ARN, this give you a mapping of Contact Group (a.k.a. Routing Profile) Name to AWS routing Profile Name
    echo "Retrieving Routing Profile ID from Group ARN for GROUP ID: $USER_CC_GROUP_ID"
    GROUP_ARN_ID_QUERY="SELECT ReferenceRecordId, ExternalId FROM CallCenterRoutingMap WHERE ReferenceRecordId = '${USER_CC_GROUP_ID}' LIMIT 1"
    GROUP_ARN_ID_INFO=$(sf data query -o $SF_USERNAME -q "$GROUP_ARN_ID_QUERY" --json)
    GROUP_ARN=$(echo $GROUP_ARN_ID_INFO | jq -r '.result.records[0].ExternalId')
    IFS='/' read -r part1 AC_INSTANCE_ID part3 SF_ROUTING_PROFILE_ID <<< "$GROUP_ARN"

    echo "GROUP_ARN: '$GROUP_ARN'"
    echo "part1: '$part1'"
    echo "AC_INSTANCE_ID: '$AC_INSTANCE_ID'"
    echo "part3: '$part3'"
    echo "SF_ROUTING_PROFILE_ID: '$SF_ROUTING_PROFILE_ID'"

    # Find the ARN (ExternalId) of the user, extract the user’s id from the ARN
    echo "Retrieving AWS user ARN for USER_ID_REF: $USER_ID_REF"
    USER_AWS_ARN_QUERY="SELECT ExternalId, ReferenceRecord.Name from CallCenterRoutingMap where ReferenceRecordId = '${USER_ID_REF}' LIMIT 1"
    USER_AWS_ARN_INFO=$(sf data query -o $SF_USERNAME -q "$USER_AWS_ARN_QUERY" --json)

    USER_AWS_ARN=$(echo $USER_AWS_ARN_INFO | jq -r '.result.records[0].ExternalId')
    IFS='/' read -r part1 AC_INSTANCE_ID part3 AWS_USER_ID_REF <<< "$USER_AWS_ARN"

    echo "USER_AWS_ARN: '$USER_AWS_ARN'"
    echo "AC_INSTANCE_ID: '$AC_INSTANCE_ID'"
    echo "AWS_USER_ID_REF: '$AWS_USER_ID_REF'"

    #Use AWS CLI to describe user (See https://docs.aws.amazon.com/cli/latest/reference/connect/describe-user.html#examples for sample output, you may use --query to get the RoutingProfileId attribute only. Use the user id extracted from step #3 above.
    echo "Describe AWS User"
    DESCRIBE_AWS_USER_QUERY=$(aws connect describe-user --instance-id "$AC_INSTANCE_ID" --user-id "$AWS_USER_ID_REF" --profile default --output json)
    AWS_USER_ROUTING_PROFILE_ID=$(echo "$DESCRIBE_AWS_USER_QUERY" | jq -r '.User.RoutingProfileId')
    #echo "DESCRIBE_AWS_USER_QUERY: $DESCRIBE_AWS_USER_QUERY"
    echo ""
    echo "Check Routing profiles match"
    echo "AWS_USER_ROUTING_PROFILE_ID: $AWS_USER_ROUTING_PROFILE_ID"
    echo "SF_ROUTING_PROFILE_ID: '$SF_ROUTING_PROFILE_ID'"

    if [[ "$AWS_USER_ROUTING_PROFILE_ID" != "$SF_ROUTING_PROFILE_ID" ]]; then
        echo "Routing Profiles don't match."
        # Update the user's AWS security profile
        echo "Updating AWS User Routing profile for USER_ID_REF: $AWS_USER_ID_REF"
        AWS_UPDATE_PROFILE_INFO=$(aws connect update-user-routing-profile --instance-id $AC_INSTANCE_ID --user-id $AWS_USER_ID_REF --routing-profile-id $SF_ROUTING_PROFILE_ID --profile default --output json)

        # Check and print the result of the update
        if [ -z "${AWS_UPDATE_PROFILE_INFO}" ]; then
            echo "Successfully updated routing profile for user $USER_FIRSTLASTNAME"
        else
            print_ERROR "Unable to update routing profile for user $USER_FIRSTLASTNAME with reason: '$AWS_UPDATE_PROFILE_INFO'"
        fi
    else
        echo "Routing Profiles match."
    fi
    return
}

persona_profile_mapping() {
    echo "Retrieving Persona AWS Security profile mapping"
    SECURITY_PORIFILE_QUERY="SELECT AWS_Security_Profile__c, nmspc_test__User_Persona__c FROM Voice_Persona_Configuration__mdt"
    SECURITY_PORIFILE_RESULT=$(sf data query -o $SF_USERNAME -q "$SECURITY_PORIFILE_QUERY" --json)
    #echo "SECURITY_PORIFILE_RESULT: $SECURITY_PORIFILE_RESULT"
    
    for row in $(echo "${SECURITY_PORIFILE_RESULT}" | jq -r '.result.records[] | @base64'); do
        _jq() {
        echo ${row} | base64 --decode | jq -r ${1}
        }
        AWS_SECURITY_PROFILE_NAME="$(echo $(_jq '.AWS_Security_Profile__c'))"
        PERSONA_NAME_REF="$(echo $(_jq '.nmspc_test__User_Persona__c'))"
        SANITIZED_PERSONA_NAME="${PERSONA_NAME_REF// /_}"
        PROF_ARRAY["$SANITIZED_PERSONA_NAME"]="$AWS_SECURITY_PROFILE_NAME"
    done
}


load_delegated_admin_groups() {
    if [ -z "$1" ]; then
        print_H3 "DELEGATED_ADMIN_SET is empty. No Voice Groups found for Assignment"
        return
    fi
    local -n DELEGATED_ADMIN_SET_REF="$1"

    if [ ${#DELEGATED_ADMIN_SET_REF[@]} -eq 0 ]; then
        echo "DELEGATED_ADMIN_SET is empty"
    else 

        # Loop through the array and process each key-value pair
        for key in "${!DELEGATED_ADMIN_SET_REF[@]}"; do
            USER_ID=$(echo "$key" | cut -d'-' -f1)
            DELEGATED_ADMIN_GROUP=$(echo "$key" | cut -d'-' -f2)
            DELEGATED_ADMIN_GROUP="${DELEGATED_ADMIN_GROUP//_/ }"

            print_H2 "USER_ID: $USER_ID, DELEGATED_ADMIN_GROUP: $DELEGATED_ADMIN_GROUP"

            # Query for the DelegateGroup ID
            DELEG_ADMIN_QUERY="Select Id, Name from DelegateGroup WHERE Name = '$DELEGATED_ADMIN_GROUP' LIMIT 1"
            DELEG_ADMIN_INFO=$(sf data query -o "$SF_USERNAME" -q "$DELEG_ADMIN_QUERY" --json --use-tooling-api)
            DELEG_ADMIN_ID=$(echo "$DELEG_ADMIN_INFO" | jq -r '.result.records[0].Id')
            echo "DELEG_ADMIN_ID: $DELEG_ADMIN_ID"
            echo "USER_ID: $USER_ID"

            # Create DelegateGroupMember
            DELEG_ADMIN_CREATE_INFO=$(sf data create record --use-tooling-api --sobject DelegateGroupMember --values "DelegateGroupId=$DELEG_ADMIN_ID UserOrGroupId=$USER_ID" -o "$SF_USERNAME" --json)
            DELEG_ADMIN_CREATE_RESULT=$(echo "$DELEG_ADMIN_CREATE_INFO" | jq -r '.result')
            echo "DELEG_ADMIN_CREATE_RESULT: $DELEG_ADMIN_CREATE_RESULT"
        done
    fi
}

reset_user_passwords() {
    if [ -z "$1" ]; then
        print_H3 "No Users to reset password for"
        return
    fi
    local STRING="$1" 
    local send_password_ref="$2"
    local activity_type_ref="$3"

    echo "SEND_PASSWORD: $send_password_ref"
    echo "ACTIVITY_TYPE: $activity_type_ref"

    if [ "$send_password_ref" = "Send Password Email" ] ; then
        SOURCE_FILEPATH="$USERS_JOB_DIR/user-reset-passwords.apex"
        DEPLOY_FILEPATH="$USERS_JOB_DIR/user-reset-passwords-Update.apex"
        cp $SOURCE_FILEPATH $DEPLOY_FILEPATH
        echo "USER_ID_STRING: $STRING"
        sed -i "s|{RECORDID_LIST}|$STRING|g" $DEPLOY_FILEPATH
        try sf apex run --target-org "$SF_USERNAME" --file $DEPLOY_FILEPATH
    else
        echo "Reset Password was not executed."
    fi

}


fetch_profiles() {

    if [ -z "$2" ]; then
        return
    fi

    local SF_USERNAME="$1"
    local PROFILES_STRING="$2"

    QUERY="Select Id, Name FROM Profile WHERE Name in ($PROFILES_STRING)"
    CMD=$(sf data query --target-org "$SF_USERNAME" -r json -q "$QUERY")
    SEARCH_RESULT="$(echo "$CMD")"

    for row in $(echo "${SEARCH_RESULT}" | jq -r '.result.records[] | @base64'); do
        _jq() {
            echo "$row" | base64 --decode | jq -r "$1"
        }
        PROFILE_NAME="$(_jq '.Name')"
        REPLACE_WITH="$(_jq '.Id')"
        PROFILE_NAME=${PROFILE_NAME//[ ]/_}
        Profiles["$PROFILE_NAME"]="$REPLACE_WITH"
    done

    for record in "${!Profiles[@]}"; do
        echo "Profile: '$record', Value: '${Profiles[$record]}'"
    done
}

fetch_roles() {

    if [ -z "$2" ]; then
        return
    fi

    local SF_USERNAME="$1"
    local ROLES_STRING="$2"

    QUERY="Select Id, Name FROM UserRole WHERE Name IN ($ROLES_STRING)"
    CMD=`sf data query --target-org $SF_USERNAME -r json -q "$QUERY"`
    SEARCH_RESULT="$(echo $CMD)"

    for row in $(echo "${SEARCH_RESULT}" | jq -r '.result.records[] | @base64'); do
        _jq() {
        echo ${row} | base64 --decode | jq -r ${1}
        }
        USERROLE_NAME="$(echo $(_jq '.Name'))"
        REPLACE_WITH="$(echo $(_jq '.Id'))"
        USERROLE_NAME="${USERROLE_NAME// /_}"
        Roles["$USERROLE_NAME"]="$REPLACE_WITH"
    done

    for record in "${!Roles[@]}"; do
        echo "Role: '$record', Value: '${Roles[$record]}'"
    done
}

fetch_permission_sets() {

    if [ -z "$2" ]; then
        return
    fi

    local SF_USERNAME="$1"
    local STRING="$2"

    QUERY="Select Id, Label FROM PermissionSet WHERE IsOwnedByProfile = false AND PermissionSetGroupId = null AND Label in ($STRING)"
    CMD=`sf data query --target-org $SF_USERNAME -r json -q "$QUERY"`
    PERMSET_SEARCH_RESULT="$(echo $CMD)"

    for row in $(echo "${PERMSET_SEARCH_RESULT}" | jq -r '.result.records[] | @base64'); do
        _jq() {
        echo ${row} | base64 --decode | jq -r ${1}
        }
        PERMSET_NAME="$(echo $(_jq '.Label'))"
        TAG_NAME="{PERMSET-${PERMSET_NAME}}"
        REPLACE_WITH="$(echo $(_jq '.Id'))"
        PERMSET_NAME="${PERMSET_NAME// /_}"
        PermSet["$PERMSET_NAME"]="$REPLACE_WITH"
    done

    for record in "${!PermSet[@]}"; do
        echo "Perm Set: '$record', Value: '${PermSet[$record]}'"
    done
}

fetch_permission_set_groups() {

    if [ -z "$2" ]; then
        return
    fi

    local SF_USERNAME="$1"
    local STRING="$2"

    QUERY="Select Id, MasterLabel FROM PermissionSetGroup WHERE MasterLabel IN ($STRING)"
    CMD=`sf data query --target-org $SF_USERNAME -r json -q "$QUERY"`
    PERMSETGROUP_SEARCH_RESULT="$(echo $CMD)"

    for row in $(echo "${PERMSETGROUP_SEARCH_RESULT}" | jq -r '.result.records[] | @base64'); do
        _jq() {
        echo ${row} | base64 --decode | jq -r ${1}
        }
        PERMSET_GROUP_NAME="$(echo $(_jq '.MasterLabel'))"
        REPLACE_WITH="$(echo $(_jq '.Id'))"
        PERMSET_GROUP_NAME="${PERMSET_GROUP_NAME// /_}"
        PermSetGroup["$PERMSET_GROUP_NAME"]="$REPLACE_WITH"
    done

    for record in "${!PermSetGroup[@]}"; do
        echo "Perm Set Group: '$record', Value: '${PermSetGroup[$record]}'"
    done
}

fetch_public_groups() {

    if [ -z "$2" ]; then
        return
    fi

    local SF_USERNAME="$1"
    local STRING="$2"

    QUERY="Select Id, Name FROM Group WHERE Type = 'Regular' AND Name IN ($STRING)"
    CMD=`sf data query --target-org $SF_USERNAME -r json -q "$QUERY"`
    GROUP_SEARCH_RESULT="$(echo $CMD)"

    for row in $(echo "${GROUP_SEARCH_RESULT}" | jq -r '.result.records[] | @base64'); do
        _jq() {
        echo ${row} | base64 --decode | jq -r ${1}
        }
        GROUP_NAME="$(echo $(_jq '.Name'))"
        REPLACE_WITH="$(echo $(_jq '.Id'))"
        GROUP_NAME="${GROUP_NAME// /_}"
        Groups["$GROUP_NAME"]="$REPLACE_WITH"
    done

    for record in "${!Groups[@]}"; do
        echo "Public Group: '$record', Value: '${Groups[$record]}'"
    done
}

fetch_queues() {

    if [ -z "$2" ]; then
        return
    fi

    local SF_USERNAME="$1"
    local STRING="$2"

    QUERY="Select Id, Name FROM Group WHERE Type = 'Queue' AND Name IN ($STRING)" 
    CMD=`sf data query --target-org $SF_USERNAME -r json -q "$QUERY"`
    QUEUE_SEARCH_RESULT="$(echo $CMD)"

    for row in $(echo "${QUEUE_SEARCH_RESULT}" | jq -r '.result.records[] | @base64'); do
        _jq() {
        echo ${row} | base64 --decode | jq -r ${1}
        }
        QUEUE_NAME="$(echo $(_jq '.Name'))"
        REPLACE_WITH="$(echo $(_jq '.Id'))"
        QUEUE_NAME="${QUEUE_NAME// /_}"
        Queues["$QUEUE_NAME"]="$REPLACE_WITH"
    done

    for record in "${!Queues[@]}"; do
        echo "Queue: '$record', Value: '${Queues[$record]}'"
    done
}


get_profile_name() {
    local tag_name="$1"
    # Remove the prefix "{PROFILE-" and the suffix "}"
    tag_name=${tag_name#\{PROFILE-}  # Removes the prefix "{PROFILE-"
    tag_name=${tag_name%\}}  # Removes the suffix "}"
    echo "$tag_name"
}

get_role_name() {
    local tag_name="$1"
    # Remove the prefix "{PROFILE-" and the suffix "}"
    tag_name=${tag_name#\{USERROLE-}  # Removes the prefix "{PROFILE-"
    tag_name=${tag_name%\}}  # Removes the suffix "}"
    echo "$tag_name"
}

remove_pending_component_entries_with_no_id() {
    remove_component_id_pending Profiles
    remove_component_id_pending Roles
    remove_component_id_pending PermSet
    remove_component_id_pending PermSetGroup
    remove_component_id_pending Groups
    remove_component_id_pending Queues
}

# Function to remove 'COMPONENT_ID_PENDING' from any given array
remove_component_id_pending() {
    local -n array_ref=$1            # Use nameref to pass the associative array by reference
    local value_to_remove="COMPONENT_ID_PENDING"

    # Iterate over the associative array and remove the matching entries
    for key in "${!array_ref[@]}"; do
        if [ "${array_ref[$key]}" == "$value_to_remove" ]; then
            unset "array_ref[$key]"
        fi
    done
}

add_to_profiles() {
    if ! is_valid_string "$1"; then
        return
    fi

    local STRING="$1"
    IFS=';' read -ra group_array <<< "$STRING"
    for group in "${group_array[@]}"; do
        Profiles["$group"]="COMPONENT_ID_PENDING"
    done
}
add_to_roles() {
    if ! is_valid_string "$1"; then
        return
    fi

    local STRING="$1"
    IFS=';' read -ra group_array <<< "$STRING"
    for group in "${group_array[@]}"; do
        Roles["$group"]="COMPONENT_ID_PENDING"
    done
}

add_to_delegadmingroups() {
    if ! is_valid_string "$1"; then
        return
    fi

    local STRING="$1"
    IFS=';' read -ra group_array <<< "$STRING"
    for group in "${group_array[@]}"; do
        DelegAdminGroups["$group"]="COMPONENT_ID_PENDING"
    done
}
add_to_permsets() {
    if ! is_valid_string "$1"; then
        return
    fi

    local STRING="$1"
    IFS=';' read -ra group_array <<< "$STRING"
    for group in "${group_array[@]}"; do
        PermSet["$group"]="COMPONENT_ID_PENDING"
    done
}
add_to_permsetgroups() {
    if ! is_valid_string "$1"; then
        return
    fi

    local STRING="$1"
    IFS=';' read -ra group_array <<< "$STRING"
    for group in "${group_array[@]}"; do
        PermSetGroup["$group"]="COMPONENT_ID_PENDING"
    done
}
add_to_groups() {
    if ! is_valid_string "$1"; then
        return
    fi

    local STRING="$1"
    IFS=';' read -ra group_array <<< "$STRING"
    for group in "${group_array[@]}"; do
        Groups["$group"]="COMPONENT_ID_PENDING"
    done
}
add_to_queues() {
    if ! is_valid_string "$1"; then
        return
    fi

    local STRING="$1"
    IFS=';' read -ra queue_array <<< "$STRING"
    for queue in "${queue_array[@]}"; do
        Queues["$queue"]="COMPONENT_ID_PENDING"
    done
}

assign_permsets() {
    local UserIdRef="$1"
    
    ## If no component to assign, return
    if ! is_valid_string "$2"; then
        echo "User does not have any perm set assignments"
        return 0
    fi

    local PermSetToAssign="$2"
    local -n PermSetRef="$3"
    local -n PERM_SET_REF="$4"

    # Replace spaces with underscores and semicolons with newlines
    PermSetToAssign=$(replace_spaces_and_semicolons "$PermSetToAssign")

    # Loop through each group name (queue)
    for permSetName in $PermSetToAssign; do
        # Trim leading and trailing spaces
        permSetName=$(trim_spaces "$permSetName")

        # Get the Queue ID from the associative array
        PERM_SET_ID=${PermSetRef["$permSetName"]}
        
        # Check if QUEUE_ID is valid and append it to the string
        if [ -z "${PERM_SET_ID}" ]; then
            print_ERROR "Perm Set ID Not Found for: $permSetName" >&2
        else
            # Append the mapping to QUEUE_STRING
            echo "Assigning Perm Set: $permSetName with Id: $PERM_SET_ID"
            PERMSET_STRING="${PERM_SET_REF} '${UserIdRef}_${PERM_SET_ID}' => '${UserIdRef}%${PERM_SET_ID}',"
        fi
    done
    
    return 0
}

assign_permset_groups() {
    local UserIdRef="$1"
    
    ## If no component to assign, return
    if ! is_valid_string "$2"; then
        echo "User does not have any perm set group assignments"
        return 0
    fi

    local PermSetGroupToAssign="$2"
    local -n PermSetGroupRef="$3"
    local -n PERM_SET_GROUP_REF="$4"

    # Replace spaces with underscores and semicolons with newlines
    PermSetGroupToAssign=$(replace_spaces_and_semicolons "$PermSetGroupToAssign")

    # Loop through each group name (queue)
    for permSetGroupName in $PermSetGroupToAssign; do
        # Trim leading and trailing spaces
        permSetGroupName=$(trim_spaces "$permSetGroupName")

        # Get the Queue ID from the associative array
        PERM_SET_GROUP_ID=${PermSetGroupRef["$permSetGroupName"]}
        
        # Check if QUEUE_ID is valid and append it to the string
        if [ -z "${PERM_SET_GROUP_ID}" ]; then
            print_ERROR "Perm Set Group ID Not Found for: $permSetGroupName" >&2
        else
            # Append the mapping to QUEUE_STRING
            echo "Assigning Perm Set Group: $permSetGroupName with Id: $PERM_SET_GROUP_ID"
            PERMSETGROUP_STRING="${PERM_SET_GROUP_REF} '${UserIdRef}_${PERM_SET_GROUP_ID}' => '${UserIdRef}%${PERM_SET_GROUP_ID}',"
        fi
    done
    
    return 0
}

assign_queues() {
    local UserIdRef="$1"
    
    ## If no component to assign, return
    if ! is_valid_string "$2"; then
        echo "User does not have any queue assignments"
        return 0
    fi

    local QueuesToAssign="$2"
    local -n QueuesRef="$3"   # Associative array for queue mappings, passed by reference
    local -n QUEUE_STRING_REF="$4"  # String to hold queue assignments, passed by reference

    # Replace spaces with underscores and semicolons with newlines
    QueuesToAssign=$(replace_spaces_and_semicolons "$QueuesToAssign")

    # Loop through each group name (queue)
    for queueName in $QueuesToAssign; do
        # Trim leading and trailing spaces
        queueName=$(trim_spaces "$queueName")

        # Get the Queue ID from the associative array
        QUEUE_ID=${QueuesRef["$queueName"]}
        
        # Check if QUEUE_ID is valid and append it to the string
        if [ -z "${QUEUE_ID}" ]; then
            print_ERROR "Queue ID Not Found for: $queueName" >&2
        else
            # Append the mapping to QUEUE_STRING
            echo "Assigning Queue: $queueName with Id: $QUEUE_ID"
            QUEUE_STRING="${QUEUE_STRING_REF} '${UserIdRef}_${QUEUE_ID}' => '${UserIdRef}%${QUEUE_ID}',"
        fi
    done
    
    return 0
}

assign_public_groups() {
    local UserIdRef="$1"
    
    ## If no component to assign, return
    if ! is_valid_string "$2"; then
        echo "User does not have any public group assignments"
        return 0
    fi

    local PublicGroupToAssign="$2"
    local -n PublicGroupRef="$3"   # Associative array for queue mappings, passed by reference
    local -n PUBLIC_GROUP_STRING_REF="$4"  # String to hold queue assignments, passed by reference

    # Replace spaces with underscores and semicolons with newlines
    PublicGroupToAssign=$(replace_spaces_and_semicolons "$PublicGroupToAssign")

    # Loop through each group name (queue)
    for publicGroupName in $PublicGroupToAssign; do
        # Trim leading and trailing spaces
        publicGroupName=$(trim_spaces "$publicGroupName")

        # Get the Queue ID from the associative array
        PUBLIC_GROUP_ID=${PublicGroupRef["$publicGroupName"]}
        
        # Check if QUEUE_ID is valid and append it to the string
        if [ -z "${PUBLIC_GROUP_ID}" ]; then
            print_ERROR "Public Group ID Not Found for: $publicGroupName" >&2
        else
            # Append the mapping to PUBLIC_GROUP_STRING
            echo "Assigning Public Group: $publicGroupName with Id: $PUBLIC_GROUP_ID"
            PUBLIC_GROUP_STRING="${PUBLIC_GROUP_STRING_REF} '${UserIdRef}_${PUBLIC_GROUP_ID}' => '${UserIdRef}%${PUBLIC_GROUP_ID}',"
        fi
    done
    
    return 0
}

assign_delegate_admin_groups() {
    local UserIdRef="$1"

    ## If no component to assign, return
    if ! is_valid_string "$2"; then
        echo "User does not have any delegated admin group assignments"
        return 0
    fi

    local DelegateAdminGroup_STRING="$2"
    declare -n DELEGATEDREF_ADMIN_SET=$3  # Pass associative array by reference

    # Check if DelegateAdminGroup_STRING is empty or contains only a carriage return
    if [ -z "$DelegateAdminGroup_STRING" ] || [ "$DelegateAdminGroup_STRING" == "$CARRIAGE_RETURN" ]; then
        echo "Persona does not have any delegate admin group assignments"
    else
        # Replace spaces with underscores and semicolons with newlines
        DelegateAdminGroup_STRING=${DelegateAdminGroup_STRING// /_}
        DelegateAdminGroup_STRING=${DelegateAdminGroup_STRING//;/$'\n'}

        # Loop through each group name
        for groupName in $DelegateAdminGroup_STRING; do

            # Trim leading and trailing whitespace
            groupName=$(trim_spaces "$groupName")
            
            # Assign the group to the UserIdRef in the associative array
            echo "Assigning Delegate Admin Group: $groupName to User Id: $UserIdRef"
            DELEGATED_ADMIN_SET["${UserIdRef}-${groupName}"]="${groupName}"
        done
    fi
}


set_user_defails_from_federated_id() {

    local USER_FEDERATED_ID_REF="$1"

    ## If no component to assign, return
    if ! is_valid_string "$1"; then
        echo "get_user_from_federated_id USER_FEDERATED_ID_REF not a valid string"
        return 1
    fi
    USER_FEDERATED_ID_REF=${USER_FEDERATED_ID_REF%,}
    echo "USER_FEDERATED_ID_REF: $USER_FEDERATED_ID_REF"
    
    HEADING="Get User Details with FederationIdentifier '$USER_FEDERATED_ID_REF'"; print_H1 "$HEADING"; START_TIME=$SECONDS
    QUERY="Select Id, FirstName, LastName, Email, UserName, FederationIdentifier, nmspc_test__User_Persona__c FROM User WHERE FederationIdentifier = '$USER_FEDERATED_ID_REF' LIMIT 1"
    CMD=`sf data query --target-org $SF_USERNAME -r json -q "$QUERY"`
    USER_SEARCH_RESULT="$(echo $CMD)"
    for row in $(echo "${USER_SEARCH_RESULT}" | jq -r '.result.records[] | @base64'); do
        _jq() {
        echo ${row} | base64 --decode | jq -r ${1}
        }
        USER_USERNAME="$(echo $(_jq '.Username'))"
        USER_UESRID="$(echo $(_jq '.Id'))"
        UserArray["$USER_USERNAME"]="$USER_UESRID"
        echo "Adding: '$USER_USERNAME' with Id: '$USER_UESRID'"

         ## If runtime params are empty use default values
        FIRST_NAME="$(echo $(_jq '.FirstName'))"
        LAST_NAME="$(echo $(_jq '.LastName'))"
        USER_ALIAS="$(echo $(_jq '.Alias'))"
        INDIVIDUAL_USER_NAME="$(echo $(_jq '.Username'))"
        INDIVIDUAL_USER_EMAIL="$(echo $(_jq '.Email'))"

    done

    if ! is_valid_string "$USER_USERNAME"; then
        echo "User not found with FederationIdentifier '$USER_FEDERATED_ID_REF'"
        return 1
    fi
    echo "done"
    print_ElapsedTime_H1 $START_TIME "$HEADING"

}