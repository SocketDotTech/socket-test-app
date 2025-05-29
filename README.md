# EVMx Integration Tests for SOCKET Protocol functionalities

This document provides a comprehensive guide for running the EVMx integration test suite. The test suite validates cross-chain functionality, gas management, scheduling, and error handling across EVMx, Arbitrum Sepolia, and Optimism Sepolia networks.

## Prerequisites

### Environment Setup

Ensure your environment contains the variables on `.env.sample`.

### Dependencies

- Node.js and yarn
- Foundry (forge) for contract compilation
- TypeScript execution environment (tsx)

### Installation

```bash
yarn install
```

## Test Categories

### 1. Write Tests (`-w`)

**Purpose**: Tests write operations from EVMx to multiple destination chains.

**What it does**:
Runs three write test scenarios:
- **Sequential Write**: Triggers 10 sequential counter increments on Optimism
- **Parallel Write**: Triggers 10 parallel counter increments on Arbitrum
- **Alternating Write**: Triggers 10 alternating increments between both chains

### 2. Read Tests (`-r`)

**Purpose**: Tests cross-chain read operations from EVMx to destination chains.

**What it does**:
Runs two read test scenarios:
- **Parallel Read**: Reads values from 10 contracts simultaneously on Arbitrum
- **Alternating Read**: Alternates reading between Optimism and Arbitrum chains

### 3. Trigger Tests (`-t`)

**Purpose**: Tests bidirectional communication - triggering EVMx operations from onchain contracts.

**What it does**:
Runs three trigger scenarios:
- **Arbitrum → EVMx**: Increases value on AppGateway from Arbitrum contract
- **EVMx → Optimism**: Updates Optimism contract from AppGateway
- **Optimism → Arbitrum**: Propagates value from Optimism to Arbitrum

### 4. Upload Tests (`-u`)

**Purpose**: Tests uploading existing contracts from destination chains to EVMx.

**What it does**:
Uploads the counter state to EVMx

### 5. Scheduler Tests (`-s`)

**Purpose**: Tests EVMx's built-in scheduling functionality for delayed execution.

**What it does**:
Triggers all scheduled operations simultaneously
Waits for timeout resolution (up to the maximum timeout duration)

### 6. Insufficient Fees Tests (`-i`)

**Purpose**: Tests the system's handling of insufficient gas fees and fee top-up functionality.

**What it does**:
1. Attempts to deploy onchain contracts (should initially fail)
1. Adds sufficient fees using `increaseFees`
1. Verifies forwarder deployment completes successfully

### 7. Revert Tests (`-v`)

**Purpose**: Tests error handling and revert scenarios in cross-chain operations.

**What it does**:
Tests two revert scenarios:
- **Onchain Revert**: Triggers a transaction that fails on the destination chain
- **Callback Revert**: Triggers a callback that fails due to wrong input arguments

## Running All Tests

**Command**:
```bash
tsx runIntegrationTests.ts -a
```

This runs all test categories in sequence. Each test suite uses a fresh deployment to ensure isolation.
