#!/bin/bash

# ****************************
# Configure .env and constants
# ****************************
source .env
STARTING_BLOCK_NUMBER=19510000
BLOCK_NUMBER_INCREMENT=$((5 * 60 * 24 * 1)) # blocks per day * days
BLOCKS_PER_YEAR=$((5 * 60 * 24 * 365))
ANVIL_PORT=8123
INITIAL_ETH=1000000000000000000
NETWORK_ARGS="--broadcast --rpc-url http://localhost:$ANVIL_PORT --private-key $ANVIL_PRIVATE_KEY"
LATEST_BLOCK_NUMBER=$(cast block-number --rpc-url $MAINNET_RPC_URL)

CSV_FORMAT='$block,$GAS_PRICE,$TOTAL_GAS_USED,$AMOUNT_REQUIRED,$ETH_BALANCE,$WETH_BALANCE,$WSTETH_BALANCE,$USDC_BALANCE,$AAVE_COLLATERAL_BALANCE_BASE_BEFORE,$AAVE_COLLATERAL_BALANCE_BASE_AFTER,$AAVE_COLLATERAL_BALANCE_AWSTETH_BEFORE,$AAVE_COLLATERAL_BALANCE_AWSTETH_AFTER,$AAVE_DEBT_BALANCE_BEFORE,$AAVE_DEBT_BALANCE_AFTER,$AVERAGE_APR_PERIOD_USDC,$AAVE_HEALTH_FACTOR_BEFORE,$AAVE_HEALTH_FACTOR_AFTER,$AAVE_CURRENT_LIQUIDATION_THRESHOLD,$AAVE_LTV'

# ***************************
# Create CSV and add headers
# ***************************
echo "${CSV_FORMAT//$/}" >historicalTestingOutput.csv

# TODO: At this point it could be an offchain check to see if rebalance is needed, but initially just run it onchain

