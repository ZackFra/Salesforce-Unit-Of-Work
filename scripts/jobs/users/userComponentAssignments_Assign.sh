#!/usr/bin/env bash
set -e

# Capture the serialized array string
received_array=("$@")

# Extract values using jq
WORK_DIR="${received_array[0]}"
SF_USERNAME="${received_array[1]}"
USERS_JOB_DIR="${received_array[2]}"
PERMSET_STRING="${received_array[3]}"
PERMSETGROUP_STRING="${received_array[4]}"
PUBLIC_GROUP_STRING="${received_array[5]}"
QUEUE_STRING="${received_array[6]}"
NON_PROD_CHAT_QUEUE_STRING="${received_array[7]}"
VOICE_GROUP_STRING="${received_array[8]}"
DELEGATED_ADMIN_STRING="${received_array[9]}"

source $WORK_DIR/scripts/functions.sh

print_H2 "INFO: Print received_array for userComponentAssignments_Assign.sh";
echo "WORK_DIR: ${received_array[0]}"
echo "SF_USERNAME: ${received_array[1]}"
echo "USERS_JOB_DIR: ${received_array[2]}"
echo "PERMSET_STRING: ${received_array[3]}"
echo "PERMSETGROUP_STRING: ${received_array[4]}"
echo "PUBLIC_GROUP_STRING: ${received_array[5]}"
echo "QUEUE_STRING: ${received_array[6]}"
echo "NON_PROD_CHAT_QUEUE_STRING: ${received_array[7]}"
echo "VOICE_GROUP_STRING: ${received_array[8]}"
echo "DELEGATED_ADMIN_STRING: ${received_array[9]}"

HEADING="Assign User Components"; print_H1 "$HEADING"; START_TIME=$SECONDS

print_H2 "Load New Assignments"
if [ -z "${PERMSET_STRING-}" ]; then
    print_H3 "No Permission Sets Found for Assignment"
else
    PERMSET_STRING=${PERMSET_STRING%,}
    echo "PERMSET_STRING: $PERMSET_STRING"
    echo "Make new copy of Permission set assignments Apex file to transform and load"
    SOURCE_FILEPATH="$USERS_JOB_DIR/user-assign-permission-sets.apex"
    DEPLOY_FILEPATH="$USERS_JOB_DIR/user-assign-permission-sets-Update.apex"
    cp $SOURCE_FILEPATH $DEPLOY_FILEPATH
    echo "Update Tags"
    sed -i "s/{USERID_PERMSET_SET}/$PERMSET_STRING/g" $DEPLOY_FILEPATH
    echo "Load Assignments"
    sf apex run --target-org "$SF_USERNAME" --file $DEPLOY_FILEPATH
    echo "Done"
fi

if [ -z "${PERMSETGROUP_STRING-}" ]; then
    print_H3 "No Permission Set Groups Found for Assignment"
else
    PERMSETGROUP_STRING=${PERMSETGROUP_STRING%,}
    echo "PERMSETGROUP_STRING: $PERMSETGROUP_STRING"
    echo "Make new copy of Permission set Group assignments Apex file to transform and load"
    SOURCE_FILEPATH="$USERS_JOB_DIR/user-assign-permission-set-groups.apex"
    DEPLOY_FILEPATH="$USERS_JOB_DIR/user-assign-permission-set-groups-Update.apex"
    cp $SOURCE_FILEPATH $DEPLOY_FILEPATH
    echo "Update Tags"
    sed -i "s|{USERID_PERMSET_SET}|$PERMSETGROUP_STRING|g" $DEPLOY_FILEPATH
    echo "Load Assignments"
    sf apex run --target-org "$SF_USERNAME" --file $DEPLOY_FILEPATH
    echo "Done"
fi

if [ -z "${PUBLIC_GROUP_STRING-}" ]; then
    print_H3 "No Public Groups Found for Assignment"
else
    PUBLIC_GROUP_STRING=${PUBLIC_GROUP_STRING%,}
    echo "PUBLIC_GROUP_STRING: $PUBLIC_GROUP_STRING"
    echo "Make new copy of Group assignments Apex file to transform and load"
    SOURCE_FILEPATH="$USERS_JOB_DIR/user-assign-groups.apex"
    DEPLOY_FILEPATH="$USERS_JOB_DIR/user-assign-groups-Update.apex"
    cp $SOURCE_FILEPATH $DEPLOY_FILEPATH
    echo "Update Tags"
    sed -i "s|{GROUP_STRING}|$PUBLIC_GROUP_STRING|g" $DEPLOY_FILEPATH
    echo "Load Assignments"
    sf apex run --target-org "$SF_USERNAME" --file $DEPLOY_FILEPATH
    echo "Done"
