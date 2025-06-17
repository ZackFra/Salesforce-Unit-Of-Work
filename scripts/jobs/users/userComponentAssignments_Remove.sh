#!/usr/bin/env bash
set -e

# Capture the serialized array string
received_array=("$@")

# Extract values using jq
WORK_DIR="${received_array[0]}"
SF_USERNAME="${received_array[1]}"
USERS_JOB_DIR="${received_array[2]}"
USER_ID_STRING="${received_array[3]}"

source $WORK_DIR/scripts/functions.sh

print_H2 "INFO:  Print received_array"; 
echo "WORK_DIR: ${received_array[0]}"
echo "SF_USERNAME: ${received_array[1]}"
echo "USERS_JOB_DIR: ${received_array[2]}"
echo "USER_ID_STRING: ${received_array[3]}"

print_H2 "Remove Old Permission Set Assignments";
declare -A PermSetRemove
QUERY="SELECT Id,AssigneeId from PermissionSetAssignment WHERE AssigneeId IN ($USER_ID_STRING) AND PermissionSet.IsOwnedByProfile = false"
CMD=`sf data query --target-org $SF_USERNAME -r json -q "$QUERY"`
#echo "$CMD"
PERMSET_REMOVEAL_SEARCH_RESULT="$(echo $CMD)"
PERMSET_REMOVE_STRING="";

batch_size=20
counter=0
PERMSET_REMOVE_STRING=""

for row in $(echo "${PERMSET_REMOVEAL_SEARCH_RESULT}" | jq -r '.result.records[] | @base64'); do
    _jq() {
     echo ${row} | base64 --decode | jq -r ${1}
    }
    PERMSET_ASSIGN_RECORD_ID="$(echo $(_jq '.Id'))"
    PERMSET_USER_ID="$(echo $(_jq '.AssigneeId'))"
    #PermSetRemove["$PERMSET_USER_ID"]="$PERMSET_ASSIGN_ID"
    echo "Adding Perm Set Assignment with ID: $PERMSET_USER_ID for user: $PERMSET_USER_ID"

    PERMSET_REMOVE_STRING="$PERMSET_REMOVE_STRING '${PERMSET_ASSIGN_RECORD_ID}_${PERMSET_USER_ID}' => '${PERMSET_ASSIGN_RECORD_ID}_${PERMSET_USER_ID}',"

    counter=$((counter + 1))

    # When batch size reaches 20, process the batch and reset the counter and batch
    if [ $counter -eq $batch_size ]; then
        print_H2 "Processing batch: $counter"

        PERMSET_REMOVE_STRING=${PERMSET_REMOVE_STRING%,}
        echo "PERMSET_REMOVE_STRING: $PERMSET_REMOVE_STRING"

        echo "Make new copy of Permission set removal of assignments Apex file to transform and load"
        SOURCE_FILEPATH7="$USERS_JOB_DIR/user-remove-permission-sets-and-perm-set-groups.apex"
        DEPLOY_FILEPATH7="$USERS_JOB_DIR/user-remove-permission-sets-and-perm-set-groups-Update.apex"
        cp $SOURCE_FILEPATH7 $DEPLOY_FILEPATH7

        echo "Update Tags"
        sed -i "s/{RECORDID_PERMSET_SET}/$PERMSET_REMOVE_STRING/g" $DEPLOY_FILEPATH7

        echo "Remove Permission Sets and Perm Set Groups "
        print_apex_errors "$DEPLOY_FILEPATH7"

        # Reset counter and batch
        counter=0
        PERMSET_REMOVE_STRING=""
    fi

done

# Process any remaining records if they don't exactly divide by 20
if [ $counter -gt 0 ]; then
    print_H2 "Processing final batch: $counter"

    PERMSET_REMOVE_STRING=${PERMSET_REMOVE_STRING%,}
    echo "PERMSET_REMOVE_STRING: $PERMSET_REMOVE_STRING"

    echo "Make new copy of Permission set removal of assignments Apex file to transform and load"
    SOURCE_FILEPATH7="$USERS_JOB_DIR/user-remove-permission-sets-and-perm-set-groups.apex"
    DEPLOY_FILEPATH7="$USERS_JOB_DIR/user-remove-permission-sets-and-perm-set-groups-Update.apex"
    cp $SOURCE_FILEPATH7 $DEPLOY_FILEPATH7

    echo "Update Tags"
    sed -i "s/{RECORDID_PERMSET_SET}/$PERMSET_REMOVE_STRING/g" $DEPLOY_FILEPATH7

    echo "Remove Permission Sets and Perm Set Groups "
    print_apex_errors "$DEPLOY_FILEPATH7"
fi
echo "done"


