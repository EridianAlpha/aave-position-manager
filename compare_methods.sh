#!/bin/bash

# ANSI color codes
RED='\033[0;31m'
BOLD='\033[1m'
RESET='\033[0m' # No color

# Check if three arguments are passed
if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <interface_contract_file_path> <contract_name> <ignore_list>"
    exit 1
fi

# Assign the arguments to variables
INTERFACE_CONTRACT_FILE="$1"
CONTRACT_NAME="$2"
IGNORE_LIST="$3"

# Convert ignore list string to an array
IFS=',' read -ra IGNORE_ARRAY <<< "$IGNORE_LIST"

# Initialize allMatched to 1 (true)
allMatched=1

# Get method identifiers from the contract
METHODS=$(forge inspect "$CONTRACT_NAME" methodIdentifiers | jq -r 'keys[]')

# Loop through each method in the contract
for METHOD in $METHODS; do
    METHOD_NAME=$(echo "$METHOD" | cut -d'(' -f1)

    # Skip if the method name is in the ignore array
    if printf '%s\n' "${IGNORE_ARRAY[@]}" | grep -qxE "\b$METHOD_NAME\b"; then
        continue
    fi

    # Count occurrences in the contract
    CONTRACT_COUNT=$(grep -ow "$METHOD_NAME" <<< "$METHODS" | wc -l)

    # Count occurrences in the interface contract file
    INTERFACE_COUNT=$(grep -ow "$METHOD_NAME" "$INTERFACE_CONTRACT_FILE" | wc -l)

    # Check for the presence and the count match of the method name
    if [[ $INTERFACE_COUNT -eq 0 ]]; then
        echo -e "${CONTRACT_NAME} 🔎 Method NOT found in interface contract: ${RED}${BOLD}$METHOD_NAME${RESET}"
        allMatched=0
    elif [[ $CONTRACT_COUNT -ne $INTERFACE_COUNT ]]; then
        echo -e "${CONTRACT_NAME} ☢️  Mismatch in occurrences for method: ${RED}${BOLD}$METHOD_NAME${RESET}"
        allMatched=0
    fi
done

# Output the result based on allMatched
if [ "$allMatched" -eq 1 ]; then
    echo "---"
fi