fi

if [ -z "${QUEUE_STRING-}" ]; then
    print_H3 "No Queues Found for Assignment"
else
    QUEUE_STRING=${QUEUE_STRING%,}
    echo "QUEUE_STRING: $QUEUE_STRING"
    echo "Make new copy of Group assignments Apex file to transform and load"
    SOURCE_FILEPATH="$USERS_JOB_DIR/user-assign-groups.apex"
    DEPLOY_FILEPATH="$USERS_JOB_DIR/user-assign-groups-Update.apex"
    cp $SOURCE_FILEPATH $DEPLOY_FILEPATH
    echo "Update Tags"
    sed -i "s|{GROUP_STRING}|$QUEUE_STRING|g" $DEPLOY_FILEPATH
    echo "Load Assignments"
    sf apex run --target-org "$SF_USERNAME" --file $DEPLOY_FILEPATH >/dev/null
    echo "Done"
fi

if [ -z "${NON_PROD_CHAT_QUEUE_STRING-}" ]; then
    print_H3 "No Non Prod Chat Queues Found for Assignment"
else
    NON_PROD_CHAT_QUEUE_STRING=${NON_PROD_CHAT_QUEUE_STRING%,}
    echo "NON_PROD_CHAT_QUEUE_STRING: $NON_PROD_CHAT_QUEUE_STRING"
    echo "Make new copy of Group assignments Apex file to transform and load"
    SOURCE_FILEPATH="$USERS_JOB_DIR/user-assign-groups.apex"
    DEPLOY_FILEPATH="$USERS_JOB_DIR/user-assign-groups-Update.apex"
    cp $SOURCE_FILEPATH $DEPLOY_FILEPATH
    echo "Update Tags"
    sed -i "s|{GROUP_STRING}|$NON_PROD_CHAT_QUEUE_STRING|g" $DEPLOY_FILEPATH
    echo "Load Assignments"
    sf apex run --target-org "$SF_USERNAME" --file $DEPLOY_FILEPATH >/dev/null
    echo "Done"
fi
print_ElapsedTime_H1 $START_TIME "$HEADING"

HEADING="Assign Voice Components"; print_H1 "$HEADING"; START_TIME=$SECONDS
## ASSIGN VOICE GROUP TO UESR
if [ -z "${VOICE_GROUP_STRING-}" ]; then
    print_H3 "No Voice Groups Found for Assignment"
else
    print_H2 "Voice Group"
    # Declare a new associative array
    declare -A VOICE_GROUP_ARRAY

    # Deserialize the serialized_array and populate VOICE_GROUP_ARRAY
    IFS=',' read -ra items <<< "$VOICE_GROUP_STRING"
    for item in "${items[@]}"; do
        key=$(echo "$item" | cut -d':' -f1)
        value=$(echo "$item" | cut -d':' -f2)
        VOICE_GROUP_ARRAY["$key"]="$value"
    done

    CALLCENTER_QUERY="SELECT Id, Name, Version FROM CallCenter WHERE Version != null LIMIT 1"
    CALLCENTER_INFO=$(sf data query -o $SF_USERNAME -q "$CALLCENTER_QUERY" --json)
    CONTACT_CENTER_ID=$(echo $CALLCENTER_INFO | jq -r '.result.records[0].Id')
    echo "CONTACT_CENTER_ID: $CONTACT_CENTER_ID"

    ## CHECK IF CONTACT CENTRE EXISTS
    if [ -z "${CONTACT_CENTER_ID}" ] || [ "${CONTACT_CENTER_ID}" = "null" ]; then
        echo "No Contact Centre found for Contact Centre Group Assignment"
    else

        # Now you can use the VOICE_GROUP_ARRAY in this script
        for key in "${!VOICE_GROUP_ARRAY[@]}"; do
            USER_ID=$(echo "$key" | cut -d'-' -f1)
            CONTACT_CENTER_GROUP=$(echo "$key" | cut -d'-' -f2)

            print_H2 "USER_ID: $USER_ID, CONTACT_CENTER_GROUP: $CONTACT_CENTER_GROUP"

            DEBUG_PATH="$WORK_DIR/runtimeResources/debugScreenshots"
            echo "Running puppeteer"
            rm -rf $DEBUG_PATH
            ENABLE_LOGS='None'

            echo "Get URL to Open Org"
            OPEN_URL=$(echo `sf org open -o $SF_USERNAME -r --path home/home.jsp 2>/dev/null`)
            OPEN_URL="${OPEN_URL/URL: /,}"    
            OPEN_URL=$(cut -d',' -f2 <<<"$OPEN_URL")

            echo "Add User to Contact Center";
            JOB_NAME=assignVoiceGroupToUser
            USER_QUERY="SELECT Id, Name, CallCenterId FROM User WHERE Id = '$USER_ID' LIMIT 1"
            USER_INFO=$(sf data query  -o $SF_USERNAME -q "$USER_QUERY" --json)
            USER_FULL_NAME=$(echo $USER_INFO | jq -r '.result.records[0].Name')
            USER_CONTACT_CENTER_ID=$(echo $USER_INFO | jq -r '.result.records[0].CallCenterId')
            USER_CONTACT_CENTER_ID=${USER_CONTACT_CENTER_ID:-""}
            echo "USER_CONTACT_CENTER_ID: $USER_CONTACT_CENTER_ID"
            
            CONTACT_CENTER_GROUP="${CONTACT_CENTER_GROUP//_/ }"
            CMD_STR="${USER_ID},${USER_FULL_NAME},${USER_CONTACT_CENTER_ID},${CONTACT_CENTER_GROUP},${CONTACT_CENTER_ID}"

            echo "CMD_STR: $CMD_STR"
            mkdir -p "$DEBUG_PATH/$JOB_NAME"
            cd $WORK_DIR
            node "$WORK_DIR/scripts/surface/addContactCenterAndVoiceGroupToUser.js" "$WORK_DIR" "$JOB_NAME" "$ENABLE_LOGS" "$OPEN_URL" "$CMD_STR";
            

        done
    fi
