#!/bin/bash

# Ensure destination directory exists
mkdir -p ~/.cumulusci

# Copy the file
if [ -f "./scripts/cci/core-cumulusci.yml" ]; then
    cp -f ./scripts/cci/core-cumulusci.yml ~/.cumulusci/cumulusci.yml
    echo "Moved cumulusci.yml to ~/.cumulusci/"
else
    echo "Error: cumulusci.yml not found in current directory."
    exit 1
fi