#!/usr/bin/env bash
set -e

# Capture the serialized array string and xtract values using jq
received_array=("$@")
WORK_DIR="${received_array[0]}"
SF_USERNAME="${received_array[1]}"
SANDBOX_NAME="${received_array[2]}"
DEPLOY_PATH="${received_array[3]}"
SFDX_PATH="${received_array[4]}"
SFDX_REPO_NAME="${received_array[5]}"
MY_DOMAIN="${received_array[6]}"
USER_STATUS="${received_array[7]}"
USER_TYPE="${received_array[8]}"
SEND_PASSWORD="${received_array[9]}"
Agent_TempDirectory="${received_array[10]}"
ORG_USERNAME_IDENT="${received_array[11]}"
COMPANY_DOMAIN="${received_array[12]}"
ERROR_HANDLING="${received_array[13]}"
ACTIVITY_TYPE="${received_array[14]}"
CSV_FILE_NAME="${received_array[15]}"
PERSONA="${received_array[16]}"
USER_EMAIL_ADDRESS="${received_array[17]}"
FIRST_NAME="${received_array[18]}"
LAST_NAME="${received_array[19]}"
USER_ALIAS="${received_array[20]}"


source $WORK_DIR/scripts/functions.sh
ELAPSEDTIME_STRING=""

print_H2 "INFO:  Print received_array";
echo "WORK_DIR: ${received_array[0]}"
echo "SF_USERNAME: ${received_array[1]}"
echo "SANDBOX_NAME: ${received_array[2]}"
echo "DEPLOY_PATH: ${received_array[3]}"
echo "SFDX_PATH: ${received_array[4]}"
echo "SFDX_REPO_NAME: ${received_array[5]}"
echo "MY_DOMAIN: ${received_array[6]}"
echo "USER_STATUS: ${received_array[7]}"
echo "USER_TYPE: ${received_array[8]}"
echo "SEND_PASSWORD: ${received_array[9]}"
echo "Agent_TempDirectory: ${received_array[10]}"
echo "ORG_USERNAME_IDENT: ${received_array[11]}"
echo "COMPANY_DOMAIN: ${received_array[12]}"
echo "ERROR_HANDLING: ${received_array[13]}"
echo "ACTIVITY_TYPE: ${received_array[14]}"
echo "CSV_FILE_NAME: ${received_array[15]}"
echo "PERSONA: ${received_array[16]}"
echo "USER_EMAIL_ADDRESS: ${received_array[17]}"
echo "FIRST_NAME: ${received_array[18]}"
echo "LAST_NAME: ${received_array[19]}"
echo "USER_ALIAS: ${received_array[20]}"


# Static Strings and other variables
DEPLOY_PATH="$Agent_TempDirectory/deploy"
USERS_LIST_CSV="$Agent_TempDirectory/$CSV_FILE_NAME"
USERS_LIST_CSV_SINGLE="$Agent_TempDirectory/Single_User.csv"
USERS_UPLOAD_CSV="$Agent_TempDirectory/Users-Upload.csv"
USERS_JOB_DIR="$WORK_DIR/scripts/jobs/users"
USER_PERSONA_COMPONENTS_CSV="$USERS_JOB_DIR/UserPersonaComponents.csv"
USER_ID_STRING=''
USER_USERNAME_STRING=''

# ERROR HANDLING
THROW_ERROR=false
ERROR_CAUGHT=false
ERROR_DETAILS=""
MSG_STRING=""

# Error Handling
SHOULD_THROW_ERROR=false
if [ "$ERROR_HANDLING" == 'Do not create any users if some have missing components' ]; then
    SHOULD_THROW_ERROR=true;
    echo "Do not create any users if some have missing components"
    echo "SHOULD_THROW_ERROR: $SHOULD_THROW_ERROR"
fi

declare -A PERSONA_SET;
declare -A Profiles;
declare -A Roles;
declare -A PermSet;
declare -A PermSetGroup;
declare -A Groups;
declare -A Queues;
declare -A DelegAdminGroups;
declare -A UserArray;

