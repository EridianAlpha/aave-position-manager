# ================================================================
# │                 GENERIC MAKEFILE CONFIGURATION               │
# ================================================================
-include .env

.PHONY: clean help install snapshot format anvil ethernal

help:
	@echo "Usage:"
	@echo "  make deploy-anvil\n

clean 		:; forge clean
update 		:; forge update
build 		:; forge build
snapshot 	:; forge snapshot
format 		:; forge fmt

# Configure Anvil
anvil 		:; anvil -m 'test test test test test test test test test test test junk' --steps-tracing  #--block-time 1

# Configure Network Variables
anvil-network:
	$(eval \
		NETWORK_ARGS := --broadcast \
						--rpc-url ${ANVIL_RPC_URL} \
						--private-key ${ANVIL_PRIVATE_KEY} \
	)

# holesky-network: 
# 	$(eval \
# 		NETWORK_ARGS := --broadcast \
# 			--rpc-url ${HOLESKY_RPC_URL} \
# 			--private-key ${HOLESKY_PRIVATE_KEY} \
# 			--verify \
# 			--etherscan-api-key ${ETHERSCAN_API_KEY} \
# 	)

# mainnet-network: 
# 	$(eval \
# 		NETWORK_ARGS := --broadcast \
# 			--rpc-url ${MAINNET_RPC_URL} \
# 			--private-key ${MAINNET_PRIVATE_KEY} \
# 			--verify \
# 			--etherscan-api-key ${ETHERSCAN_API_KEY} \
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
test-fork-mainnet:; forge test --fork-url ${MAINNET_RPC_URL}
test-fork-mainnet-v:; forge test --fork-url ${MAINNET_RPC_URL} -vvvv
test-fork-mainnet-summary:; forge test --fork-url ${MAINNET_RPC_URL} --summary

coverage:
	@forge coverage --fork-url ${MAINNET_RPC_URL} --report summary --report lcov 
	@echo

coverage-report:
	@forge coverage --fork-url ${MAINNET_RPC_URL} --report debug > coverage-report.txt
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
	wei_value=$$(echo "$$value * 10^18 / 1" | bc); \
	echo $$wei_value > MAKE_CLI_INPUT_VALUE.tmp;

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
	forge install aave/aave-v3-core@v1.19.3 --no-commit
	

# ================================================================
# │                           SCRIPTS                            │
# ================================================================
deploy-script:
	@forge script script/DeployAavePM.s.sol:DeployAavePM ${NETWORK_ARGS} -vvvv

send-ETH-script: 
	@forge script script/Interactions.s.sol:FundAavePM ${NETWORK_ARGS} -vvvv --sig "run(uint256)" ${MAKE_CLI_INPUT_VALUE}

wrap-ETH-WETH-script:
	@forge script script/Interactions.s.sol:WrapETHToWETH ${NETWORK_ARGS} -vvvv

unwrap-WETH-ETH-script:
	@forge script script/Interactions.s.sol:UnwrapWETHToETH ${NETWORK_ARGS} -vvvv

swap-ETH-USDC-script:
	@forge script script/Interactions.s.sol:SwapTokensAavePM ${NETWORK_ARGS} -vvvv --sig "run(string, string, string)" "USDC/ETH" "ETH" "USDC"

swap-USDC-WETH-script:
	@forge script script/Interactions.s.sol:SwapTokensAavePM ${NETWORK_ARGS} -vvvv --sig "run(string, string, string)" "USDC/ETH" "USDC" "WETH"

swap-ETH-wstETH-script:
	@forge script script/Interactions.s.sol:SwapTokensAavePM ${NETWORK_ARGS} -vvvv --sig "run(string, string, string)" "wstETH/ETH" "ETH" "wstETH"

swap-wstETH-ETH-script:
	@forge script script/Interactions.s.sol:SwapTokensAavePM ${NETWORK_ARGS} -vvvv --sig "run(string, string, string)" "wstETH/ETH" "wstETH" "ETH"

update-hft-script:
	@forge script script/Interactions.s.sol:UpdateHFTAavePM ${NETWORK_ARGS} -vvvv --sig "run(uint16)" ${MAKE_CLI_INPUT_VALUE}

# ================================================================
# │                       COMBINED COMMANDS                      │
# ================================================================
send-ETH: ask-for-value convert-value-to-wei store-value send-ETH-script remove-value
update-hft: ask-for-value store-value update-hft-script remove-value

# ================================================================
# │                         RUN COMMANDS                         │
# ================================================================
deploy-anvil: anvil-network deploy-script
send-ETH-anvil: anvil-network send-ETH
wrap-ETH-WETH-anvil: anvil-network wrap-ETH-WETH-script
unwrap-WETH-ETH-anvil: anvil-network unwrap-WETH-ETH-script
swap-ETH-USDC-anvil: anvil-network swap-ETH-USDC-script
swap-USDC-WETH-anvil: anvil-network swap-USDC-WETH-script
swap-ETH-wstETH-anvil: anvil-network swap-ETH-wstETH-script
swap-wstETH-ETH-anvil: anvil-network swap-wstETH-ETH-script
update-hft-anvil: anvil-network update-hft