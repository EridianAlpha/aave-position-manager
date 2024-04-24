# AavePM - Aave Position Manager

> ---
>
> 🏗️ UNDER DEVELOPMENT 🏗️
>
> ---

* [1. Overview](#1-overview)
  * [1.1. Key Functions](#11-key-functions)
* [2. WebApp](#2-webapp)
* [3. Installation](#3-installation)
  * [3.1. Clone repository](#31-clone-repository)
  * [3.2. Install Dependencies](#32-install-dependencies)
  * [3.3. Create `.env` file](#33-create-env-file)
  * [3.4. Configure Ethernal (optional)](#34-configure-ethernal-optional)
* [4. Testing](#4-testing)
  * [4.1. Tests](#41-tests)
  * [4.2. Coverage](#42-coverage)
* [5. Deployment](#5-deployment)
* [6. Upgrades](#6-upgrades)
* [7. Interactions](#7-interactions)
  * [7.1. Fund contract with ETH](#71-fund-contract-with-eth)
  * [7.2. Wrap/Unwrap WETH](#72-wrapunwrap-weth)
  * [7.3. Swap Tokens](#73-swap-tokens)
  * [7.4. Update Health Factor Target](#74-update-health-factor-target)
  * [7.5. Aave Supply wstETH](#75-aave-supply-wsteth)
  * [7.6. Aave Borrow USDC](#76-aave-borrow-usdc)
  * [7.7. Rebalance](#77-rebalance)
* [8. Build and Deploy Documentation](#8-build-and-deploy-documentation)
* [9. License](#9-license)

## 1. Overview

> Docs Site: [https://eridianalpha.github.io/aave-position-manager](https://eridianalpha.github.io/aave-position-manager)

A smart contract manager for Aave positions.

1. Set a desired Health Factor.
2. Deposit assets (ETH or wstETH) into the position.
3. Rebalance the position to maintain the desired Health Factor, either manually or with a bot.

### 1.1. Key Functions

| Function          | Restrictions   | Description                                               |
| ----------------- | -------------- | --------------------------------------------------------- |
| deposit()         | `MANAGER_ROLE` | Deposit ETH or wstETH.                                    |
| rebalance()       | `MANAGER_ROLE` | Rebalance the Aave position to the desired Health Factor. |
| setHealthFactor() | `OWNER_ROLE`   | Set the desired Health Factor.                            |
| withdraw()        | `OWNER_ROLE`   | Withdraw wstETH while maintaining desired Health Factor.  |

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

Under development 🏗️

## 7. Interactions

Interactions are defined in [Interactions.s.sol](./script/Interactions.s.sol).

### 7.1. Fund contract with ETH

Input value in ETH e.g. `0.15`.

| Chain | Command               |
| ----- | --------------------- |
| Anvil | `make send-ETH-anvil` |

### 7.2. Wrap/Unwrap WETH

Wrap or unwrap all WETH to/from ETH.

| Chain | Command                      |
| ----- | ---------------------------- |
| Anvil | `make wrap-ETH-WETH-anvil`   |
| Anvil | `make unwrap-WETH-ETH-anvil` |

### 7.3. Swap Tokens

Swap tokens using UniswapV3.

| Chain | Command                      |
| ----- | ---------------------------- |
| Anvil | `make swap-ETH-USDC-anvil`   |
| Anvil | `make swap-USDC-WETH-anvil`  |
| Anvil | `make swap-ETH-wstETH-anvil` |
| Anvil | `make swap-wstETH-ETH-anvil` |

### 7.4. Update Health Factor Target

Input value to 2 decimal places e.g. `225`.

| Chain | Command                 |
| ----- | ----------------------- |
| Anvil | `make update-hft-anvil` |

### 7.5. Aave Supply wstETH

Supplies all wstETH to Aave.

| Chain | Command                         |
| ----- | ------------------------------- |
| Anvil | `make aave-supply-wstETH-anvil` |

### 7.6. Aave Borrow USDC

Borrows the specified amount of USDC from Aave. If the Health Factor is below the target, the borrow will fail.

Input value in USDC e.g. `100`.

| Chain | Command                       |
| ----- | ----------------------------- |
| Anvil | `make aave-borrow-USDC-anvil` |

### 7.7. Rebalance

Rebalances the Aave position to maintain the desired Health Factor.

| Chain | Command                |
| ----- | ---------------------- |
| Anvil | `make rebalance-anvil` |

## 8. Build and Deploy Documentation

Instructions on how to build and deploy the documentation book are detailed here: [https://docs.eridianalpha.com/ethereum-dev/foundry-notes/docs-and-github-pages](https://docs.eridianalpha.com/ethereum-dev/foundry-notes/docs-and-github-pages)

## 9. License

[MIT](https://choosealicense.com/licenses/mit/)
