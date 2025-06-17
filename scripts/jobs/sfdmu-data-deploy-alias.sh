#!/usr/bin/env bash

################ USAGE ################
# Assumes you're already loggedin to the CLI
# utils/surface/deactivateRecordType.sh DEVbesta15 DEVbesta15 . MEMBER_ID OBJECT_ID
# chmod +x utils/surface/deactivateRecordType.sh
################ USAGE ################

PCK_PATH=$1
SANDBOX_NAME=$2
SF_USERNAME=$3
MY_DOMAIN=$4

echo "Running sfdmu-data-deploy-alias.sh"
case $SANDBOX_NAME in
    sit|stagingfc|uat|prod)
        echo "$SANDBOX_NAME detected, do nothing."
        ;;
    *)
        SOURCE_BASE_PATH="$PCK_PATH"
        SANDBOX_STR="--$SANDBOX_NAME";
        echo "Checking for folder with alias $SANDBOX_NAME";
        SOURCE_ALIAS_PATH="$SOURCE_BASE_PATH/$SANDBOX_NAME"
        if [ -d "$SOURCE_ALIAS_PATH" ]; then
            SOURCE_ALIAS_FINAL_PATH="$SOURCE_ALIAS_PATH"
            sfdx sfdmu:run \
            --path $SOURCE_ALIAS_FINAL_PATH \
            -s csvfile \
            -u $SF_USERNAME \
            --noprompt \
            --canmodify $MY_DOMAIN$SANDBOX_STR.my.salesforce.com
        else
            echo "Directory $SOURCE_ALIAS_PATH does not exists. We'll use the default folder"
            SOURCE_ALIAS_FINAL_PATH="$SOURCE_BASE_PATH/default"
            sfdx sfdmu:run \
            --path $SOURCE_ALIAS_FINAL_PATH \
            -s csvfile \
            -u $SF_USERNAME \
            --noprompt \
            --canmodify $MY_DOMAIN$SANDBOX_STR.my.salesforce.com
        fi
esac

echo "Process Completed Successfully"
exit 0;