HEADING="Prepare job"; print_H2 "$HEADING"; START_TIME=$SECONDS
if [ "$USER_STATUS" = "Activate" ]; then
    echo "User Status is Activate"
    USER_STATUS_FLAG="true"
    active_users_csv_header
else
    echo "User Status is Deactivate"
    USER_STATUS_FLAG="false"
    deactivate_users_csv_header
fi

SB_LOWER="$(echo "$SANDBOX_NAME" | tr '[:upper:]' '[:lower:]')" 
PROVISION_NON_PROD_COMPONENTS=false
if [ "$SB_LOWER" = "prod" ]; then
    echo "Running on Production"
    USER_SUFFIX="" # Before USER_SUFFIX=".$ORG_USERNAME_IDENT" everywhere to add a org_username_identity (Kforce?) not required
    PROVISION_NON_PROD_COMPONENTS=false
    ## NO OTHER ACTIVITY IS AUTHORISED ON PRODUCTION
    if [ "$ACTIVITY_TYPE" != "ProductionUpdatePersona" ] ; then
        ACTIVITY_TYPE="ProductionUserUpdate"
    fi
else
    echo "Running on Sandbox"
    if [ "$ACTIVITY_TYPE" = "Training" ]; then
        echo "Running $ACTIVITY_TYPE"
        USER_SUFFIX=".training.$SB_LOWER"
        PROVISION_NON_PROD_COMPONENTS=false
    elif [ "$ACTIVITY_TYPE" = "OfficialTestUserLoad" ]; then
        USER_SUFFIX=".$SB_LOWER"
        PROVISION_NON_PROD_COMPONENTS=false
    elif [ "$ACTIVITY_TYPE" = "ProductionUserUpdate" ]; then
        USER_SUFFIX=".$SB_LOWER"
        PROVISION_NON_PROD_COMPONENTS=false
    else
        USER_SUFFIX=".$SB_LOWER"
        PROVISION_NON_PROD_COMPONENTS=false
    fi
fi

echo "USER_SUFFIX: $USER_SUFFIX"
echo "Create csv file to import"

if [ -f "$USERS_LIST_CSV" ]; then
    echo "File '$USERS_LIST_CSV' exists."
    echo "Using CSV file"
