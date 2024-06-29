# ================================================================
# │                 GENERIC MAKEFILE CONFIGURATION               │
# ================================================================
-include .env

.PHONY: clean help install ethernal

help:
	@echo "Usage:"
	@echo "  make deploy-anvil\n

clean 	:; forge clean
update 	:; forge update
build 	:; forge build

# ================================================================
# │                      NETWORK CONFIGURATION                   │
# ================================================================
get-network-args: $(word 2, $(MAKECMDGOALS))-network
anvil: # Added to stop error output when running commands e.g. make deploy anvil
	@echo
anvil-network:
	$(eval \
		NETWORK_ARGS := --broadcast \
						--rpc-url ${ANVIL_RPC_URL} \
						--private-key ${ANVIL_PRIVATE_KEY} \
	)

base-sepolia: # Added to stop error output when running commands e.g. make deploy base-sepolia
	@echo
base-sepolia-network: 
	$(eval \
		NETWORK_ARGS := --broadcast \
			--rpc-url ${BASE_SEPOLIA_RPC_URL} \
			--private-key ${BASE_SEPOLIA_PRIVATE_KEY} \
			--verify \
			--etherscan-api-key ${BASESCAN_API_KEY} \
	)

# base-mainnet: # Added to stop error output when running commands e.g. make deploy base-mainnet
# 	@echo
# base-mainnet-network: 
# 	$(eval \
# 		NETWORK_ARGS := --broadcast \
# 			--rpc-url ${BASE_MAINNET_RPC_URL} \
# 			--private-key ${BASE_MAINNET_PRIVATE_KEY} \
# 			--verify \
# 			--etherscan-api-key ${BASESCAN_API_KEY} \
# 	)

# ================================================================
# │            ETHERNAL BLOCK EXPLORER CONFIGURATION             │
# ================================================================
ethernal:
	ETHERNAL_API_TOKEN=${ETHERNAL_API_TOKEN} ethernal listen --astUpload true
# https://app.tryethernal.com

# ================================================================
# │                   FORK TESTING AND COVERAGE                  │
# ================================================================
test-fork:; forge test --fork-url ${FORK_RPC_URL}
test-fork-v:; forge test --fork-url ${FORK_RPC_URL} -vvvv
test-fork-summary:; forge test --fork-url ${FORK_RPC_URL} --summary

coverage:
	@forge coverage --fork-url ${FORK_RPC_URL} --report summary --report lcov 
	@echo

coverage-report:
	@forge coverage --fork-url ${FORK_RPC_URL} --report debug > coverage-report.txt
	@echo Output saved to coverage-report.txt

# ================================================================
# │                   USER INPUT - ASK FOR VALUE                 │
# ================================================================
ask-for-value:
	@echo "Enter value: "
	@read value; \
	echo $$value > MAKE_CLI_INPUT_VALUE.tmp;

convert-value-to-wei:
	@value=$$(cat MAKE_CLI_INPUT_VALUE.tmp); \
	first_value=$$(echo $$value | cut -d',' -f1); \
	remaining_inputs=$$(echo $$value | cut -d',' -f2-); \
	if [ "$$first_value" = "$$value" ]; then \
		remaining_inputs=""; \
	fi; \
 	wei_value=$$(echo "$$first_value * 10^18 / 1" | bc); \
	if [ -n "$$remaining_inputs" ]; then \
		final_value=$$wei_value,$$remaining_inputs; \
	else \
		final_value=$$wei_value; \
	fi; \
 	echo $$final_value > MAKE_CLI_INPUT_VALUE.tmp;

convert-value-to-USDC:
	@value=$$(cat MAKE_CLI_INPUT_VALUE.tmp); \
	first_value=$$(echo $$value | cut -d',' -f1); \
	remaining_inputs=$$(echo $$value | cut -d',' -f2-); \
	if [ "$$first_value" = "$$value" ]; then \
		remaining_inputs=""; \
	fi; \
 	usdc_value=$$(echo "$$first_value * 10^6 / 1" | bc); \
	if [ -n "$$remaining_inputs" ]; then \
		final_value=$$usdc_value,$$remaining_inputs; \
	else \
		final_value=$$usdc_value; \
	fi; \
 	echo $$final_value > MAKE_CLI_INPUT_VALUE.tmp;

store-value:
	$(eval \
		MAKE_CLI_INPUT_VALUE := $(shell cat MAKE_CLI_INPUT_VALUE.tmp) \
	)

remove-value:
	@rm -f MAKE_CLI_INPUT_VALUE.tmp

# ================================================================
# │                CONTRACT SPECIFIC CONFIGURATION               │
# ================================================================
install:
	forge install foundry-rs/forge-std@v1.7.6 --no-commit && \
	forge install EridianAlpha/foundry-devops@404761e --no-commit && \
	forge install openzeppelin/openzeppelin-contracts@v5.0.1 --no-commit && \
	forge install openzeppelin/openzeppelin-contracts-upgradeable@v5.0.1 --no-commit && \
	forge install uniswap/v3-core --no-commit && \
	forge install uniswap/v3-periphery --no-commit && \
	forge install uniswap/swap-router-contracts --no-commit && \
	forge install aave/aave-v3-core@v1.19.3 --no-commit

