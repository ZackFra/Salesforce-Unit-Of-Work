#!/usr/bin/env bash
set -e

# Capture the serialized array string
received_array=("$@")

# Extract values using jq
WORK_DIR="${received_array[0]}"
Agent_TempDirectory="${received_array[1]}"
DEPLOY_PATH="${received_array[2]}"
SF_USERNAME="${received_array[3]}"
USER_PERSONA_COMPONENTS_CSV="${received_array[4]}"
PROFILEIDS_FILE="${received_array[5]}"
ROLEIDS_FILE="${received_array[6]}"
PERMSETIDS_FILE="${received_array[7]}"
PERMSETGROUPDS_FILE="${received_array[8]}"
PUBLICGROUP_FILE="${received_array[9]}"
QUEUES_FILE="${received_array[10]}"
USERSID_FILE="${received_array[11]}"

source $WORK_DIR/scripts/functions.sh

print_H2 "INFO:  Print received_array"
echo "WORK_DIR: ${received_array[0]}"
echo "Agent_TempDirectory: ${received_array[1]}"
echo "DEPLOY_PATH: ${received_array[2]}"
echo "SF_USERNAME: ${received_array[3]}"
echo "USER_PERSONA_COMPONENTS_CSV: ${received_array[4]}"
echo "PROFILEIDS_FILE: ${received_array[5]}"
echo "ROLEIDS_FILE: ${received_array[6]}"
echo "PERMSETIDS_FILE: ${received_array[7]}"
echo "PERMSETGROUPDS_FILE: ${received_array[8]}"
echo "PUBLICGROUP_FILE: ${received_array[9]}"
echo "QUEUES_FILE: ${received_array[10]}"
echo "USERSID_FILE: ${received_array[11]}"

HEADING="Get Profile Names and IDs"; print_H1 "$HEADING"; START_TIME=$SECONDS
declare -A Profiles
QUERY="Select Id, Name FROM Profile"
CMD=`sf data query --target-org $SF_USERNAME -r json -q "$QUERY"`
#echo "$CMD"
SEARCH_RESULT="$(echo $CMD)"

> "$PROFILEIDS_FILE"