else

    echo "Prepare single user csv file"
    echo "ACTIVITY_TYPE: $ACTIVITY_TYPE"
    USERS_LIST_CSV="$USERS_LIST_CSV_SINGLE"
    users_list_csv_header
    
    USER_EMAIL_ADDRESS=$(trim_spaces "$USER_EMAIL_ADDRESS")
    EmailAlias="$(echo $USER_EMAIL_ADDRESS | cut -d'@' -f1)"
    EmailDomain="$(echo $USER_EMAIL_ADDRESS | cut -d'@' -f2)"
    echo "EmailAlias: $EmailAlias"
    echo "EmailDomain: $EmailDomain"

    if [ "$ACTIVITY_TYPE" = "ProductionUpdatePersona" ] ; then
        
        echo "USER_ALIAS: '$USER_ALIAS'"
        ## GET INPUT ALIAS, OTHERWISE TAKE LOGGED IN USER
        if ! is_valid_string "$USER_ALIAS"; then
            echo "Using Email Alias: '$EmailAlias'"
            Alias=$EmailAlias
        else
            echo "Using USER_ALIAS: '$USER_ALIAS'"
            Alias="$USER_ALIAS"
        fi
        set_user_defails_from_federated_id "$Alias"

        ## GET INPUT ALIAS, OTHERWISE TAKE LOGGED IN USER
        if ! is_valid_string "$USER_ALIAS"; then
            Alias=$EmailAlias
            USER_ALIAS=$EmailAlias
            echo "Using Email Alias: '$EmailAlias'"
        else
            Alias="$USER_ALIAS"
            USER_ALIAS="$USER_ALIAS"
            echo "Using USER_ALIAS: '$USER_ALIAS'"
        fi
        
        users_list_csv_add_row "$FIRST_NAME" "$LAST_NAME" "$USER_ALIAS" "$USER_EMAIL_ADDRESS" "$PERSONA"

    else
       
        # DO NOT LET USER USE NON COMPANY EMAIL (NOT REQUIRED FOR TPM BECAUSE WE USE THE COMPANY_DOMAIN AS USERNAME SUFIX) -  we do not do this for tpm
        if [ "$EmailDomain" != "$COMPANY_DOMAIN" ] && [ "$EmailDomain" != "salesforce.com" ]; then
            print_H2 "Email address domain is '$EmailDomain'. Username suffix will be moved to $COMPANY_DOMAIN"
        #   print_ERROR "Email address domain is '$EmailDomain'. Domain is required to have the following domain: $COMPANY_DOMAIN"
        #   fail_build_on_error
        #   exit 1;
        fi

        ## If runtime params are empty use default values
        [[ -z "$FIRST_NAME" ]] && FIRST_NAME="${EmailAlias}"
        [[ -z "$LAST_NAME" ]] && LAST_NAME="${PERSONA}"
        [[ -z "$USER_ALIAS" ]] && USER_ALIAS="${EmailAlias}"

        ## Options
        ## - Create or Change Access Levels for your User
        ## - Create or Update a User dedicated for a Persona
        echo "USER_TYPE just before INDIVIDUAL_USER_NAME: $USER_TYPE"
        if [ "$USER_TYPE" == "Create or Change Access Levels for your User" ]; then
            INDIVIDUAL_USER_NAME="${EmailAlias}@${COMPANY_DOMAIN}${USER_SUFFIX}";
        else
            #PERSONA_CLEANED=$(echo "$PERSONA" | tr '[:upper:]' '[:lower:]' | sed 's/[()]//g; s/ /./g; s/\.-//g')
            #INDIVIDUAL_USER_NAME="${EmailAlias}.${PERSONA_CLEANED}@${EmailDomain}${USER_SUFFIX}";
            INDIVIDUAL_USER_NAME="${EmailAlias}@${COMPANY_DOMAIN}${USER_SUFFIX}";
        fi

        echo "INDIVIDUAL_USER_NAME: $INDIVIDUAL_USER_NAME"

        users_list_csv_add_row "$FIRST_NAME" "$LAST_NAME" "$USER_ALIAS" "$USER_EMAIL_ADDRESS" "$PERSONA"
    fi ## END SINGLE USER FILE
fi

if [[ ! -f "$USERS_LIST_CSV" ]]; then
    print_ERROR "$USERS_LIST_CSV file not found"
    fail_build_on_error
else
    print_H2 "PRINT USER CSV with file: $USERS_LIST_CSV"
    cat $USERS_LIST_CSV
fi


########################################
#### GATHER COMPONENT NAMES ############
########################################

HEADING="Gather User Components"; print_H1 "$HEADING"; START_TIME=$SECONDS

print_H2 "Gather Persona Names"
while IFS=',' read -r FirstName LastName FederationIdentifier EmailAddress PersonaName; do
    PersonaName=$(echo -e "$PersonaName" | tr -d '\r\n' | xargs)
    # Check blank line
    if [ ! -z "$PersonaName" ] && [ "$PersonaName" != "" ]; then

        PersonaName=$(echo -e "$PersonaName" | tr -d '\r\n' | xargs)
        echo "Adding PersonaName to set: $PersonaName"
        PERSONA_SET["$PersonaName"]=1

        #is_valid_string "$VoiceGroup" && Groups["$VoiceGroup"]=1

    fi # Check blank line
done < <(tail -n +2 "$USERS_LIST_CSV"; echo)

