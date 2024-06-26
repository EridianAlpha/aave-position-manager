# AavePM - Aave Position Manager

> ---
>
> 🧪 ALPHA TESTING PHASE 🧪
>
> ---

* [1. Overview](#1-overview)
  * [1.1. Key Functions](#11-key-functions)
    * [1.1.1. Owner Functions](#111-owner-functions)
    * [1.1.2. Manager Functions](#112-manager-functions)
* [2. WebApp](#2-webapp)
* [3. Installation](#3-installation)
  * [3.1. Clone repository](#31-clone-repository)
  * [3.2. Install Dependencies](#32-install-dependencies)
  * [3.3. Create the `.env` file](#33-create-the-env-file)
  * [3.4. Configure Ethernal (optional)](#34-configure-ethernal-optional)
* [4. Testing](#4-testing)
  * [4.1. Tests (Fork)](#41-tests-fork)
  * [4.2. Coverage (Fork)](#42-coverage-fork)
* [5. Deployment](#5-deployment)
* [6. Upgrades](#6-upgrades)
* [7. Interactions](#7-interactions)
  * [7.1. Fund contract with ETH](#71-fund-contract-with-eth)
  * [7.2. Update Health Factor Target](#72-update-health-factor-target)
  * [7.3. Update Slippage Tolerance](#73-update-slippage-tolerance)
  * [7.4. Rebalance Aave Position](#74-rebalance-aave-position)
  * [7.5. Reinvest collateral](#75-reinvest-collateral)
  * [7.6. Supply from contract balance to Aave](#76-supply-from-contract-balance-to-aave)
  * [7.7. Repay USDC from contract balance](#77-repay-usdc-from-contract-balance)
  * [7.8. Close Position](#78-close-position)
  * [7.9. Withdraw wstETH to owner](#79-withdraw-wsteth-to-owner)
  * [7.10. Withdraw Token to owner](#710-withdraw-token-to-owner)
  * [7.11. Borrow USDC and send to owner](#711-borrow-usdc-and-send-to-owner)
  * [7.12. Get Contract Balance](#712-get-contract-balance)
  * [7.13. Get Aave Account Data](#713-get-aave-account-data)
* [8. Build and Deploy Documentation](#8-build-and-deploy-documentation)
* [9. License](#9-license)

## 1. Overview

> Docs Site: [https://eridianalpha.github.io/aave-position-manager](https://eridianalpha.github.io/aave-position-manager)

A smart contract manager for Aave positions.

1. Set a desired Health Factor.
2. Send assets (ETH, WETH, wstETH, or USDC) to the contract.
3. Reinvest and rebalance the position to maintain the desired Health Factor, either manually or with a bot.
4. Borrow and withdraw USDC from the position while maintaining the desired Health Factor.

### 1.1. Key Functions

#### 1.1.1. Owner Functions

| Function                          | Restrictions | Description                                             |
| --------------------------------- | ------------ | ------------------------------------------------------- |
| upgradeToAndCall                  | `OWNER_ROLE` | Upgrade the contract.                                   |
| updateContractAddress             | `OWNER_ROLE` | Update the specified contract address.                  |
| updateTokenAddress                | `OWNER_ROLE` | Update the specified token address.                     |
| updateUniswapV3Pool               | `OWNER_ROLE` | Update the specified Uniswap V3 pool.                   |
| updateManagerDailyInvocationLimit | `OWNER_ROLE` | Update the daily invocation limit for the manager role. |

#### 1.1.2. Manager Functions

| Function                          | Restrictions   | Description                                                                                         |
| --------------------------------- | -------------- | --------------------------------------------------------------------------------------------------- |
| rebalance                         | `MANAGER_ROLE` | Rebalance the Aave position to the desired Health Factor.                                           |
| reinvest                          | `MANAGER_ROLE` | Reinvest the Aave position to the desired Health Factor target.                                     |
| deleverage                        | `MANAGER_ROLE` | Deleverage the Aave position by paying back all reinvested debt.                                    |
| aaveSupplyFromContractBalance     | `MANAGER_ROLE` | Supply all the collateral from the contract balance to Aave.                                        |
| aaveRepayUSDCFromContractBalance  | `MANAGER_ROLE` | Repay Aave position debt using all the USDC from the contract balance.                              |
| withdrawTokensFromContractBalance | `MANAGER_ROLE` | Withdraw all the specified tokens from the contract to the specified owner.                         |
| aaveBorrowAndWithdrawUSDC         | `MANAGER_ROLE` | Borrow USDC from Aave and withdraw to the specified owner.                                          |
| aaveWithdrawWstETH                | `MANAGER_ROLE` | Withdraw wstETH collateral from the Aave position to the specified owner.                           |
| aaveClosePosition                 | `MANAGER_ROLE` | Close the Aave position by repaying all debt and withdrawing all collateral to the specified owner. |
| updateHealthFactorTarget          | `MANAGER_ROLE` | Set the desired Health Factor target.                                                               |
| updateSlippageTolerance           | `MANAGER_ROLE` | Set the slippage tolerance for Uniswap V3 swaps.                                                    |
| rescueEth                         | `MANAGER_ROLE` | Rescue ETH from the contract to the specified owner.                                                |
| delegateCallHelper                | `MANAGER_ROLE` | Execute a delegate call to the specified module.                                                    |

## 2. WebApp

A WebApp is being developed to allow easy interaction with the smart contract and will be linked here when available.

## 3. Installation

### 3.1. Clone repository

```bash
git clone https://github.com/EridianAlpha/aave-position-manager.git
```

### 3.2. Install Dependencies

This should happen automatically when first running a command, but the installation can be manually triggered with the following commands:

```bash
git submodule init
git submodule update
make install
```

### 3.3. Create the `.env` file

Use the `.env.example` file as a template to create a `.env` file.

### 3.4. Configure Ethernal (optional)

Configure an Ethernal account to interact with the smart contract through a UI. Ethernal is like Etherscan but for a custom network.

[https://docs.eridianalpha.com/ethereum-dev/useful-tools/ethernal](https://docs.eridianalpha.com/ethereum-dev/useful-tools/ethernal)

```bash
make ethernal
```

## 4. Testing

### 4.1. Tests (Fork)

```bash
make test-fork
make test-fork-v
make test-fork-summary
```

### 4.2. Coverage (Fork)

```bash
make coverage
make coverage-report
```

## 5. Deployment

Deploys AavePM and all modules to the Anvil chain specified in the `.env` file.

| Chain        | Command                    |
| ------------ | -------------------------- |
| Anvil        | `make deploy anvil`        |
| Base Mainnet | `make deploy base-mainnet` |

## 6. Upgrades

Upgrade the contract to a new logic implementation while maintaining the same proxy address.
This also redeploys all modules and updates their contract addresses on AavePM.

| Chain        | Command                     |
| ------------ | --------------------------- |
| Anvil        | `make upgrade anvil`        |
| Base Mainnet | `make upgrade base-mainnet` |

## 7. Interactions

Interactions are defined in `./script/Interactions.s.sol`

If `DEPLOYED_CONTRACT_ADDRESS` is set in the `.env` file, that contract address will be used for interactions.
If that variable is not set, the latest deployment on the specified chain will be used.

### 7.1. Fund contract with ETH

Input value in ETH e.g. `0.15`.

| Chain        | Command                      |
| ------------ | ---------------------------- |
| Anvil        | `make send-ETH anvil`        |
| Base Mainnet | `make send-ETH base-mainnet` |

### 7.2. Update Health Factor Target

Input value to 2 decimal places e.g. `225` for a Health Factor target of `2.25`.

| Chain        | Command                        |
| ------------ | ------------------------------ |
| Anvil        | `make update-hft anvil`        |
| Base Mainnet | `make update-hft base-mainnet` |

### 7.3. Update Slippage Tolerance

Input value to 2 decimal places e.g. `200` for a Slippage Tolerance of `0.5%`.

| Chain        | Command                       |
| ------------ | ----------------------------- |
| Anvil        | `make update-st anvil`        |
| Base Mainnet | `make update-st base-mainnet` |

### 7.4. Rebalance Aave Position

Rebalances the Aave position to maintain the desired Health Factor target.
`REBALANCE_HFT_BUFFER` is a constant in the module that determines if a rebalance is required.

| Chain        | Command                       |
| ------------ | ----------------------------- |
| Anvil        | `make rebalance anvil`        |
| Base Mainnet | `make rebalance base-mainnet` |

### 7.5. Reinvest collateral

Reinvests any collateral above the Health Factor target.
`REINVEST_HFT_BUFFER` is a constant in the module that determines if a reinvest is required.

| Chain        | Command                      |
| ------------ | ---------------------------- |
| Anvil        | `make reinvest anvil`        |
| Base Mainnet | `make reinvest base-mainnet` |

### 7.6. Supply from contract balance to Aave

Supplies any ETH, WETH, wstETH, or USDC in the contract to Aave.

| Chain        | Command                    |
| ------------ | -------------------------- |
| Anvil        | `make supply anvil`        |
| Base Mainnet | `make supply base-mainnet` |

### 7.7. Repay USDC from contract balance

Repay any USDC debt in the contract to repay Aave position debt.

| Chain        | Command                   |
| ------------ | ------------------------- |
| Anvil        | `make repay anvil`        |
| Base Mainnet | `make repay base-mainnet` |

### 7.8. Close Position

Close the Aave position by repaying all debt and withdrawing all collateral.
Input value as an owner address. e.g. `0x123...`.

| Chain        | Command                           |
| ------------ | --------------------------------- |
| Anvil        | `make closePosition anvil`        |
| Base Mainnet | `make closePosition base-mainnet` |

### 7.9. Withdraw wstETH to owner

Withdraw wstETH collateral from the Aave position to the specified owner.
Input value 1 in ETH e.g. `0.15`.
Input value 2 as an owner address e.g. `0x123...`.
Combined input value e.g. `0.15,0x123...`.

| Chain        | Command                            |
| ------------ | ---------------------------------- |
| Anvil        | `make withdrawWstETH anvil`        |
| Base Mainnet | `make withdrawWstETH base-mainnet` |

### 7.10. Withdraw Token to owner

Withdraw the specified token from the contract to the specified owner.
Input value 1 in token identifier e.g. `USDC`.
Input value 2 as an owner address e.g. `0x123...`.
Combined input value e.g. `USDC,0x123...`.

| Chain        | Command                           |
| ------------ | --------------------------------- |
| Anvil        | `make withdrawToken anvil`        |
| Base Mainnet | `make withdrawToken base-mainnet` |

### 7.11. Borrow USDC and send to owner

Borrow USDC from Aave and withdraw to the specified owner.
Input value 1 in USDC e.g. `200` for $200 USDC.
Input value 2 as an owner address e.g. `0x123...`.
Combined input value e.g. `200,0x123...`.

| Chain        | Command                        |
| ------------ | ------------------------------ |
| Anvil        | `make borrowUSDC anvil`        |
| Base Mainnet | `make borrowUSDC base-mainnet` |

### 7.12. Get Contract Balance

Input value as token identifier e.g. `USDC`.

| Chain        | Command                                |
| ------------ | -------------------------------------- |
| Anvil        | `make getContractBalance anvil`        |
| Base Mainnet | `make getContractBalance base-mainnet` |

### 7.13. Get Aave Account Data

Returns the Aave account data for the contract.

| Chain        | Command                                |
| ------------ | -------------------------------------- |
| Anvil        | `make getAaveAccountData anvil`        |
| Base Mainnet | `make getAaveAccountData base-mainnet` |

## 8. Build and Deploy Documentation

Instructions on how to build and deploy the documentation book are detailed here: [https://docs.eridianalpha.com/ethereum-dev/foundry-notes/docs-and-github-pages](https://docs.eridianalpha.com/ethereum-dev/foundry-notes/docs-and-github-pages)

## 9. License

[MIT](https://choosealicense.com/licenses/mit/)
