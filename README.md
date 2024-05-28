# AavePM - Aave Position Manager

> ---
>
> 🏗️ UNDER DEVELOPMENT 🏗️
>
> ---

- [1. Overview](#1-overview)
  - [1.1. Key Functions](#11-key-functions)
    - [1.1.1. Owner Functions](#111-owner-functions)
    - [1.1.2. Manager Functions](#112-manager-functions)
- [2. WebApp](#2-webapp)
- [3. Installation](#3-installation)
  - [3.1. Clone repository](#31-clone-repository)
  - [3.2. Install Dependencies](#32-install-dependencies)
  - [3.3. Create `.env` file](#33-create-env-file)
  - [3.4. Configure Ethernal (optional)](#34-configure-ethernal-optional)
- [4. Testing](#4-testing)
  - [4.1. Tests](#41-tests)
  - [4.2. Coverage](#42-coverage)
- [5. Deployment](#5-deployment)
- [6. Upgrades](#6-upgrades)
- [7. Interactions](#7-interactions)
  - [7.1. Fund contract with ETH](#71-fund-contract-with-eth)
  - [7.2. Update Health Factor Target](#72-update-health-factor-target)
  - [7.3. Update Slippage Tolerance](#73-update-slippage-tolerance)
  - [7.4. Rebalance](#74-rebalance)
- [8. Build and Deploy Documentation](#8-build-and-deploy-documentation)
- [9. License](#9-license)

## 1. Overview

> Docs Site: [https://eridianalpha.github.io/aave-position-manager](https://eridianalpha.github.io/aave-position-manager)

A smart contract manager for Aave positions.

1. Set a desired Health Factor.
2. Deposit assets (ETH or wstETH) into the position.
3. Rebalance the position to maintain the desired Health Factor, either manually or with a bot.

### 1.1. Key Functions

#### 1.1.1. Owner Functions

| Function | Restrictions | Description |
| -------- | ------------ | ----------- |

#### 1.1.2. Manager Functions

| Function                 | Restrictions   | Description                                                                 |
| ------------------------ | -------------- | --------------------------------------------------------------------------- |
| updateHealthFactorTarget | `MANAGER_ROLE` | Set the desired Health Factor target.                                       |
| borrowAndWithdrawUSDC    | `MANAGER_ROLE` | Borrow USDC from Aave and withdraw to the specified owner.                  |
| withdrawWstETH           | `MANAGER_ROLE` | Withdraw all wstETH from the contract to the specified owner.               |
| repayUSDC                | `MANAGER_ROLE` | Repay USDC to Aave using all the USDC in the contract.                      |
| withdrawTokens           | `MANAGER_ROLE` | Withdraw all the specified tokens from the contract to the specified owner. |
| rebalance                | `MANAGER_ROLE` | Rebalance the Aave position to the desired Health Factor.                   |

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

### 3.3. Create `.env` file

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

| Chain | Command              |
| ----- | -------------------- |
| Anvil | `make upgrade-anvil` |

## 7. Interactions

Interactions are defined in [Interactions.s.sol](./script/Interactions.s.sol).

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

## 8. Build and Deploy Documentation

Instructions on how to build and deploy the documentation book are detailed here: [https://docs.eridianalpha.com/ethereum-dev/foundry-notes/docs-and-github-pages](https://docs.eridianalpha.com/ethereum-dev/foundry-notes/docs-and-github-pages)

## 9. License

[MIT](https://choosealicense.com/licenses/mit/)