print_H2 "Remove Old Permission Set Assignments License Assignments"
declare -A PermSetRemove
QUERY="SELECT Id,AssigneeId from PermissionSetLicenseAssign WHERE AssigneeId IN ($USER_ID_STRING)"
CMD=`sf data query --target-org $SF_USERNAME -r json -q "$QUERY"`
#echo "$CMD"
PERMSET_REMOVEAL_SEARCH_RESULT="$(echo $CMD)"
PERMSET_REMOVE_STRING="";

batch_size=20
counter=0
PERMSET_REMOVE_STRING=""

for row in $(echo "${PERMSET_REMOVEAL_SEARCH_RESULT}" | jq -r '.result.records[] | @base64'); do
    _jq() {
     echo ${row} | base64 --decode | jq -r ${1}
    }
    PERMSET_ASSIGN_RECORD_ID="$(echo $(_jq '.Id'))"
    PERMSET_USER_ID="$(echo $(_jq '.AssigneeId'))"
    echo "Adding Perm Set License Assignment with ID: $PERMSET_USER_ID for user: $PERMSET_USER_ID"

    PERMSET_REMOVE_STRING="$PERMSET_REMOVE_STRING '${PERMSET_ASSIGN_RECORD_ID}_${PERMSET_USER_ID}' => '${PERMSET_ASSIGN_RECORD_ID}_${PERMSET_USER_ID}',"

    counter=$((counter + 1))

    # When batch size reaches 20, process the batch and reset the counter and batch
    if [ $counter -eq $batch_size ]; then
        print_H2 "Processing batch: $counter"

        PERMSET_REMOVE_STRING=${PERMSET_REMOVE_STRING%,}
        echo "PERMSET_REMOVE_STRING: $PERMSET_REMOVE_STRING"

        echo "Make new copy of Permission set removal of assignments Apex file to transform and load"
        SOURCE_FILEPATH7="$USERS_JOB_DIR/user-remove-permission-sets-license-assignments.apex"
        DEPLOY_FILEPATH7="$USERS_JOB_DIR/user-remove-permission-sets-license-assignments-Update.apex"
        cp $SOURCE_FILEPATH7 $DEPLOY_FILEPATH7

        echo "Update Tags"
        sed -i "s/{RECORDID_PERMSET_SET}/$PERMSET_REMOVE_STRING/g" $DEPLOY_FILEPATH7

        echo "Remove Permission Sets License Assignments"
        print_apex_errors "$DEPLOY_FILEPATH7"

        # Reset counter and batch
        counter=0
        PERMSET_REMOVE_STRING=""
    fi

done

# Process any remaining records if they don't exactly divide by 20
if [ $counter -gt 0 ]; then
    print_H2 "Processing final batch: $counter"

    PERMSET_REMOVE_STRING=${PERMSET_REMOVE_STRING%,}
    echo "PERMSET_REMOVE_STRING: $PERMSET_REMOVE_STRING"

    echo "Make new copy of Permission set removal of assignments Apex file to transform and load"
    SOURCE_FILEPATH7="$USERS_JOB_DIR/user-remove-permission-sets-license-assignments.apex"
    DEPLOY_FILEPATH7="$USERS_JOB_DIR/user-remove-permission-sets-license-assignments-Update.apex"
    cp $SOURCE_FILEPATH7 $DEPLOY_FILEPATH7

    echo "Update Tags"
    sed -i "s/{RECORDID_PERMSET_SET}/$PERMSET_REMOVE_STRING/g" $DEPLOY_FILEPATH7

    echo "Remove Permission Sets License Assignments"
    print_apex_errors "$DEPLOY_FILEPATH7"
fi
echo "done"


print_H2 "Remove Old Group"
declare -A GroupRemove
QUERY="SELECT Id, UserOrGroupId, GroupId from GroupMember WHERE UserOrGroupId IN ($USER_ID_STRING)"
CMD=`sf data query --target-org $SF_USERNAME -r json -q "$QUERY"`
#echo "$CMD"
GROUP_REMOVEAL_SEARCH_RESULT="$(echo $CMD)"
GROUP_REMOVE_STRING="";

batch_size=20
counter=0
PERMSET_REMOVE_STRING=""

