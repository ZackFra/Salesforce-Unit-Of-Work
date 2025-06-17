#!/usr/bin/env bash

################ USAGE ################
# Assumes you're already loggedin to the CLI
# utils/jobs/removeApexClassAsLines.sh /Users/adam.best/Documents/workspace/A-Salesforce-FS/Salesforce-FS/src
# chmod +x utils/jobs/removeApexClassAsLines.sh
################ USAGE ################

SCANNIG_PATH=$1

echo "";
echo "";
echo "===========================";
echo "INFO: remove lines from apex classes with update as, insert as, upsert as or delete as";
echo "===========================";

root_path="$SCANNIG_PATH"

# Find all directories named "classes" under the specified root
find "$root_path" -type d -name "classes" | while read -r classes_dir; do
    echo "Processing files in: $classes_dir"

    # Perform your job for each file in the "classes" directory
    for file in "$classes_dir"/*; do
        #echo "Processing file: $file"
        # Remove lines containing "update as " or "insert as " from the file
        sed -i -E '/update as |insert as |delete as |upsert as /d' "$file"
    done
done
echo "Completed"
exit 0;