for row in $(echo "${SEARCH_RESULT}" | jq -r '.result.records[] | @base64'); do
    _jq() {
     echo ${row} | base64 --decode | jq -r ${1}
    }
    
    PROFILE_NAME="$(echo $(_jq '.Name'))"
    TAG_NAME="{PROFILE-${PROFILE_NAME}}"
    REPLACE_WITH="$(echo $(_jq '.Id'))"

    PROFILE_NAME=${PROFILE_NAME//[ ]/_}
    echo "Profile Name: '$PROFILE_NAME' Id: '$REPLACE_WITH'"
    Profiles["$PROFILE_NAME"]="$REPLACE_WITH"
    echo "$PROFILE_NAME=${Profiles[$PROFILE_NAME]}" >> "$PROFILEIDS_FILE"

done
echo "done"
print_ElapsedTime_H1 $START_TIME "$HEADING"

HEADING="Get Roles Names and IDs"; print_H1 "$HEADING"; START_TIME=$SECONDS
declare -A Roles
FILE_CONTENTS=$(tail -n +2 $USER_PERSONA_COMPONENTS_CSV)
FILE_CONTENTS="${FILE_CONTENTS// /___}"
results=$(
    for csvRow in $FILE_CONTENTS; do
        UserRoleName=$(cut -d',' -f3 <<<"$csvRow")
        UserRoleName="${UserRoleName//___/ }"
        UserRoleName=$(cut -d'-' -f2,3 <<<$UserRoleName)
        UserRoleName=${UserRoleName%?}
        UserRoleName="${UserRoleName// /%%}"
        ### DO NOT COMMENT OUT BELOW ECHO - THIS IS ALWAYS NEEDED
        echo $UserRoleName
    done
)

# remove duplicates to decrease runtime
newstring=$(echo "${results[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' ')
ROLE_STRING=''
for sorted in $newstring; do
    ROLE_STRING="$ROLE_STRING'$sorted',"
done
ROLE_STRING=${ROLE_STRING%,}
ROLE_STRING="${ROLE_STRING//%%/ }"


QUERY="Select Id, Name FROM UserRole WHERE Name IN ($ROLE_STRING)"
CMD=`sf data query --target-org $SF_USERNAME -r json -q "$QUERY"`
SEARCH_RESULT="$(echo $CMD)"

> "$ROLEIDS_FILE"

for row in $(echo "${SEARCH_RESULT}" | jq -r '.result.records[] | @base64'); do
    _jq() {
     echo ${row} | base64 --decode | jq -r ${1}
    }
    USERROLE_NAME="$(echo $(_jq '.Name'))"
    TAG_NAME="{USERROLE-${USERROLE_NAME}}"
    REPLACE_WITH="$(echo $(_jq '.Id'))"
    #sed -i "s|$TAG_NAME|$REPLACE_WITH|g" $DEPLOY_FILEPATH
    USERROLE_NAME=${USERROLE_NAME//[ ]/_}
    echo "UserRole Name: '$USERROLE_NAME' Id: '$REPLACE_WITH'"
    Roles["$USERROLE_NAME"]="$REPLACE_WITH"
    echo "$USERROLE_NAME=${Roles[$USERROLE_NAME]}" >> "$ROLEIDS_FILE"

done
echo "done"
print_ElapsedTime_H1 $START_TIME "$HEADING"

HEADING="Get Permission Sets from target org"; print_H1 "$HEADING"; START_TIME=$SECONDS
declare -A PermSet
QUERY="Select Id, Label FROM PermissionSet WHERE IsOwnedByProfile = false AND PermissionSetGroupId = null"
CMD=`sf data query --target-org $SF_USERNAME -r json -q "$QUERY"`
PERMSET_SEARCH_RESULT="$(echo $CMD)"

> "$PERMSETIDS_FILE"

for row in $(echo "${PERMSET_SEARCH_RESULT}" | jq -r '.result.records[] | @base64'); do
    _jq() {
     echo ${row} | base64 --decode | jq -r ${1}
    }
    PERMSET_NAME="$(echo $(_jq '.Label'))"
    TAG_NAME="{PERMSET-${PERMSET_NAME}}"
    REPLACE_WITH="$(echo $(_jq '.Id'))"
    PERMSET_NAME=${PERMSET_NAME//[ ]/_}
    PermSet["$PERMSET_NAME"]="$REPLACE_WITH"
    echo "Permission Set: '$PERMSET_NAME' with id '$REPLACE_WITH'"
    echo "$PERMSET_NAME=${PermSet[$PERMSET_NAME]}" >> "$PERMSETIDS_FILE"
done
echo "done"
print_ElapsedTime_H1 $START_TIME "$HEADING"

HEADING="Get Permission Set Groups from target org"; print_H1 "$HEADING"; START_TIME=$SECONDS
declare -A PermSetGroup
QUERY="Select Id, MasterLabel FROM PermissionSetGroup"
CMD=`sf data query --target-org $SF_USERNAME -r json -q "$QUERY"`
PERMSETGROUP_SEARCH_RESULT="$(echo $CMD)"

> "$PERMSETGROUPDS_FILE"

for row in $(echo "${PERMSETGROUP_SEARCH_RESULT}" | jq -r '.result.records[] | @base64'); do
    _jq() {
     echo ${row} | base64 --decode | jq -r ${1}
    }
    PERMSET_GROUP_NAME="$(echo $(_jq '.MasterLabel'))"
    TAG_NAME="{PERMSETGROUP-${PERMSET_GROUP_NAME}}"
    REPLACE_WITH="$(echo $(_jq '.Id'))"
    PERMSET_GROUP_NAME=${PERMSET_GROUP_NAME//[ ]/_}
    PermSetGroup["$PERMSET_GROUP_NAME"]="$REPLACE_WITH"
    echo "Permission Set Group: '$PERMSET_GROUP_NAME' with id '$REPLACE_WITH'"
    echo "$PERMSET_GROUP_NAME=${PermSetGroup[$PERMSET_GROUP_NAME]}" >> "$PERMSETGROUPDS_FILE"
done
echo "done"
print_ElapsedTime_H1 $START_TIME "$HEADING"

HEADING="Get Groups from target org"; print_H1 "$HEADING"; START_TIME=$SECONDS
declare -A Groups
QUERY="Select Id, Name FROM Group WHERE Type = 'Regular'"
CMD=`sf data query --target-org $SF_USERNAME -r json -q "$QUERY"`
GROUP_SEARCH_RESULT="$(echo $CMD)"

> "$PUBLICGROUP_FILE"

for row in $(echo "${GROUP_SEARCH_RESULT}" | jq -r '.result.records[] | @base64'); do
    _jq() {
     echo ${row} | base64 --decode | jq -r ${1}
    }
    GROUP_NAME="$(echo $(_jq '.Name'))"
    REPLACE_WITH="$(echo $(_jq '.Id'))"
    GROUP_NAME=${GROUP_NAME//[ ]/_}
    echo "Queue: '$GROUP_NAME' with id '$REPLACE_WITH'"
    Groups["$GROUP_NAME"]="$REPLACE_WITH"
    echo "$GROUP_NAME=${Groups[$GROUP_NAME]}" >> "$PUBLICGROUP_FILE"
done
echo "done"
print_ElapsedTime_H1 $START_TIME "$HEADING"

HEADING="Get Queues from target org"; print_H1 "$HEADING"; START_TIME=$SECONDS
declare -A Queues
QUERY="Select Id, Name FROM Group WHERE Type = 'Queue'"
CMD=`sf data query --target-org $SF_USERNAME -r json -q "$QUERY"`
QUEUE_SEARCH_RESULT="$(echo $CMD)"

> "$QUEUES_FILE"

for row in $(echo "${QUEUE_SEARCH_RESULT}" | jq -r '.result.records[] | @base64'); do
    _jq() {
     echo ${row} | base64 --decode | jq -r ${1}
    }
    QUEUE_NAME="$(echo $(_jq '.Name'))"
    REPLACE_WITH="$(echo $(_jq '.Id'))"

    QUEUE_NAME=${QUEUE_NAME//[ ]/_}
    echo "Queue: '$QUEUE_NAME' with id '$REPLACE_WITH'"
    Queues["$QUEUE_NAME"]="$REPLACE_WITH"
    echo "$QUEUE_NAME=${Queues[$QUEUE_NAME]}" >> "$QUEUES_FILE"
done
echo "done"
print_ElapsedTime_H1 $START_TIME "$HEADING"

#print_H1 "Get Users and their IDs from target org"
#declare -A UserArray
#QUERY="Select Id, Username FROM User where UserType = 'Standard'"
#CMD=`sf data query --target-org $SF_USERNAME -r json -q "$QUERY"`
#USER_SEARCH_RESULT="$(echo $CMD)"

#> "$USERSID_FILE"

#for row in $(echo "${USER_SEARCH_RESULT}" | jq -r '.result.records[] | @base64'); do
#    _jq() {
#     echo ${row} | base64 --decode | jq -r ${1}
#    }
#    USER_USERNAME="$(echo $(_jq '.Username'))"
#    USER_UESRID="$(echo $(_jq '.Id'))"
#    UserArray["$USER_USERNAME"]="$USER_UESRID"
#    echo "$USER_USERNAME=${UserArray[$USER_USERNAME]}" >> "$USERSID_FILE"
#done
#echo "done"