print_H2 "Collect Persona Components from $USER_PERSONA_COMPONENTS_CSV"
for PersonaName in "${!PERSONA_SET[@]}"; do

    PersonaName=$(echo -e "$PersonaName" | tr -d '\r\n' | xargs)
    echo " "
    echo "Collecting components for '$PersonaName'"

    ProfileName=$(get_profile_name "$(get_persona_field "$PersonaName" 2)")
    RoleName=$(get_role_name "$(get_persona_field "$PersonaName" 3)")
    PublicGroups_STRING=$(get_persona_field "$PersonaName" 13)
    QueueAssignment_STRING=$(get_persona_field "$PersonaName" 14)
    PermSetGroups_STRING=$(get_persona_field "$PersonaName" 15)
    PermSets_STRING=$(get_persona_field "$PersonaName" 16)
    DelegateAdminGroup_STRING=$(get_persona_field "$PersonaName" 19)
    echo "ProfileName: $ProfileName"    
    echo "RoleName: $RoleName"                      
    echo "PublicGroups_STRING: $PublicGroups_STRING"
    echo "QueueAssignment_STRING: $QueueAssignment_STRING"
    echo "PermSetGroups_STRING: $PermSetGroups_STRING"
    echo "PermSets_STRING: $PermSets_STRING"
    echo "DelegateAdminGroup_STRING: $DelegateAdminGroup_STRING"

    add_to_profiles "$ProfileName"
    add_to_roles "$RoleName"
    add_to_groups "$PublicGroups_STRING"
    add_to_queues "$QueueAssignment_STRING"
    add_to_permsetgroups "$PermSetGroups_STRING"
    add_to_permsets "$PermSets_STRING"
    add_to_delegadmingroups "$DelegateAdminGroup_STRING"

    #if [ $PROVISION_NON_PROD_COMPONENTS = true ]; then
        #NonProdVoiceGroups_STRING=$(get_persona_field "$PersonaName" 17)     
        #NonProdChatQueues_STRING=$(get_persona_field "$PersonaName" 18)     
        #echo "NonProdVoiceGroups_STRING: $NonProdVoiceGroups_STRING"
        #echo "NonProdChatQueues_STRING: $NonProdChatQueues_STRING"
        #add_to_groups "$NonProdVoiceGroups_STRING"
        #add_to_queues "$NonProdChatQueues_STRING"
    #fi
done

print_arr_names "Persona Names" PERSONA_SET
print_arr_names "Profile Names" Profiles
print_arr_names "Role Names" Roles
print_arr_names "PermSetGroup Names" PermSetGroup
print_arr_names "PermSet Names" PermSet
print_arr_names "Groups Names" Groups
print_arr_names "Queues Names" Queues

print_ElapsedTime_H1 $START_TIME "$HEADING"
fail_build_on_error


########################################
#### RETRIEVE COMPONENT IDS ############
########################################

if [ "$USER_STATUS" = "Activate" ]; then
    HEADING="Fetch Component Ids"; print_H1 "$HEADING"; START_TIME=$SECONDS
    fetch_profiles "$SF_USERNAME" "$(array_to_string Profiles)"
    fetch_roles "$SF_USERNAME" "$(array_to_string Roles)"
    fetch_permission_sets "$SF_USERNAME" "$(array_to_string PermSet)"
    fetch_permission_set_groups "$SF_USERNAME" "$(array_to_string PermSetGroup)"
    fetch_public_groups "$SF_USERNAME" "$(array_to_string Groups)"
    fetch_queues "$SF_USERNAME" "$(array_to_string Queues)"
    remove_pending_component_entries_with_no_id
    print_ElapsedTime_H1 $START_TIME "$HEADING"
fi

########################################
#### BUILD USER CSV TO LOAD ############
########################################

