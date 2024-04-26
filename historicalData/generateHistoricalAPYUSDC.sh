#!/bin/bash

source .env
STARTING_BLOCK_NUMBER=19510000
LATEST_BLOCK_NUMBER=$(cast block-number --rpc-url $MAINNET_RPC_URL)
CSV_FILE_NAME_APY="historicalApyUSDC.csv"

# Check if CSV file exists, if not create it with a header
if [ ! -f "$CSV_FILE_NAME_APY" ]; then
    echo "BlockNumber,CurrentVariableBorrowRate" >$CSV_FILE_NAME_APY
fi

# Function to fetch and process data
fetch_data() {
    local block=$1
    echo "Fetching data for block $block ..."
    # Make the RPC call
    response=$(cast call --block $block $MAINNET_ADDRESS_AAVE_POOL "getReserveData(address)" $MAINNET_ADDRESS_USDC --rpc-url $MAINNET_RPC_URL)

    # Extracting the specific hex slice for currentVariableBorrowRate
    rate_hex=$(echo $response | cut -c 259-322)
    uppercase_hex=$(echo "$rate_hex" | awk '{print toupper($0)}')
    rate_decimal=$(echo "ibase=16; $uppercase_hex" | bc)

    # Append to CSV if not already present
    if ! grep -q "^$block," $CSV_FILE_NAME_APY; then
        echo "$block,$rate_decimal" >>$CSV_FILE_NAME_APY
    fi

}

# Loop through the range of blocks
for ((block = $STARTING_BLOCK_NUMBER; block <= $LATEST_BLOCK_NUMBER; block++)); do
    if ! grep -q "^$block," $CSV_FILE_NAME_APY; then
        fetch_data $block
    else
        echo "Skipping block $block, already in CSV."
    fi
done
