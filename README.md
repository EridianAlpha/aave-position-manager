# AavePM - Aave Position Manager

> ---
>
> 🏗️ UNDER DEVELOPMENT 🏗️
>
> ---

- [Overview](#overview)
  - [Key Functions](#key-functions)
- [WebApp](#webapp)
- [Installation](#installation)
  - [Clone repository](#clone-repository)
  - [Install Dependencies](#install-dependencies)
  - [Create `.env` file](#create-env-file)
  - [Configure Ethernal (optional)](#configure-ethernal-optional)
- [Testing](#testing)
  - [Tests](#tests)
  - [Coverage](#coverage)
- [Deployment](#deployment)
- [Interactions](#interactions)
  - [Deposit](#deposit)
- [Build and Deploy Documentation](#build-and-deploy-documentation)
- [License](#license)

## Overview

> Docs Site: [https://eridianalpha.github.io/aave-position-manager](https://eridianalpha.github.io/aave-position-manager)

A smart contract manager for Aave positions.

1. Set a desired Health Factor.
2. Deposit assets (ETH or wstETH) into the position.
3. Rebalance the position to maintain the desired Health Factor, either manually or with a bot.

### Key Functions

| Function          | Restrictions   | Description                                               |
| ----------------- | -------------- | --------------------------------------------------------- |
| deposit()         | `MANAGER_ROLE` | Deposit ETH or wstETH.                                    |
| rebalance()       | `MANAGER_ROLE` | Rebalance the Aave position to the desired Health Factor. |
| setHealthFactor() | `OWNER_ROLE`   | Set the desired Health Factor.                            |
| withdraw()        | `OWNER_ROLE`   | Withdraw wstETH while maintaining desired Health Factor.  |

## WebApp

A WebApp is being developed to allow easy interaction with the smart contract and will be linked here when ready.

## Installation

### Clone repository

```bash
git clone https://github.com/EridianAlpha/aave-position-manager.git
```

### Install Dependencies

This should happen automatically when first running a command, but the installation can be manually triggered with the following commands:

```bash
git submodule init
git submodule update
make install
```

### Create `.env` file

Use the `.env.example` file as a template to create a `.env` file.

### Configure Ethernal (optional)

Configure an Ethernal account to interact with the smart contract through a UI (like Etherscan but for a local network).

[https://docs.eridianalpha.com/ethereum-dev/useful-tools/ethernal](https://docs.eridianalpha.com/ethereum-dev/useful-tools/ethernal)

```bash
make ethernal
```

## Testing

### Tests

```bash
make test
make test-fork-mainnet
make test-fork-mainnet-v
make test-fork-mainnet-summary
```

### Coverage

```bash
make coverage
```

## Deployment

| Chain   | Command                |
| ------- | ---------------------- |
| Anvil   | `make deploy-anvil`    |
| Holesky | `make deploy-holesky`  |
| Mainnet | `#make deploy-mainnet` |
| Base    | `#make deploy-base`    |

## Interactions

### Deposit

Under development 🏗️

## Build and Deploy Documentation

Instructions on how to build and deploy the documentation book are detailed here: [https://docs.eridianalpha.com/ethereum-dev/foundry-notes/docs-and-github-pages](https://docs.eridianalpha.com/ethereum-dev/foundry-notes/docs-and-github-pages)

## License

[MIT](https://choosealicense.com/licenses/mit/)