# ================================================================
# │                         RUN COMMANDS                         │
# ================================================================
# Interactions script
interactions-script = @forge script script/Interactions.s.sol:Interactions ${NETWORK_ARGS} -vvvv

# Deploy script
deploy-script:; @forge script script/DeployAavePM.s.sol:DeployAavePM ${NETWORK_ARGS} -vvvv
deploy: get-network-args \
	deploy-script

# Upgrade script
upgrade-script:; $(interactions-script) --sig "upgradeAavePM()"
upgrade: get-network-args \
	upgrade-script

# Grant role script
grantRole-script:; $(interactions-script) --sig "grantRoleAavePM(string, address)" $(shell echo $(MAKE_CLI_INPUT_VALUE) | tr ',' ' ')
grantRole: get-network-args \
	ask-for-value \
	store-value \
	grantRole-script \
	remove-value

# Revoke role script
revokeRole-script:; $(interactions-script) --sig "revokeRoleAavePM(string, address)" $(shell echo $(MAKE_CLI_INPUT_VALUE) | tr ',' ' ')
revokeRole: get-network-args \
	ask-for-value \
	store-value \
	revokeRole-script \
	remove-value

# Send ETH script
send-ETH-script:; $(interactions-script) --sig "fundAavePM(uint256)" ${MAKE_CLI_INPUT_VALUE}
send-ETH: get-network-args \
	ask-for-value \
	convert-value-to-wei \
	store-value \
	send-ETH-script \
	remove-value

# Update HFT script
update-hft-script:;	$(interactions-script) --sig "updateHFTAavePM(uint16)" ${MAKE_CLI_INPUT_VALUE}
update-hft: get-network-args \
	ask-for-value \
	store-value \
	update-hft-script \
	remove-value

# Update ST script
update-st-script:; $(interactions-script) --sig "updateSTAavePM(uint16)" ${MAKE_CLI_INPUT_VALUE}
update-st: get-network-args \
	ask-for-value \
	store-value \
	update-st-script \
	remove-value

# Rebalance script
rebalance-script:; $(interactions-script) --sig "rebalanceAavePM()"
rebalance: get-network-args \
	rebalance-script

# Reinvest script
reinvest-script:; $(interactions-script) --sig "reinvestAavePM()"
reinvest: get-network-args \
	reinvest-script

# Deleverage script
deleverage-script:; $(interactions-script) --sig "aaveDeleverageAavePM()"
deleverage: get-network-args \
	deleverage-script

# Close position script
closePosition-script:; $(interactions-script) --sig "aaveClosePositionAavePM(address)" ${MAKE_CLI_INPUT_VALUE}
closePosition: get-network-args \
	ask-for-value \
	store-value \
	closePosition-script \
	remove-value

# Supply script
supply-script:; $(interactions-script) --sig "aaveSupplyAavePM()"
supply: get-network-args \
	supply-script

# Repay script
repay-script:; $(interactions-script) --sig "aaveRepayAavePM()"
repay: get-network-args \
	repay-script

# Withdraw WstETH script
withdrawWstETH-script:; $(interactions-script) --sig "withdrawWstETHAavePM(uint256, address)" $(shell echo $(MAKE_CLI_INPUT_VALUE) | tr ',' ' ')
withdrawWstETH: get-network-args \
	ask-for-value \
	convert-value-to-wei \
	store-value \
	withdrawWstETH-script \
	remove-value

# Borrow USDC script
borrowUSDC-script:; $(interactions-script) --sig "borrowAndWithdrawUSDCAavePM(uint256, address)" $(shell echo $(MAKE_CLI_INPUT_VALUE) | tr ',' ' ')
borrowUSDC: get-network-args \
	ask-for-value \
	convert-value-to-USDC \
	store-value \
	borrowUSDC-script \
	remove-value

# Rescue ETH script
rescueETH-script:; $(interactions-script) --sig "rescueETHAavePM(address)" ${MAKE_CLI_INPUT_VALUE}
rescueETH: get-network-args \
	ask-for-value \
	store-value \
	rescueETH-script \
	remove-value

# Withdraw Token script
withdrawToken-script:; $(interactions-script) --sig "withdrawTokenAavePM(string, address)" $(shell echo $(MAKE_CLI_INPUT_VALUE) | tr ',' ' ')
withdrawToken: get-network-args \
	ask-for-value \
	store-value \
	withdrawToken-script \
	remove-value

# Get Contract Balance script
getContractBalance-script:; $(interactions-script) --sig "getContractBalanceAavePM(string)" ${MAKE_CLI_INPUT_VALUE}
getContractBalance: get-network-args \
	ask-for-value \
	store-value \
	getContractBalance-script \
	remove-value

# Get Aave Account Data script
getAaveAccountData-script:; $(interactions-script) --sig "getAaveAccountDataAavePM()"
getAaveAccountData: get-network-args \
	getAaveAccountData-script