HEADING="Create Line Items for CSV Users"; print_H1 "$HEADING"; START_TIME=$SECONDS
while IFS=',' read -r FirstName LastName FederationIdentifier EmailAddress PersonaName; do

    PersonaName=$(echo -e "$PersonaName" | tr -d '\r\n' | xargs)

    # Check blank line
    if [ ! -z "$PersonaName" ] && [ "$PersonaName" != "" ]; then

        EmailAddress=$(lowercase_string "$EmailAddress")

        # DOMAIN CHECK
        EmailAlias="$(echo $EmailAddress | cut -d'@' -f1)"
        EmailDomain="$(echo $EmailAddress | cut -d'@' -f2)"

        Username="${EmailAlias}@$COMPANY_DOMAIN${USER_SUFFIX}" #CSV-import
        UserId="${UserArray[$Username]}"
        print_H2 "Processing User: '$Username' with Persona: '$PersonaName'"
        IsActive="$USER_STATUS_FLAG";

        # If deactivating users, just write 2 columns
        if [ "$USER_STATUS_FLAG" = "false" ]; then
            ## START DEACTIVATE USERS
        
            # String to do various tasks like remove user component assignements or send passwords
            USER_USERNAME_STRING="$USER_USERNAME_STRING '$Username',"

            echo "Username: $Username"
            echo "IsActive: $IsActive"
            deactivate_users_csv_add_row "$Username" "$IsActive"
            ## END DEACTIVATE USERS
        else
            
            # Check Persona
            PERSONA_NAME_CHECK=$(grep "^$PersonaName," "$USER_PERSONA_COMPONENTS_CSV" | cut -d',' -f1);
            #echo "PERSONA_NAME_CHECK: '$PERSONA_NAME_CHECK' for PersonaName: '$PersonaName'"
            if [ -z "$PERSONA_NAME_CHECK" ]; then
                print_ERROR "No Persona found with name: '$PersonaName' for user '$Username'"
            else


                # DO NOT LET USER USE NON COMPANY EMAIL IF ITS NOT THE OFFICEAL TEST UESER LOAD 
                #if [ "$ACTIVITY_TYPE" != "OfficialTestUserLoad" ] && [ "$EmailDomain" != "$COMPANY_DOMAIN" ] && [ "$EmailDomain" != "salesforce.com" ]; then
                #   print_ERROR "Email address domain is '$EmailDomain'. Username suffix will be moved to $COMPANY_DOMAIN"
                #   print_ERROR "Email address domain is '$EmailDomain'. Domain is required to have the following domain: $COMPANY_DOMAIN" # - We do not need this for TPM
                #else

                    
                    FirstName=$(trim_spaces "$FirstName")
                    LastName=$(trim_spaces "$LastName")
                    FederationIdentifier=$(trim_spaces "$FederationIdentifier")
                    Alias=$(lowercase_string "$FederationIdentifier")

                    if [ "$ACTIVITY_TYPE" = "ProductionUserUpdate" ] ; then
                        # Production Users get FederationIdentifier
                        FederationIdentifier=$(lowercase_string "$FederationIdentifier")
                    elif [ "$ACTIVITY_TYPE" = "ProductionUpdatePersona" ] ; then
                        # Keep existing production values. Only supports single user updates.
                        Username="$INDIVIDUAL_USER_NAME"
                        FederationIdentifier="$USER_ALIAS"
                        EmailAddress="$INDIVIDUAL_USER_EMAIL"
                    elif [ "$ACTIVITY_TYPE" = "SelfServiceUser" ] ; then
                        Username="$INDIVIDUAL_USER_NAME"
                        # We do not set FederationIdentifier for sandboxes
                        FederationIdentifier=""                    
                    else
                        # We do not set FederationIdentifier for sandboxes
                        FederationIdentifier=""
                    fi
                    
                    USER_USERNAME_STRING="$USER_USERNAME_STRING '$Username',"

                    PROFILE_NAME=$(get_profile_name "$(get_persona_field "$PersonaName" 2)")
                    PROFILE_NAME="${PROFILE_NAME// /_}"
                    ProfileID="${Profiles[$PROFILE_NAME]}"
                    if [ -z "$ProfileID" ]; then
                        print_ERROR "No Id found for Profile Name: '$PROFILE_NAME'"
                    fi
                    
                    ROLE_NAME=$(get_role_name "$(get_persona_field "$PersonaName" 3)")
                    if [ -n "$ROLE_NAME" ]; then
                        ROLE_NAME="${ROLE_NAME// /_}"
                        UserRoleID="${Roles[$ROLE_NAME]}"
                        if [ -z "$UserRoleID" ]; then
                            print_ERROR "No Id found for Role Name: '$ROLE_NAME'"
                        fi
                    fi
                    
                    # Remove dots and cut to the first 8 characters
                    Alias=$(echo "$Alias" | sed 's/\.//g' | cut -c 1-8)
                    LocaleSidKey=$(get_persona_field "$PersonaName" 4)
                    LanguageLocaleKey=$(get_persona_field "$PersonaName" 5)
                    EmailEncodingKey=$(get_persona_field "$PersonaName" 6)
                    TimezoneSidKey=$(get_persona_field "$PersonaName" 7)
                    Department=$(get_persona_field "$PersonaName" 8)
                    UserPermissionsMarketingUser=$(get_persona_field "$PersonaName" 9)
                    UserPermissionsKnowledgeUser=$(get_persona_field "$PersonaName" 10)
                    UserPermissionsInteractionUser=$(get_persona_field "$PersonaName" 11)
                    UserPermissionsSupportUser=$(get_persona_field "$PersonaName" 12)
                    echo "ProfileID: $ProfileID"
                    echo "UserRoleID: $UserRoleID"
                    echo "LocaleSidKey: $LocaleSidKey"
                    echo "LanguageLocaleKey: $LanguageLocaleKey"
                    echo "EmailEncodingKey: $EmailEncodingKey"
                    echo "TimezoneSidKey: $TimezoneSidKey"
                    echo "UserPermissionsMarketingUser: $UserPermissionsMarketingUser"
                    echo "UserPermissionsKnowledgeUser: $UserPermissionsKnowledgeUser"
                    echo "UserPermissionsInteractionUser: $UserPermissionsInteractionUser"
                    echo "UserPermissionsSupportUser: $UserPermissionsSupportUser"

                    echo "PersonaName: $PersonaName"
                    echo "VoiceGroup: $VoiceGroup"

                    active_users_csv_add_row "$UserId" "$PersonaName" "$FirstName" "$LastName" "$Alias" "$FederationIdentifier" "$Username" "$EmailAddress" "$ProfileID" "$UserRoleID" "$LocaleSidKey" "$LanguageLocaleKey" "$EmailEncodingKey" "$TimezoneSidKey" "$Department" "$UserPermissionsMarketingUser" "$UserPermissionsKnowledgeUser" "$UserPermissionsInteractionUser" "$UserPermissionsSupportUser" "$IsActive"
                #fi ## END DOMAIN CHECK
            fi ## END Check Persona
        fi ## END ACTIVATE USER
    fi # Check blank line
