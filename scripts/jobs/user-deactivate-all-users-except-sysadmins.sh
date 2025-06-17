#!/usr/bin/env bash
set -euo pipefail

################ USAGE ################
# Assumes you're already loggedin to the CLI
# utils/jobs/user-deactivate-all-users-except-sysadmins.sh DAadast1
# chmod +x utils/jobs/user-deactivate-all-users-except-sysadmins.sh
################ USAGE ################

SF_USERNAME=$1
WORK_DIR=$2
APEXPATH="$WORK_DIR/scripts/jobs/user-deactivate-all-users-except-sysadmins.apex"

echo "==============================================================="
echo "Run utils/jobs/user-deactivate-all-users-except-sysadmins.apex (Runs 100 each time)"
echo "==============================================================="

for ((i = 1; i <= 10; i++)); do
    echo "";
    echo "============================"
    echo "Run #$i"
    echo "============================"

    sf apex run --target-org "$SF_USERNAME" --file $APEXPATH
done

exit 0;