# ================================================================
# │                 GENERIC MAKEFILE CONFIGURATION               │
# ================================================================
-include .env

.PHONY: all test clean help install snapshot format anvil ethernal

help:
	@echo "Usage:"
	@echo "  make deploy-anvil\n

clean 		:; forge clean
remove 		:; rm -rf .gitmodules && rm -rf .git/modules/* && rm -rf lib && touch .gitmodules && git add . && git commit -m "modules"
update 		:; forge update
build 		:; forge build
test 		:; forge test
snapshot 	:; forge snapshot
format 		:; forge fmt

# Configure Anvil
anvil 		:; anvil -m 'test test test test test test test test test test test junk' --steps-tracing  #--block-time 1

# Configure Network Variables
anvil-network:
	$(eval \
		NETWORK_ARGS := --broadcast \
						--rpc-url $(ANVIL_RPC_URL) \
						--private-key $(ANVIL_PRIVATE_KEY) \
	)

holesky-network: 
	$(eval \
		NETWORK_ARGS := --broadcast \
			--rpc-url $(HOLESKY_RPC_URL) \
			--private-key $(HOLESKY_PRIVATE_KEY) \
			--verify \
			--etherscan-api-key $(ETHERSCAN_API_KEY) \
	)

# mainnet-network: 
# 	$(eval \
# 		NETWORK_ARGS := --broadcast \
# 			--rpc-url $(MAINNET_RPC_URL) \
# 			--private-key $(MAINNET_PRIVATE_KEY) \
# 			--verify \
# 			--etherscan-api-key $(ETHERSCAN_API_KEY) \
# 	)


# ================================================================
# │            ETHERNAL BLOCK EXPLORER CONFIGURATION             │
# ================================================================
# https://app.tryethernal.com
ethernal:
	ETHERNAL_API_TOKEN=${ETHERNAL_API_TOKEN} ethernal listen --astUpload true


# ================================================================
# │                CONTRACT SPECIFIC CONFIGURATION               │
# ================================================================
install:
	forge install foundry-rs/forge-std@v1.7.6 --no-commit && \
	forge install Cyfrin/foundry-devops@0.1.0 --no-commit && \
	forge install openzeppelin/openzeppelin-contracts@v5.0.1 --no-commit

deploy:
	@forge script script/DeployAavePM.s.sol:DeployAavePM $(NETWORK_ARGS) -vvvv

deposit-wstEth: 
	@forge script script/Interactions.s.sol:DepositWstEth $(NETWORK_ARGS) -vvvv


# ================================================================
# │                         RUN COMMANDS                         │
# ================================================================
deploy-anvil: anvil-network deploy
deploy-holesky: holesky-network deploy

anvil-deposit-wstEth: anvil-network deposit-wstEth
holesky-deposit-wstEth: holesky-network deposit-wstEth