done < <(tail -n +2 "$USERS_LIST_CSV"; echo)
print_ElapsedTime_H1 $START_TIME "$HEADING"
fail_build_on_error

HEADING="User CSV file to import"; print_H1 "$HEADING"; START_TIME=$SECONDS
cat $USERS_UPLOAD_CSV;
print_H2 "Load User Data"
START_TIME=$SECONDS

sfdx force:data:bulk:upsert -o $SF_USERNAME -s User -f $USERS_UPLOAD_CSV -i Username -w 60
echo "done"
print_ElapsedTime_H1 $START_TIME "$HEADING"

HEADING="Get User Id, UserName and Persona Name for Users"; print_H1 "$HEADING"; START_TIME=$SECONDS
USER_USERNAME_STRING=${USER_USERNAME_STRING%,}
echo "USER_USERNAME_STRING: $USER_USERNAME_STRING"
QUERY="Select Id, Username, nmspc_test__User_Persona__c FROM User WHERE UserName IN ($USER_USERNAME_STRING)"
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
done
echo "done"
print_ElapsedTime_H1 $START_TIME "$HEADING"

#PRINT WARNINGS AND RESTART MSG STRING
print_warnings; MSG_STRING="";

USER_ID_STRING=""
PERMSET_STRING=""
PERMSETGROUP_STRING=""
PUBLIC_GROUP_STRING=""
QUEUE_STRING=""
CARRIAGE_RETURN=$'\r'