fi
print_ElapsedTime_H1 $START_TIME "$HEADING"


# ASSIGN DELEGATE ADMIN TO USER
HEADING="Assign Delegated Admin Components"; print_H1 "$HEADING"; START_TIME=$SECONDS
if [ -z "${DELEGATED_ADMIN_STRING-}" ]; then
    print_H3 "No Delegated Admin Groups Found for Assignment"
else
    print_H2 "Delegated Admin Group"
    # Declare a new associative array
    declare -A DELEGATE_ADMIN_ARRAY

    # Deserialize the serialized_array and populate DELEGATE_ADMIN_ARRAY
    IFS=',' read -ra items <<< "$DELEGATED_ADMIN_STRING"
    for item in "${items[@]}"; do
        key=$(echo "$item" | cut -d':' -f1)
        value=$(echo "$item" | cut -d':' -f2)
        DELEGATE_ADMIN_ARRAY["$key"]="$value"
    done

    # Now you can use the DELEGATE_ADMIN_ARRAY in this script
    for key in "${!DELEGATE_ADMIN_ARRAY[@]}"; do
        USER_ID=$(echo "$key" | cut -d'-' -f1)
        DELEGATED_ADMIN_GROUP=$(echo "$key" | cut -d'-' -f2)
        DELEGATED_ADMIN_GROUP="${DELEGATED_ADMIN_GROUP//_/ }"

        print_H2 "USER_ID: $USER_ID, DELEGATED_ADMIN_GROUP: $DELEGATED_ADMIN_GROUP"
        DELEG_ADMIN_QUERY="Select Id, Name from DelegateGroup WHERE Name = '$DELEGATED_ADMIN_GROUP' LIMIT 1"
        DELEG_ADMIN_INFO=$(sf data query  -o $SF_USERNAME -q "$DELEG_ADMIN_QUERY" --json --use-tooling-api)
        DELEG_ADMIN_ID=$(echo $DELEG_ADMIN_INFO | jq -r '.result.records[0].Id')
        echo "DELEG_ADMIN_ID: $DELEG_ADMIN_ID"

        DELEG_ADMIN_CREATE_INFO=$(sf data create record --use-tooling-api --sobject DelegateGroupMember --values "DelegateGroupId=$DELEG_ADMIN_ID UserOrGroupId=$USER_ID" -o $SF_USERNAME --json)
        DELEG_ADMIN_CREATE_RESULT=$(echo $DELEG_ADMIN_CREATE_INFO | jq -r '.result')
        echo "DELEG_ADMIN_CREATE_RESULT: $DELEG_ADMIN_CREATE_RESULT"
    done
fi
print_ElapsedTime_H1 $START_TIME "$HEADING"