# 🏦 Linum - Advanced Credit-Scored Lending Protocol

[![Solidity](https://img.shields.io/badge/Solidity-0.8.20-blue.svg)](https://soliditylang.org/)
[![Foundry](https://img.shields.io/badge/Foundry-1.0+-orange.svg)](https://getfoundry.sh/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Tests](https://img.shields.io/badge/Tests-139%20passed-brightgreen.svg)]()

> **Linum** is a next-generation decentralized lending protocol that combines traditional credit scoring with blockchain technology to provide personalized lending solutions.

## 📋 Table of Contents

- [Overview](#-overview)
- [Key Features](#-key-features)
- [Smart Contracts](#-smart-contracts)
- [Installation](#-installation)
- [Usage](#-usage)
- [Security](#-security)
- [Contributing](#-contributing)

## 🎯 Overview

Linum is a sophisticated DeFi lending protocol that introduces credit scoring to decentralized finance. Unlike traditional DeFi protocols that rely solely on over-collateralization, Linum implements a dynamic credit system that adjusts borrowing terms based on user behavior and repayment history.

### Core Innovation

- **Credit-Scored Lending**: Dynamic collateral requirements based on user credit scores
- **Rebasing Yield Tokens**: Fair yield distribution through advanced share-based accounting
- **Multi-Asset Support**: Native support for ETH, USDC, MATIC, and extensible ERC20 tokens
- **Utilization-Based Interest**: Aave-style kink model for dynamic interest rates
- **Advanced Security**: Comprehensive protection against common DeFi attack vectors

## ✨ Key Features

### 🏆 Credit Scoring System
- **5 Credit Tiers**: NEW, BRONZE, SILVER, GOLD, PREMIUM
- **Dynamic Collateral Ratios**: 200% to 110% based on credit score
- **Interest Rate Discounts**: Up to 0.8% discount for premium users
- **Behavioral Tracking**: On-time payments, late payments, and liquidation history

### 💰 Yield Distribution
- **Rebasing YieldTokens**: Automatic balance adjustments for fair yield distribution
- **Share-Based Accounting**: Precise yield allocation without precision loss
- **Attack Prevention**: Protection against donation and bootstrap attacks
- **Rate Limiting**: Anti-spam mechanisms for deposit operations

### 🔒 Security & Risk Management
- **Reentrancy Protection**: All external functions protected
- **Pausable Operations**: Emergency pause functionality
- **Blacklisting System**: Automatic blacklisting for malicious users
- **Liquidation Mechanisms**: Automated position liquidation for overdue loans

## 📜 Smart Contracts

### Core Contracts

#### `LendingVaults.sol`
The main protocol contract that orchestrates all lending operations.

**Key Functions:**
- `deposit()` - Deposit assets to earn yield
- `borrow()` - Borrow assets with collateral
- `repay()` - Repay borrowed amounts
- `liquidate()` - Liquidate overdue positions
- `getCreditTier()` - Get user credit tier information

#### `YieldToken.sol`
Rebasing ERC20 tokens that represent shares in the lending protocol.

**Key Features:**
- Automatic balance rebasing for yield distribution
- Share-based accounting for precision
- Attack prevention mechanisms
- Rate limiting for deposits

## 🚀 Installation

### Prerequisites

- [Foundry](https://getfoundry.sh/) (v1.0+)
- [Node.js](https://nodejs.org/) (v16+)
- [Git](https://git-scm.com/)

### Setup

```bash
# Clone the repository
git clone https://github.com/your-org/linum.git
cd linum

# Install dependencies
forge install

# Build contracts
forge build

# Run tests
forge test
```

### Environment Setup

Create a `.env` file with the following variables:

```env
# RPC Endpoints
ETHEREUM_RPC_URL=https://eth-mainnet.alchemyapi.io/v2/YOUR_KEY
POLYGON_RPC_URL=https://polygon-rpc.com

# API Keys
ETHERSCAN_MAINNET_KEY=your_etherscan_key
ETHERSCAN_API_KEY=your_polygonscan_key

# Private Keys (for deployment)
PRIVATE_KEY=your_private_key
```

## 📖 Usage

### Basic Operations

#### 1. Deposit Assets

```solidity
// Deposit ETH
lendingVaults.deposit{value: 1 ether}(address(0), 0);

// Deposit USDC
usdc.approve(address(lendingVaults), 1000 * 10**6);
lendingVaults.deposit(address(usdc), 1000 * 10**6);
```

#### 2. Borrow Assets

```solidity
// Borrow with same-asset collateral
lendingVaults.borrow(
    address(usdc),           // Asset to borrow
    500 * 10**6,            // Amount to borrow
    address(usdc),          // Collateral asset
    1000 * 10**6            // Collateral amount
);
```

#### 3. Repay Loans

```solidity
// Repay loan
usdc.approve(address(lendingVaults), repayAmount);
lendingVaults.repay(positionIndex, repayAmount);
```

### Credit Score Management

```solidity
// Get user credit tier
(string memory tier, uint256 collateralRatio, uint256 rateDiscount) = 
    lendingVaults.getCreditTier(userAddress);

// Check if user can borrow
bool canBorrow = lendingVaults.canBorrow(userAddress);
```

## 🧪 Testing

### Running Tests

```bash
# Run all tests
forge test

# Run specific test file
forge test --match-contract LendingVaultsTest

# Run with verbose output
forge test -v

# Run with gas reporting
forge test --gas-report
```

### Test Coverage

The project includes comprehensive test coverage:

- **139 Tests** covering all major functionality
- **Security Tests**: Reentrancy, attack prevention, access control
- **Integration Tests**: End-to-end lending scenarios
- **Edge Case Tests**: Boundary conditions and error handling

## 🔒 Security Features

### 🛡️ Attack Prevention

#### Donation Attack Protection
```solidity
// Track minted assets separately from total assets
uint256 public totalMintedAssets; // Prevents donation attacks
uint256 public totalTrackedAssets; // Prevents bootstrap attacks
```

#### Front-Running Protection
```solidity
// Lock transfer amounts to current ratio
mapping(bytes32 => uint256) private _lockedTransferAmounts;
```

#### Rate Limiting
```solidity
uint256 public constant MIN_TIME_BETWEEN_DEPOSITS = 1 hours;
mapping(address => uint256) private _lastDepositTime;
```

### Access Control

- **Owner Functions**: Protocol parameter updates, fee withdrawal
- **Lending Protocol Only**: YieldToken minting/burning operations
- **Reentrancy Protection**: All external functions protected
- **Pausable Operations**: Emergency pause capability

### Security Considerations

1. **Professional Audit Required**: Before mainnet deployment
2. **Gradual Deployment**: Deploy with limited caps and gradually increase
3. **Monitoring**: Implement comprehensive monitoring and alerting
4. **Emergency Procedures**: Have emergency pause and recovery procedures ready

## 🚀 Deployment

### Local Development

```bash
# Start local node
anvil

# Deploy to local network
forge script script/Deploy.s.sol --rpc-url http://localhost:8545 --broadcast
```

### Testnet Deployment

```bash
# Deploy to Polygon Mumbai
forge script script/Deploy.s.sol --rpc-url $POLYGON_RPC_URL --broadcast --verify
```

## 🤝 Contributing

We welcome contributions from the community! Please follow these guidelines:

### Development Setup

```bash
# Fork and clone the repository
git clone https://github.com/your-fork/linum.git
cd linum

# Create a feature branch
git checkout -b feature/your-feature-name

# Make your changes
# Add tests for new functionality
# Update documentation

# Run tests
forge test

# Submit a pull request
```

### Contribution Guidelines

1. **Code Style**: Follow the existing code style and formatting
2. **Testing**: Add comprehensive tests for new features
3. **Documentation**: Update documentation for any API changes
4. **Security**: Consider security implications of changes
5. **Review**: All changes require code review

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- [OpenZeppelin](https://openzeppelin.com/) for secure contract libraries
- [Foundry](https://getfoundry.sh/) for the development framework
- [Aave](https://aave.com/) for inspiration on interest rate models
- The DeFi community for continuous innovation and feedback

## 📞 Support

- **Documentation**: [docs.linum.com](https://docs.linum.com)
- **Discord**: [discord.gg/linum](https://discord.gg/linum)
- **Twitter**: [@LinumProtocol](https://twitter.com/LinumProtocol)
- **Email**: support@linum.com

---

**⚠️ Disclaimer**: This software is provided "as is" without warranty. Use at your own risk. This is experimental software and has not been audited for production use.