declare -A DELEGATED_ADMIN_SET

if [ "$USER_STATUS" = "Activate" ]; then
    HEADING="Preparing User Component Assignments (from Persona)"; print_H1 "$HEADING"; START_TIME=$SECONDS
else
    HEADING="Gather User Ids to Deactivate"; print_H1 "$HEADING"; START_TIME=$SECONDS
fi

while IFS=',' read -r FirstName LastName FederationIdentifier EmailAddress PersonaName; do
    
    PersonaName=$(echo -e "$PersonaName" | tr -d '\r\n' | xargs)
    EmailAddress=$(lowercase_string "$EmailAddress")

    if [ "$ACTIVITY_TYPE" = "ProductionUpdatePersona" ] ; then
        Username="$INDIVIDUAL_USER_NAME"
    elif [ "$ACTIVITY_TYPE" = "SelfServiceUser" ] ; then
        Username="$INDIVIDUAL_USER_NAME"           
    else
        Username="$Username" #CSV-import
    fi
    
    UserId="${UserArray[$Username]}"

    # Check blank line
    if [ ! -z "$PersonaName" ] && [ "$PersonaName" != "" ]; then

        ## Add USER ID of Test user found for removal of old perm sets assigned
        if [ -z "$UserId" ]; then
            print_ERROR "No Id found for Username: '$Username'"
        else 
            # If deactivating users, just get the user id to add to string
            if [ "$USER_STATUS_FLAG" = "false" ]; then
                echo "Processing User: '$Username' with Id: '$UserId' to remove user components"
                USER_ID_STRING="$USER_ID_STRING '$UserId',"
            else
                # Check Persona
                PERSONA_NAME_CHECK=$(grep "^$PersonaName," "$USER_PERSONA_COMPONENTS_CSV" | cut -d',' -f1);
                if [ -z "$PERSONA_NAME_CHECK" ]; then
                    print_ERROR "No Persona found with name: '$PersonaName'"
                else
                    print_H2 "Processing User: '$Username' with Id: '$UserId' with Persona: '$PersonaName'"
                    USER_ID_STRING="$USER_ID_STRING '$UserId',"

                    PublicGroups_STRING=$(get_persona_field "$PersonaName" 13)
                    QueueAssignment_STRING=$(get_persona_field "$PersonaName" 14)
                    PermSetGroups_STRING=$(get_persona_field "$PersonaName" 15)
                    PermSets_STRING=$(get_persona_field "$PersonaName" 16)
                    DelegateAdminGroup_STRING=$(get_persona_field "$PersonaName" 19)                 
                    echo "PublicGroups_STRING: $PublicGroups_STRING"
                    echo "QueueAssignment_STRING: $QueueAssignment_STRING"
                    echo "PermSetGroups_STRING: $PermSetGroups_STRING"
                    echo "PermSets_STRING: $PermSets_STRING"
                    echo "DelegateAdminGroup_STRING: $DelegateAdminGroup_STRING"

                    #if [ $PROVISION_NON_PROD_COMPONENTS = true ]; then
                        #NonProdVoiceGroups_STRING=$(get_persona_field "$PersonaName" 17)     
                        #NonProdChatQueues_STRING=$(get_persona_field "$PersonaName" 18)     
                        #echo "NonProdVoiceGroups_STRING: $NonProdVoiceGroups_STRING"
                        #echo "NonProdChatQueues_STRING: $NonProdChatQueues_STRING"
                    #fi

                    assign_permsets "$UserId" "$PermSets_STRING" PermSet PERMSET_STRING
                    assign_permset_groups "$UserId" "$PermSetGroups_STRING" PermSetGroup PERMSETGROUP_STRING
                    assign_public_groups "$UserId" "$PublicGroups_STRING" Groups PUBLIC_GROUP_STRING
                    assign_queues "$UserId" "$QueueAssignment_STRING" Queues QUEUE_STRING
                    assign_delegate_admin_groups "$UserId" "$DelegateAdminGroup_STRING" DELEGATED_ADMIN_SET

                fi # END Check Persona    
            fi ## End if [ "$USER_STATUS" = "Activate" ]
        fi # END check UserId
    fi # Check blank line
