#!/bin/bash
set -e

SF_USERNAME=$1
SANDBOX_NAME=$2
SFDX_PIPELINE_REPO=$3
NO_OF_DAYS_TO_KEEP=$4
INCLUDE_SANDBOX_DELETE_RECORDS=$5
TIMES_TO_RUN=$6

if [[ $INCLUDE_SANDBOX_DELETE_RECORDS == 'Yes' ]]; then
    echo " "
    echo "============================================"
    echo "Starting Delete records"
    echo "============================================"
    SOURCE_FILEPATH3="$SFDX_PIPELINE_REPO/scripts/apex/delete-records.apex"

    echo "Update Tags"
    sed -i "s/{SANDBOX_NAME}/$SANDBOX_NAME/g" $SOURCE_FILEPATH3
    sed -i "s/{NO_OF_DAYS_TO_KEEP}/$NO_OF_DAYS_TO_KEEP/g" $SOURCE_FILEPATH3

    # Run the command specified number of times
    for ((i = 1; i <= TIMES_TO_RUN; i++)); do
        echo "Running Job $i"
        sf apex run --file $SOURCE_FILEPATH3 --target-org "$SF_USERNAME" > /dev/null 2>&1
    done
fi

echo "Process Completed Successfully"
exit 0;