for row in $(echo "${GROUP_REMOVEAL_SEARCH_RESULT}" | jq -r '.result.records[] | @base64'); do
    _jq() {
     echo ${row} | base64 --decode | jq -r ${1}
    }
    GROUP_ASSIGN_RECORD_ID="$(echo $(_jq '.Id'))"
    GROUP_USER_ID="$(echo $(_jq '.UserOrGroupId'))"
    #echo "Adding Group Assignment with ID: $GROUP_ASSIGN_RECORD_ID for user: $GROUP_USER_ID"

    GROUP_REMOVE_STRING="$GROUP_REMOVE_STRING '${GROUP_ASSIGN_RECORD_ID}_${GROUP_USER_ID}' => '${GROUP_ASSIGN_RECORD_ID}_${GROUP_USER_ID}',"

    counter=$((counter + 1))

    # When batch size reaches 20, process the batch and reset the counter and batch
    if [ $counter -eq $batch_size ]; then
        print_H2 "Processing batch: $counter"

        GROUP_REMOVE_STRING=${GROUP_REMOVE_STRING%,}
        echo "GROUP_REMOVE_STRING: $GROUP_REMOVE_STRING"

        SOURCE_FILEPATH8="$USERS_JOB_DIR/user-remove-groups.apex"
        DEPLOY_FILEPATH8="$USERS_JOB_DIR/user-remove-groups-Update.apex"
        cp $SOURCE_FILEPATH8 $DEPLOY_FILEPATH8

        sed -i "s/{RECORDID_GROUP}/$GROUP_REMOVE_STRING/g" $DEPLOY_FILEPATH8

        echo "Remove Group"
        print_apex_errors "$DEPLOY_FILEPATH8"

        # Reset counter and batch
        counter=0
        GROUP_REMOVE_STRING=""
    fi

done


# Process any remaining records if they don't exactly divide by 20
if [ $counter -gt 0 ]; then
    print_H2 "Processing final batch: $counter"

    GROUP_REMOVE_STRING=${GROUP_REMOVE_STRING%,}
    echo "GROUP_REMOVE_STRING: $GROUP_REMOVE_STRING"

    SOURCE_FILEPATH8="$USERS_JOB_DIR/user-remove-groups.apex"
    DEPLOY_FILEPATH8="$USERS_JOB_DIR/user-remove-groups-Update.apex"
    cp $SOURCE_FILEPATH8 $DEPLOY_FILEPATH8

    sed -i "s/{RECORDID_GROUP}/$GROUP_REMOVE_STRING/g" $DEPLOY_FILEPATH8

    echo "Remove Group"
    print_apex_errors "$DEPLOY_FILEPATH8"
fi


# Process any remaining records if they don't exactly divide by 20
if [ $counter -gt 0 ]; then
    print_H2 "Processing final batch: $counter"

    SALES_ORG_REMOVE_STRING=${SALES_ORG_REMOVE_STRING%,}
    echo "SALES_ORG_REMOVE_STRING: $SALES_ORG_REMOVE_STRING"

    SOURCE_FILEPATH8="$USERS_JOB_DIR/user-remove-sales-org-users.apex"
    DEPLOY_FILEPATH8="$USERS_JOB_DIR/user-remove-sales-org-users-Update.apex"
    cp $SOURCE_FILEPATH8 $DEPLOY_FILEPATH8

    sed -i "s/{RECORDID_GROUP}/$SALES_ORG_REMOVE_STRING/g" $DEPLOY_FILEPATH8

    echo "Remove Sales Org User"
    print_apex_errors "$DEPLOY_FILEPATH8"
fi

print_H2 "Remove Delegated Admin Groups"
declare -A GroupRemove
QUERY="SELECT Id,UserOrGroupId from DelegateGroupMember WHERE UserOrGroupId IN ($USER_ID_STRING)"
CMD=`sf data query --target-org $SF_USERNAME -r json -q "$QUERY" --use-tooling-api`
GROUP_REMOVEAL_SEARCH_RESULT="$(echo $CMD)"

for row in $(echo "${GROUP_REMOVEAL_SEARCH_RESULT}" | jq -r '.result.records[] | @base64'); do
    _jq() {
     echo ${row} | base64 --decode | jq -r ${1}
    }
    GROUP_ASSIGN_RECORD_ID="$(echo $(_jq '.Id'))"
    GROUP_USER_ID="$(echo $(_jq '.UserOrGroupId'))"


    print_H2 "GROUP_USER_ID: $GROUP_USER_ID, GROUP_ASSIGN_RECORD_ID: $GROUP_ASSIGN_RECORD_ID"
    DELEG_ADMIN_CREATE_INFO=$(sf data delete record --use-tooling-api --sobject DelegateGroupMember --record-id $GROUP_ASSIGN_RECORD_ID -o $SF_USERNAME --json)
    #DELEG_ADMIN_CREATE_RESULT=$(echo $DELEG_ADMIN_CREATE_INFO | jq -r '.result')
    echo "DELEG_ADMIN_CREATE_INFO: $DELEG_ADMIN_CREATE_INFO"
done


echo "done"