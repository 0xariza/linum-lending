# 🏦 Linum - Advanced Credit-Scored Lending Protocol

[![Solidity](https://img.shields.io/badge/Solidity-0.8.20-blue.svg)](https://soliditylang.org/)
[![Foundry](https://img.shields.io/badge/Foundry-1.0+-orange.svg)](https://getfoundry.sh/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Tests](https://img.shields.io/badge/Tests-139%20passed-brightgreen.svg)]()

> **Linum** is a next-generation decentralized lending protocol that combines traditional credit scoring with blockchain technology to provide personalized lending solutions. Built with security-first principles and advanced yield distribution mechanisms.

## 📋 Table of Contents

- [Overview](#-overview)
- [Key Features](#-key-features)
- [Architecture](#-architecture)
- [Smart Contracts](#-smart-contracts)
- [Credit Scoring System](#-credit-scoring-system)
- [Interest Rate Model](#-interest-rate-model)
- [Security Features](#-security-features)
- [Installation](#-installation)
- [Usage](#-usage)
- [Testing](#-testing)
- [Deployment](#-deployment)
- [API Reference](#-api-reference)
- [Security Considerations](#-security-considerations)
- [Contributing](#-contributing)
- [License](#-license)

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
- **Access Control**: Role-based permissions with owner controls

### 📊 Interest Rate Model
- **Utilization-Based**: Dynamic rates based on protocol utilization
- **Kink Model**: Aave-style interest rate curve
- **Credit Discounts**: Personalized rates based on credit scores
- **Emergency Rates**: High rates during extreme utilization

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Linum Protocol                          │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────────┐    ┌─────────────────┐                │
│  │  LendingVaults  │    │   YieldToken    │                │
│  │   (Main Core)   │◄──►│  (Yield Dist.)  │                │
│  └─────────────────┘    └─────────────────┘                │
│           │                       │                        │
│           ▼                       ▼                        │
│  ┌─────────────────┐    ┌─────────────────┐                │
│  │ Credit Scoring  │    │  Share-Based    │                │
│  │    System       │    │   Accounting    │                │
│  └─────────────────┘    └─────────────────┘                │
│           │                       │                        │
│           ▼                       ▼                        │
│  ┌─────────────────┐    ┌─────────────────┐                │
│  │ Interest Rate   │    │  Attack         │                │
│  │    Model        │    │  Prevention     │                │
│  └─────────────────┘    └─────────────────┘                │
└─────────────────────────────────────────────────────────────┘
```

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

### Interface Contracts

#### `ILendingVaults.sol`
Complete interface for the LendingVaults contract with all events and structs.

#### `IYieldToken.sol`
Interface for the YieldToken contract with all external functions.

## 🎯 Credit Scoring System

### Credit Tiers

| Tier | Score Range | Collateral Ratio | Rate Discount | Description |
|------|-------------|------------------|---------------|-------------|
| NEW | 100-199 | 200% | 0% | New users, highest collateral requirement |
| BRONZE | 200-399 | 180% | 0.2% | Basic tier with moderate requirements |
| SILVER | 400-599 | 150% | 0.4% | Established users with good history |
| GOLD | 600-799 | 130% | 0.6% | Premium users with excellent history |
| PREMIUM | 800-1000 | 110% | 0.8% | Top tier with minimal requirements |

### Score Calculation

```solidity
// Credit score updates based on behavior
function _updateCreditScore(address user, bool isPositive, uint256 liquidatedAmount) internal {
    if (liquidatedAmount > 0) {
        // Liquidation penalty: -100 points
        newScore = newScore > 100 ? newScore - 100 : MIN_CREDIT_SCORE;
    } else if (isPositive) {
        // Reward on-time payments: 15-25 points
        uint256 increase = 15;
        if (profile.onTimePayments > 10) increase = 20;
        if (profile.onTimePayments > 20) increase = 25;
    } else {
        // Late payment penalty: 15-25 points
        uint256 decrease = 15;
        if (profile.latePayments > 5) decrease = 25;
    }
}
```

## 📈 Interest Rate Model

### Utilization-Based Rates

The protocol implements an Aave-style kink model with three utilization zones:

```solidity
function getBorrowInterestRate(address asset) public view returns (uint256) {
    uint256 utilization = getUtilizationRate(asset);
    
    if (utilization <= OPTIMAL_UTILIZATION) {
        // Linear rate increase for utilization below optimal (0-80%)
        uint256 rateDiff = (utilization * RATE_SLOPE_1) / OPTIMAL_UTILIZATION;
        return BASE_RATE + rateDiff;
    } else if (utilization <= MAX_UTILIZATION) {
        // Exponential rate increase for utilization above optimal (80-95%)
        uint256 excessUtilization = utilization - OPTIMAL_UTILIZATION;
        uint256 rateDiff = (excessUtilization * RATE_SLOPE_2) / (MAX_UTILIZATION - OPTIMAL_UTILIZATION);
        return BASE_RATE + RATE_SLOPE_1 + rateDiff;
    } else {
        // Emergency rate for utilization at or above max (95%+)
        return BASE_RATE + RATE_SLOPE_1 + RATE_SLOPE_2;
    }
}
```

### Rate Parameters

- **Base Rate**: 2% minimum rate
- **Optimal Utilization**: 80% target utilization
- **Max Utilization**: 95% emergency threshold
- **Rate Slope 1**: 1.5% slope for low utilization
- **Rate Slope 2**: 5% slope for high utilization

## 🔒 Security Features

### 🛡️ Attack Prevention Mechanisms

#### Donation Attack Protection
Linum implements sophisticated protection against donation attacks where malicious actors transfer tokens directly to the contract to manipulate share calculations.

```solidity
// Track minted assets separately from total assets
uint256 public totalMintedAssets; // Prevents donation attacks
uint256 public totalTrackedAssets; // Prevents bootstrap attacks

// Donation attack protection in share calculation
function _calculateSharesFromAssets(uint256 assets) internal view returns (uint256 shares) {
    return totalShares == 0 ? assets : (assets * totalShares) / totalMintedAssets;
}
```

**How it works:**
- `totalMintedAssets` tracks only legitimate deposits through the `mint()` function
- Direct token transfers to the contract don't affect share calculations
- Users can only redeem their legitimate deposits, not donated amounts
- Legitimate donations can be handled via `handleDonation()` function

#### Bootstrap Attack Prevention
Protection against bootstrap attacks where tokens are transferred to the contract before any users deposit.

```solidity
// Bootstrap attack prevention
function syncAssets(uint256 newTotalAssets) external onlyLendingProtocol {
    if (newTotalAssets < totalTrackedAssets) revert CannotDecreaseAssets();
    
    uint256 untrackedAssets = newTotalAssets - totalTrackedAssets;
    totalAssets = newTotalAssets;
    totalTrackedAssets = newTotalAssets;
    
    if (untrackedAssets > 0) {
        totalMintedAssets += untrackedAssets;
    }
}
```

**Protection mechanism:**
- All assets are tracked from the beginning
- Untracked assets are automatically added to `totalMintedAssets`
- Ensures fair share distribution even with pre-existing balances

#### Front-Running Protection
Protection against MEV attacks and front-running during transfers.

```solidity
// Front-running protection in transfers
function transfer(address to, uint256 amount) public override returns (bool) {
    // Lock transfer amount to current ratio to prevent front-running
    bytes32 transferId = keccak256(abi.encodePacked(msg.sender, to, amount, block.timestamp));
    _lockedTransferAmounts[transferId] = amount;
    
    _transferShares(msg.sender, to, amount);
    
    // Clear the locked amount after successful transfer
    delete _lockedTransferAmounts[transferId];
    return true;
}
```

**Protection features:**
- Transfer amounts are locked to the current exchange ratio
- Prevents manipulation during transfer execution
- Unique transfer IDs prevent replay attacks

#### Rate Limiting & Anti-Spam
Protection against spam attacks and rapid deposit manipulation.

```solidity
// Rate limiting constants
uint256 public constant MIN_DEPOSIT = 1e6; // 1 token minimum
uint256 public constant MIN_TIME_BETWEEN_DEPOSITS = 1 hours;

// Rate limiting per user
mapping(address => uint256) private _lastDepositTime;

modifier rateLimited() {
    if (msg.sender != lendingProtocol && 
        block.timestamp < _lastDepositTime[msg.sender] + MIN_TIME_BETWEEN_DEPOSITS) {
        revert RateLimitExceeded();
    }
    _;
}
```

**Anti-spam features:**
- Minimum deposit requirements prevent dust attacks
- Time-based rate limiting per user
- Protocol operations are exempt from rate limiting

### 🔐 Access Control & Permissions

#### Role-Based Access Control
```solidity
// Owner-only functions
modifier onlyOwner() {
    require(msg.sender == owner(), "Not authorized");
    _;
}

// Lending protocol only functions
modifier onlyLendingProtocol() {
    if (msg.sender != lendingProtocol) revert OnlyLendingProtocol();
    _;
}
```

**Access levels:**
- **Owner**: Protocol parameter updates, fee withdrawal, emergency functions
- **Lending Protocol**: YieldToken minting/burning, rebasing operations
- **Users**: Standard deposit, borrow, repay operations

#### Emergency Controls
```solidity
// Emergency pause functionality
function pause() external onlyOwner {
    _pause();
}

function unpause() external onlyOwner {
    _unpause();
}

// Blacklisting system
mapping(address => bool) public isBlacklisted;

modifier notBlacklisted() {
    if (creditProfiles[msg.sender].isBlacklisted) revert UserBlacklisted();
    _;
}
```

### 🛡️ Reentrancy Protection

All external functions are protected against reentrancy attacks using OpenZeppelin's `ReentrancyGuard`.

```solidity
contract LendingVaults is Ownable, ReentrancyGuard, Pausable, ILendingVaults {
    
    function deposit(address asset, uint256 amount) 
        external 
        payable 
        nonReentrant 
        whenNotPaused 
        validAsset(asset) 
    {
        // Deposit logic protected against reentrancy
    }
    
    function borrow(...) 
        external 
        payable 
        nonReentrant 
        whenNotPaused 
        notBlacklisted 
        validAsset(borrowAsset) 
        validAsset(collateralAsset) 
    {
        // Borrow logic protected against reentrancy
    }
}
```

### 🔍 Input Validation & Error Handling

#### Comprehensive Input Validation
```solidity
// Asset validation
modifier validAsset(address asset) {
    if (!supportedAssets[asset]) revert UnsupportedAsset();
    _;
}

// Amount validation
if (amount == 0) revert AmountTooSmall();
if (assets < MIN_DEPOSIT) revert InsufficientDepositAmount();

// Address validation
if (to == address(0)) revert InvalidAddress();
```

#### Custom Error Messages
```solidity
// Custom errors for gas efficiency
error UserBlacklisted();
error UnsupportedAsset();
error InsufficientLiquidity();
error BorrowLimitExceeded();
error InsufficientCollateral();
error PositionNotActive();
error InvalidPositionIndex();
```

### 🎯 Precision Protection

#### Share Calculation Precision
```solidity
// Precision protection in share calculations
function _calculateSharesFromAssets(uint256 assets) internal view returns (uint256 shares) {
    if (totalShares == 0) return assets;
    
    shares = (assets * totalShares) / totalMintedAssets;
    
    // Ensure minimum precision
    if (shares == 0) revert InsufficientPrecision();
    
    return shares;
}
```

**Precision safeguards:**
- Minimum deposit requirements prevent precision loss
- Zero share protection in calculations
- Proper rounding in share-to-asset conversions

### 🔄 State Consistency

#### Atomic Operations
All state-changing operations are atomic to prevent inconsistent states.

```solidity
function mint(address to, uint256 assets) external onlyLendingProtocol returns (uint256 shares) {
    // Calculate shares
    shares = _calculateSharesFromAssets(assets);
    
    // Update all state variables atomically
    _shareBalances[to] += shares;
    totalShares += shares;
    totalAssets += assets;
    totalMintedAssets += assets;
    totalTrackedAssets += assets;
    
    emit SharesMinted(to, shares, assets);
}
```

### 🚨 Liquidation Security

#### Automated Liquidation
```solidity
function liquidate(address borrower, uint256 positionIndex) external payable nonReentrant whenNotPaused {
    // Validate liquidation conditions
    if (block.timestamp <= position.dueDate) revert PositionNotLiquidatable();
    
    // Calculate total debt
    uint256 timeElapsed = block.timestamp - position.borrowTime;
    uint256 interest = (position.borrowedAmount * position.interestRate * timeElapsed) / (365 days * 10_000);
    uint256 totalDebt = position.borrowedAmount + interest;
    
    // Execute liquidation
    // Update state variables
    // Distribute collateral to liquidator
}
```

**Liquidation features:**
- Automatic liquidation after due date
- Fair collateral distribution
- Credit score penalties for liquidated users
- Blacklisting for major losses

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

### Advanced Operations

#### Credit Score Management

```solidity
// Get user credit tier
(string memory tier, uint256 collateralRatio, uint256 rateDiscount) = 
    lendingVaults.getCreditTier(userAddress);

// Check if user can borrow
bool canBorrow = lendingVaults.canBorrow(userAddress);
```

#### Yield Token Operations

```solidity
// Get yield token balance
uint256 balance = yieldToken.balanceOf(userAddress);

// Get underlying shares
uint256 shares = yieldToken.sharesOf(userAddress);

// Redeem assets
lendingVaults.redeem(assetAddress, shares);
```

## 🧪 Testing

### Running Tests

```bash
# Run all tests
forge test

# Run specific test file
forge test --match-contract LendingVaultsTest

# Run specific test
forge test --match-test test_Borrow_ETH

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

### Key Test Categories

```bash
# Core functionality tests
forge test --match-test "test_Deposit|test_Borrow|test_Repay"

# Security tests
forge test --match-test "test_ReentrancyProtection|test_OnlyOwnerFunctions"

# Credit system tests
forge test --match-test "test_CreditScore|test_CreditTier"

# Yield token tests
forge test --match-test "test_Rebase|test_Transfer"
```

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

### Mainnet Deployment

```bash
# Deploy to Ethereum mainnet
forge script script/Deploy.s.sol --rpc-url $ETHEREUM_RPC_URL --broadcast --verify
```

## 📚 API Reference

### LendingVaults Contract

#### Core Functions

| Function | Description | Parameters |
|----------|-------------|------------|
| `deposit()` | Deposit assets to earn yield | `asset`, `amount` |
| `borrow()` | Borrow assets with collateral | `borrowAsset`, `borrowAmount`, `collateralAsset`, `collateralAmount` |
| `repay()` | Repay borrowed amounts | `positionIndex`, `repayAmount` |
| `liquidate()` | Liquidate overdue positions | `borrower`, `positionIndex` |

#### View Functions

| Function | Description | Returns |
|----------|-------------|---------|
| `getCreditTier()` | Get user credit tier | `tier`, `collateralRatio`, `rateDiscount` |
| `getBorrowInterestRate()` | Get base interest rate | `rate` |
| `getUserBorrowInterestRate()` | Get user-specific rate | `rate` |
| `getUtilizationRate()` | Get asset utilization | `utilization` |

### YieldToken Contract

#### Core Functions

| Function | Description | Parameters |
|----------|-------------|------------|
| `mint()` | Mint shares (protocol only) | `to`, `assets` |
| `burn()` | Burn shares (protocol only) | `from`, `shares` |
| `rebase()` | Update total assets | `newTotalAssets` |

#### View Functions

| Function | Description | Returns |
|----------|-------------|---------|
| `balanceOf()` | Get token balance | `balance` |
| `sharesOf()` | Get share balance | `shares` |
| `getSharesForAssets()` | Convert assets to shares | `shares` |
| `getAssetsForShares()` | Convert shares to assets | `assets` |

## ⚠️ Security Considerations

### 🚨 Known Limitations

1. **Same-Asset Collateral**: Currently only supports same-asset collateral (oracle integration pending)
2. **Admin Privileges**: Owner has extensive privileges (timelock recommended)
3. **Precision Loss**: Potential precision loss in share calculations for very small amounts
4. **Liquidation Threshold**: Hardcoded liquidation threshold (should be configurable)
5. **Credit Score Manipulation**: Users can potentially manipulate scores through small, frequent loans

### 🛡️ Attack Vectors & Mitigations

#### Donation Attack Mitigation
**Attack Vector**: Malicious actors transfer tokens directly to the contract to manipulate share calculations.

**Mitigation**: 
- Separate tracking of `totalMintedAssets` vs `totalAssets`
- Share calculations based only on legitimate deposits
- Direct transfers don't affect user share calculations
- Legitimate donations handled through `handleDonation()` function

#### Bootstrap Attack Mitigation
**Attack Vector**: Tokens transferred to contract before any users deposit to manipulate initial share distribution.

**Mitigation**:
- `syncAssets()` function tracks all pre-existing balances
- Untracked assets automatically added to `totalMintedAssets`
- Ensures fair share distribution from the beginning

#### Front-Running Attack Mitigation
**Attack Vector**: MEV bots manipulate exchange rates during transfers.

**Mitigation**:
- Transfer amounts locked to current exchange ratio
- Unique transfer IDs prevent replay attacks
- Atomic transfer operations

#### Reentrancy Attack Mitigation
**Attack Vector**: Malicious contracts re-enter functions during execution.

**Mitigation**:
- All external functions use `nonReentrant` modifier
- State changes before external calls
- OpenZeppelin's `ReentrancyGuard` implementation

#### Precision Attack Mitigation
**Attack Vector**: Very small deposits/withdrawals to exploit precision loss.

**Mitigation**:
- Minimum deposit requirements (`MIN_DEPOSIT`)
- Zero share protection in calculations
- Proper rounding in conversions

### 🔒 Best Practices

1. **Professional Audit**: Comprehensive security audit required before mainnet deployment
2. **Gradual Deployment**: Deploy with limited caps and gradually increase
3. **Monitoring & Alerting**: Implement comprehensive monitoring for unusual activity
4. **Emergency Procedures**: Have emergency pause and recovery procedures ready
5. **Timelock Implementation**: Add timelock for critical admin functions
6. **Multi-Signature**: Consider multi-signature requirements for owner functions

### 🎯 Risk Mitigation Strategies

#### Technical Mitigations
- **Insurance**: Protocol insurance for liquidation losses
- **Governance**: Decentralized governance for parameter updates
- **Oracle Integration**: Price feeds for cross-asset collateral
- **Dynamic Parameters**: Configurable liquidation thresholds and rates

#### Operational Mitigations
- **Rate Limiting**: Prevent rapid deposit/withdrawal attacks
- **Blacklisting**: Automatic blacklisting for malicious users
- **Credit Score Limits**: Minimum loan amounts for credit score updates
- **Liquidation Incentives**: Proper incentives for liquidators

#### Monitoring & Response
- **Real-time Monitoring**: Track unusual transaction patterns
- **Automated Alerts**: Alert on suspicious activity
- **Incident Response**: Clear procedures for security incidents
- **Community Reporting**: Bug bounty program for security issues

### 🔍 Security Testing

#### Automated Testing
```bash
# Security-focused tests
forge test --match-test "test_ReentrancyProtection"
forge test --match-test "test_DonationAttackPrevented"
forge test --match-test "test_BootstrapAttackPrevented"
forge test --match-test "test_FrontRunningVulnerabilityMitigated"
```

#### Manual Testing
- **Fuzz Testing**: Random input testing for edge cases
- **Integration Testing**: End-to-end security scenarios
- **Stress Testing**: High-load and extreme condition testing
- **Penetration Testing**: Simulated attack scenarios

### 📊 Security Metrics

| Security Feature | Status | Implementation |
|------------------|--------|----------------|
| Reentrancy Protection | ✅ Implemented | OpenZeppelin ReentrancyGuard |
| Donation Attack Protection | ✅ Implemented | totalMintedAssets tracking |
| Bootstrap Attack Protection | ✅ Implemented | syncAssets() function |
| Front-Running Protection | ✅ Implemented | Transfer amount locking |
| Rate Limiting | ✅ Implemented | Time-based restrictions |
| Access Control | ✅ Implemented | Role-based permissions |
| Input Validation | ✅ Implemented | Comprehensive checks |
| Emergency Pause | ✅ Implemented | Pausable functionality |
| Blacklisting | ✅ Implemented | User blacklist system |
| Precision Protection | ✅ Implemented | Minimum deposit requirements |

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

### Issue Reporting

When reporting issues, please include:

- Detailed description of the problem
- Steps to reproduce
- Expected vs actual behavior
- Environment details (network, gas price, etc.)
- Relevant transaction hashes

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