# for ((i = STARTING_BLOCK_NUMBER; i < STARTING_BLOCK_NUMBER + (BLOCK_NUMBER_INCREMENT); i += BLOCK_NUMBER_INCREMENT)); do
for ((block = STARTING_BLOCK_NUMBER; block < LATEST_BLOCK_NUMBER; block += BLOCK_NUMBER_INCREMENT)); do
    # TODO: Could also check the gas and if it's too high, wait for it to drop before continuing
    #       This would mimic what the offchain bot will do and therefore give a more accurate representation of the gas costs

    success=false
    attempts=0

    # Try up to 10 times to find a valid block in case there are missed blocks
    while [[ $attempts -lt 10 ]]; do
        response=$(cast call --block $block --rpc-url $MAINNET_RPC_URL)

        # Check the first word of the response for 'Error'
        if [[ $response =~ ^Error ]]; then
            echo "Error found for block $block, trying next block..."
            ((block++)) # Move to the next block
            ((attempts++))
        else
            success=true
            break # Exit the while loop because a valid block was found
        fi
    done

    # Check if after 10 attempts no valid block was found
    if [[ $success == false ]]; then
        echo "Failed to find a valid block after 10 attempts, starting from block $STARTING_BLOCK_NUMBER."
        exit 1 # Exit the script with an error
    fi

    # Start Anvil in a separate process
    nohup anvil --port $ANVIL_PORT --fork-url $MAINNET_RPC_URL --fork-block-number $STARTING_BLOCK_NUMBER >anvil.log 2>&1 &
    ANVIL_PID=$!
    while ! grep -q "Listening on" anvil.log; do
        sleep 0.1 # Check every 0.1 seconds
    done

    # Deploy the AavePM contract
    forge script script/DeployAavePM.s.sol:DeployAavePM ${NETWORK_ARGS} >/dev/null 2>&1

    # If it's the first block, fund the AavePM contract
    if [ "$block" -eq "$STARTING_BLOCK_NUMBER" ]; then
        echo "First Block - Funding AavePM contract..."
        forge script script/Interactions.s.sol:FundAavePM ${NETWORK_ARGS} --sig "run(uint256)" ${INITIAL_ETH} >/dev/null 2>&1
    else
        echo "Processing block $block..."
        # TODO: Restore the state of other balances if they are not zero (as I won't be depositing dust amounts on mainnet)

        # ****************************
        # Calculate the USDC interest
        # ****************************
        data_file="historicalApyUSDC.csv"

        # Variable to keep track of the current debt
        current_debt=$AAVE_DEBT_BALANCE_AFTER

        period_block_counter=0
        average_apr=0

        # Read each line from the CSV file
        while IFS=, read -r csvBlock csvApy; do
            if ((csvBlock >= block && csvBlock <= block + BLOCK_NUMBER_INCREMENT)); then
                # TODO: This doesn't account for missed blocks and will just not add any interest for those blocks
                # If the block is in the csv then it must be a non-missed block
                # For this row of the CSV (assuming each row is sequential)

                # This calculation estimates the interest for the block
                csvApyScaled=$(echo "1 + $csvApy / 1000000000000000000000000000" | bc -l)
                annual_interest_plus_inital_debt=$(echo "scale=0; $csvApyScaled * $current_debt" | bc -l | sed 's/\..*//')
                annual_interest_only=$(echo "scale=0; $annual_interest_plus_inital_debt - $current_debt" | bc -l | sed 's/\..*//')
                block_interest_only=$(echo "scale=0; $annual_interest_only / $BLOCKS_PER_YEAR" | bc -l | sed 's/\..*//')
                current_debt=$(echo "scale=0; $current_debt + $block_interest_only" | bc -l)
                period_block_counter=$((period_block_counter + 1))
                average_apr=$(echo "scale=0; $average_apr + $csvApy" | bc -l)
            fi
        done < <(tail -n +2 $data_file) # Skip the header of the CSV

        # Update the debt balance to also include the interest
        AAVE_DEBT_BALANCE_AFTER=$current_debt
        AVERAGE_APR_PERIOD_USDC=$(echo "scale=0; $average_apr / $period_block_counter" | bc -l | sed 's/\..*//')

        forge script script/Interactions.s.sol:SetAaveStateAavePM ${NETWORK_ARGS} --sig "run(uint256,uint256)" $AAVE_COLLATERAL_BALANCE_AWSTETH_AFTER $AAVE_DEBT_BALANCE_AFTER >/dev/null 2>&1

        # Store the Aave state before rebalancing
        OUTPUT=$(forge script script/Interactions.s.sol:GetAaveAccountDataAavePM ${NETWORK_ARGS})
        AAVE_DEBT_BALANCE_BEFORE=$(echo "$OUTPUT" | awk '/totalDebtBase: uint256/ {print $3}')
        AAVE_HEALTH_FACTOR_BEFORE=$(echo "$OUTPUT" | awk '/healthFactor: uint256/ {print $3}')
        AAVE_COLLATERAL_BALANCE_BASE_BEFORE=$(echo "$OUTPUT" | awk '/totalCollateralBase: uint256/ {print $3}')

        OUTPUT=$(forge script script/Interactions.s.sol:GetContractBalanceAavePM ${NETWORK_ARGS} --sig "run(string)" "awstETH")
        AAVE_COLLATERAL_BALANCE_AWSTETH_BEFORE=$(echo "$OUTPUT" | awk '/contractBalance: uint256/ {print $3}')
    fi

    OUTPUT=$(forge script script/Interactions.s.sol:RebalanceAavePM ${NETWORK_ARGS})

    # Parse the rebalance output to extract required information
    GAS_PRICE=$(echo "$OUTPUT" | awk '/Estimated gas price:/ {print $4}')
    TOTAL_GAS_USED=$(echo "$OUTPUT" | awk '/Estimated total gas used for script:/ {print $7}')
    AMOUNT_REQUIRED=$(echo "$OUTPUT" | awk '/Estimated amount required:/ {print $4}')

    # Get relevent state values
    OUTPUT=$(forge script script/Interactions.s.sol:GetContractBalanceAavePM ${NETWORK_ARGS} --sig "run(string)" "ETH")
    ETH_BALANCE=$(echo "$OUTPUT" | awk '/contractBalance: uint256/ {print $3}')

    OUTPUT=$(forge script script/Interactions.s.sol:GetContractBalanceAavePM ${NETWORK_ARGS} --sig "run(string)" "WETH")
    WETH_BALANCE=$(echo "$OUTPUT" | awk '/contractBalance: uint256/ {print $3}')

    OUTPUT=$(forge script script/Interactions.s.sol:GetContractBalanceAavePM ${NETWORK_ARGS} --sig "run(string)" "wstETH")
    WSTETH_BALANCE=$(echo "$OUTPUT" | awk '/contractBalance: uint256/ {print $3}')

    OUTPUT=$(forge script script/Interactions.s.sol:GetContractBalanceAavePM ${NETWORK_ARGS} --sig "run(string)" "USDC")
    USDC_BALANCE=$(echo "$OUTPUT" | awk '/contractBalance: uint256/ {print $3}')

    OUTPUT=$(forge script script/Interactions.s.sol:GetContractBalanceAavePM ${NETWORK_ARGS} --sig "run(string)" "awstETH")
    AAVE_COLLATERAL_BALANCE_AWSTETH_AFTER=$(echo "$OUTPUT" | awk '/contractBalance: uint256/ {print $3}')

    OUTPUT=$(forge script script/Interactions.s.sol:GetAaveAccountDataAavePM ${NETWORK_ARGS})
    AAVE_COLLATERAL_BALANCE_BASE_AFTER=$(echo "$OUTPUT" | awk '/totalCollateralBase: uint256/ {print $3}')
    AAVE_DEBT_BALANCE_AFTER=$(echo "$OUTPUT" | awk '/totalDebtBase: uint256/ {print $3}')
    AAVE_HEALTH_FACTOR_AFTER=$(echo "$OUTPUT" | awk '/healthFactor: uint256/ {print $3}')
    AAVE_CURRENT_LIQUIDATION_THRESHOLD=$(echo "$OUTPUT" | awk '/currentLiquidationThreshold: uint256/ {print $3}')
    AAVE_LTV=$(echo "$OUTPUT" | awk '/ltv: uint256/ {print $3}')

    # Save the data to the CSV
    eval "evaluated_format=\"$CSV_FORMAT\""
    echo "$evaluated_format" >>historicalTestingOutput.csv

    # TODO: Add a way to kill the anvil process even when the script is interrupted/terminated
    # Stop the Anvil process
    kill $ANVIL_PID
    # echo "Anvil process with PID $ANVIL_PID has been stopped."
done

rm anvil.log
echo "Script completed. Output saved to historicalTestingOutput.csv."