done < <(tail -n +2 "$USERS_LIST_CSV"; echo)
print_ElapsedTime_H1 $START_TIME "$HEADING"
fail_build_on_error

if [ "$USER_STATUS" = "Activate" ]; then

    HEADING="Preparing User Component Assignments (From User CSV)"; print_H1 "$HEADING"; START_TIME=$SECONDS
    
    while IFS=',' read -r FirstName LastName FederationIdentifier EmailAddress PersonaName; do
        
        PersonaName=$(echo -e "$PersonaName" | tr -d '\r\n' | xargs)
        EmailAddress=$(lowercase_string "$EmailAddress")

        if [ "$ACTIVITY_TYPE" = "ProductionUpdatePersona" ] ; then
            Username="$INDIVIDUAL_USER_NAME"
        elif [ "$ACTIVITY_TYPE" = "SelfServiceUser" ] ; then
            Username="$INDIVIDUAL_USER_NAME"           
        else
            Username="$Username" #CSV-import
        fi
        UserId="${UserArray[$Username]}"

        # Check blank line
        if [ ! -z "$PersonaName" ] && [ "$PersonaName" != "" ]; then
            ## Add USER ID of Test user found for removal of old perm sets assigned
            if [ -z "$UserId" ]; then
                print_ERROR "No Id found for Username: '$Username'. Unable to assign Groups/Queue Components"
            else 
                print_H2 "Processing User: '$Username' with Id: '$UserId' with Persona: '$PersonaName'"
                #assign_queues "$UserId" "$ChatQueue1" Queues QUEUE_STRING

            fi ## #END NO USER ID
        fi ## #END BLANK LINE
    done < <(tail -n +2 "$USERS_LIST_CSV"; echo)
    print_ElapsedTime_H1 $START_TIME "$HEADING"
    fail_build_on_error
fi 

HEADING="Remove User Components"; print_H1 "$HEADING"; START_TIME=$SECONDS
USER_ID_STRING=${USER_ID_STRING%,}
runtimeVars=("$WORK_DIR" "$SF_USERNAME" "$USERS_JOB_DIR" "$USER_ID_STRING");
FILE_PATH="$USERS_JOB_DIR/userComponentAssignments_Remove.sh"
try $FILE_PATH "${runtimeVars[@]}"
print_ElapsedTime_H1 $START_TIME "$HEADING"

if [ "$USER_STATUS" = "Activate" ]; then
    
    HEADING="Assign User Components"; print_H1 "$HEADING"; START_TIME=$SECONDS
    load_permission_sets "$PERMSET_STRING"
    load_permission_set_groups "$PERMSETGROUP_STRING"
    load_public_groups "$PUBLIC_GROUP_STRING"
    load_queues "$QUEUE_STRING"
    print_ElapsedTime_H1 $START_TIME "$HEADING"

    HEADING="Assign Delegated Admin Components"; print_H1 "$HEADING"; START_TIME=$SECONDS
    load_delegated_admin_groups DELEGATED_ADMIN_SET
    print_ElapsedTime_H1 $START_TIME "$HEADING"

    HEADING="Reset User Passwords"; print_H1 "$HEADING"; START_TIME=$SECONDS
    reset_user_passwords "$USER_ID_STRING" "$SEND_PASSWORD" "$ACTIVITY_TYPE"
    print_ElapsedTime_H1 $START_TIME "$HEADING"

fi

print_H2 "Elapsed Times"
echo -e $ELAPSEDTIME_STRING

print_H2 "Finalise Tasks"
fail_build_on_error
print_warnings
exit 0;