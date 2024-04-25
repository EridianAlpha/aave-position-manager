#!/bin/bash

# Load environment variables from .env file
source .env

STARTING_BLOCK_NUMBER=19510000
BLOCK_NUMBER_INCREMENT=1000
ANVIL_PORT=8123
INITIAL_ETH=1000000000000000000
NETWORK_ARGS="--broadcast --rpc-url http://localhost:$ANVIL_PORT --private-key $ANVIL_PRIVATE_KEY"

response=$(curl -s -X POST $MAINNET_RPC_URL \
    -H "Content-Type: application/json" \
    --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}')
# Extract the block number using jq to parse JSON
LATEST_BLOCK_NUMBER=$(echo $response | jq -r '.result')
# Convert hex to decimal
LATEST_BLOCK_NUMBER=$(printf "%d" "$LATEST_BLOCK_NUMBER")

# Create CSV and add headers
echo "blockNumber, Gas price (gwei), Total gas used for script, Amount required (ETH),ETH Balance, WETH Balance, wstETH Balance, USDC Balance, Aave Collateral Balance (awstETH), Aave Debt Balance, Aave Health Factor" > historicalTestingOutput.csv

# TODO: At this point it could be an offchain check to see if rebalance is needed, but initially just run it onchain

# for (( i=STARTING_BLOCK_NUMBER; i<LATEST_BLOCK_NUMBER; i + BLOCK_NUMBER_INCREMENT ))
for (( i=STARTING_BLOCK_NUMBER; i<STARTING_BLOCK_NUMBER + 3; i++ ))
do
    # TODO: Check to see if the block exists before trying to fork from it
    #       If it doesn't try the next one for e.g. 5 times before exiting
    
    # TODO: Could also check the gas and if it's too high, wait for it to drop before continuing
    #       This would mimic what the offchain bot will do and therefore give a more accurate representation of the gas costs

    # Start Anvil in a separate process
    nohup anvil --port $ANVIL_PORT --fork-url $MAINNET_RPC_URL --fork-block-number $STARTING_BLOCK_NUMBER > anvil.log 2>&1 &
    ANVIL_PID=$!
    # echo "Anvil has been started with PID $ANVIL_PID and is forking from block $i of the mainnet on port $ANVIL_PORT."
    # echo "Waiting for Anvil to be ready..."
    while ! grep -q "Listening on" anvil.log; do
        sleep 0.1  # Check every 0.1 seconds
    done
    # echo "Anvil is ready to accept transactions."

    # Deploy the AavePM contract
    forge script script/DeployAavePM.s.sol:DeployAavePM ${NETWORK_ARGS} > /dev/null 2>&1

    # If it's the first block, fund the AavePM contract
    if [ "$i" -eq "$STARTING_BLOCK_NUMBER" ]; then
        echo "First Block - Funding AavePM contract..."
        forge script script/Interactions.s.sol:FundAavePM ${NETWORK_ARGS} --sig "run(uint256)" ${INITIAL_ETH} > /dev/null 2>&1
    else
        # TODO: To keep it simple to start with, just set the Aave state, as all the other balances should be zero every month anyway right now
        forge script script/Interactions.s.sol:SetAaveStateAavePM ${NETWORK_ARGS} --sig "run(uint256,uint256)" $AAVE_COLLATERAL_BALANCE_AWSTETH $AAVE_DEBT_BALANCE > /dev/null 2>&1
    fi
    
    echo "Processing block $i..."
    OUTPUT=$(forge script script/Interactions.s.sol:RebalanceAavePM ${NETWORK_ARGS})

    # Parse the output to extract required information
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
    AAVE_COLLATERAL_BALANCE_AWSTETH=$(echo "$OUTPUT" | awk '/contractBalance: uint256/ {print $3}')

    OUTPUT=$(forge script script/Interactions.s.sol:GetAaveAccountDataAavePM ${NETWORK_ARGS})
    AAVE_DEBT_BALANCE=$(echo "$OUTPUT" | awk '/totalDebtBase: uint256/ {print $3}')
    AAVE_HEALTH_FACTOR=$(echo "$OUTPUT" | awk '/healthFactor: uint256/ {print $3}')

    # Save the data to the CSV
    echo "$i,$GAS_PRICE,$TOTAL_GAS_USED,$AMOUNT_REQUIRED,$ETH_BALANCE,$WETH_BALANCE,$WSTETH_BALANCE,$USDC_BALANCE,$AAVE_COLLATERAL_BALANCE_AWSTETH,$AAVE_DEBT_BALANCE,$AAVE_HEALTH_FACTOR" >> historicalTestingOutput.csv

    # Stop the Anvil process
    kill $ANVIL_PID
    # echo "Anvil process with PID $ANVIL_PID has been stopped."
done

rm anvil.log
echo "Script completed. Output saved to historicalTestingOutput.csv."
