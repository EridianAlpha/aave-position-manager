# AavePM - Aave Position Manager

> ---
>
> 🏗️ UNDER DEVELOPMENT 🏗️
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
  * [4.1. Tests](#41-tests)
  * [4.2. Coverage](#42-coverage)
* [5. Deployment](#5-deployment)
* [6. Upgrades](#6-upgrades)
* [7. Interactions](#7-interactions)
  * [7.1. Fund contract with ETH](#71-fund-contract-with-eth)
  * [7.2. Update Health Factor Target](#72-update-health-factor-target)
  * [7.3. Update Slippage Tolerance](#73-update-slippage-tolerance)
  * [7.4. Rebalance](#74-rebalance)
  * [7.5. Reinvest](#75-reinvest)
  * [7.6. Supply](#76-supply)
  * [7.7. Repay](#77-repay)
  * [7.8. Close Position](#78-close-position)
  * [7.9. Withdraw wstETH](#79-withdraw-wsteth)
  * [7.10. Borrow USDC](#710-borrow-usdc)
  * [7.11. Get Contract Balance](#711-get-contract-balance)
  * [7.12. Get Aave Account Data](#712-get-aave-account-data)
* [8. Build and Deploy Documentation](#8-build-and-deploy-documentation)
* [9. License](#9-license)

## 1. Overview

> Docs Site: [https://eridianalpha.github.io/aave-position-manager](https://eridianalpha.github.io/aave-position-manager)

A smart contract manager for Aave positions.

1. Set a desired Health Factor.
2. Deposit assets (ETH, WETH, wstETH or USDC) into the position.
3. Reinvest and rebalance the position to maintain the desired Health Factor, either manually or with a bot.

### 1.1. Key Functions

#### 1.1.1. Owner Functions

| Function              | Restrictions | Description                            |
| --------------------- | ------------ | -------------------------------------- |
| upgradeToAndCall      | `OWNER_ROLE` | Upgrade the contract.                  |
| updateContractAddress | `OWNER_ROLE` | Update the specified contract address. |
| updateTokenAddress    | `OWNER_ROLE` | Update the specified token address.    |
| updateUniswapV3Pool   | `OWNER_ROLE` | Update the specified Uniswap V3 pool.  |

#### 1.1.2. Manager Functions

| Function                          | Restrictions   | Description                                                                  |
| --------------------------------- | -------------- | ---------------------------------------------------------------------------- |
| rebalance                         | `MANAGER_ROLE` | Rebalance the Aave position to the desired Health Factor.                    |
| reinvest                          | `MANAGER_ROLE` | Reinvest the Aave position to the desired Health Factor target.              |
| deleverage                        | `MANAGER_ROLE` | Deleverage the Aave position by paying back all reinvested debt.             |
| aaveSupplyFromContractBalance     | `MANAGER_ROLE` | Supply all the collateral from the contract balance to Aave.                 |
| aaveRepayUSDCFromContractBalance  | `MANAGER_ROLE` | Repay Aave position debt using all the USDC from the contract balance.       |
| withdrawTokensFromContractBalance | `MANAGER_ROLE` | Withdraw all the specified tokens from the contract to the specified owner.  |
| aaveBorrowAndWithdrawUSDC         | `MANAGER_ROLE` | Borrow USDC from Aave and withdraw to the specified owner.                   |
| aaveWithdrawWstETH                | `MANAGER_ROLE` | Withdraw wstETH collateral from the Aave position to the specified owner.    |
| aaveClosePosition                 | `MANAGER_ROLE` | Close the Aave position by repaying all debt and withdrawing all collateral. |
| updateHealthFactorTarget          | `MANAGER_ROLE` | Set the desired Health Factor target.                                        |
| updateSlippageTolerance           | `MANAGER_ROLE` | Set the slippage tolerance for Uniswap V3 swaps.                             |
| rescueEth                         | `MANAGER_ROLE` | Rescue ETH from the contract to the specified owner.                         |

## 2. WebApp

A WebApp is being developed to allow easy interaction with the smart contract and will be linked here when ready.

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

Configure an Ethernal account to interact with the smart contract through a UI (like Etherscan but for a local network).

[https://docs.eridianalpha.com/ethereum-dev/useful-tools/ethernal](https://docs.eridianalpha.com/ethereum-dev/useful-tools/ethernal)

```bash
make ethernal
```

## 4. Testing

### 4.1. Tests

```bash
make test-fork-mainnet
make test-fork-mainnet-v
make test-fork-mainnet-summary
```

### 4.2. Coverage

```bash
make coverage
make coverage-report
```

## 5. Deployment

| Chain | Command             |
| ----- | ------------------- |
| Anvil | `make deploy-anvil` |

## 6. Upgrades

Upgrade the contract to a new logic implementation while maintaining the same proxy address.

| Chain | Command              |
| ----- | -------------------- |
| Anvil | `make upgrade-anvil` |

## 7. Interactions

Interactions are defined in `./script/Interactions.s.sol`

### 7.1. Fund contract with ETH

Input value in ETH e.g. `0.15`.

| Chain | Command               |
| ----- | --------------------- |
| Anvil | `make send-ETH-anvil` |

### 7.2. Update Health Factor Target

Input value to 2 decimal places e.g. `225` for a Health Factor target of `2.25`.

| Chain | Command                 |
| ----- | ----------------------- |
| Anvil | `make update-hft-anvil` |

### 7.3. Update Slippage Tolerance

Input value to 2 decimal places e.g. `200` for a Slippage Tolerance of `0.5%`.

| Chain | Command                |
| ----- | ---------------------- |
| Anvil | `make update-st-anvil` |

### 7.4. Rebalance

Rebalances the Aave position to maintain the desired Health Factor target.
TODO: Add threshold details.

| Chain | Command                |
| ----- | ---------------------- |
| Anvil | `make rebalance-anvil` |

### 7.5. Reinvest

Reinvests any collateral above the Health Factor target.

| Chain | Command               |
| ----- | --------------------- |
| Anvil | `make reinvest-anvil` |

### 7.6. Supply

Supplies any ETH, WETH, wstETH or USDC in the contract to Aave.

| Chain | Command             |
| ----- | ------------------- |
| Anvil | `make supply-anvil` |

### 7.7. Repay

Repay any USDC debt in the contract to repay Aave position debt.

| Chain | Command            |
| ----- | ------------------ |
| Anvil | `make repay-anvil` |

### 7.8. Close Position

Close the Aave position by repaying all debt and withdrawing all collateral.

| Chain | Command                    |
| ----- | -------------------------- |
| Anvil | `make closePosition-anvil` |

### 7.9. Withdraw wstETH

Withdraw wstETH collateral from the Aave position to the specified owner.

| Chain | Command                     |
| ----- | --------------------------- |
| Anvil | `make withdrawWstETH-anvil` |

### 7.10. Borrow USDC

Borrow USDC from Aave and withdraw to the specified owner.

| Chain | Command                 |
| ----- | ----------------------- |
| Anvil | `make borrowUSDC-anvil` |

### 7.11. Get Contract Balance

Input value as token identifier e.g. `USDC`.

| Chain | Command                         |
| ----- | ------------------------------- |
| Anvil | `make getContractBalance-anvil` |

### 7.12. Get Aave Account Data

Returns the Aave account data for the contract.

| Chain | Command                         |
| ----- | ------------------------------- |
| Anvil | `make getAaveAccountData-anvil` |

## 8. Build and Deploy Documentation

Instructions on how to build and deploy the documentation book are detailed here: [https://docs.eridianalpha.com/ethereum-dev/foundry-notes/docs-and-github-pages](https://docs.eridianalpha.com/ethereum-dev/foundry-notes/docs-and-github-pages)

## 9. License

[MIT](https://choosealicense.com/licenses/mit/)
