# Linum Lending Protocol

[![Solidity](https://img.shields.io/badge/Solidity-0.8.26-blue.svg)](https://soliditylang.org/)
[![Foundry](https://img.shields.io/badge/Foundry-✓-green.svg)](https://getfoundry.sh/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

A decentralized lending protocol built on Ethereum and Polygon that provides secure, collateralized lending with dynamic credit scoring and yield distribution.

## 🚀 Features

### Core Functionality
- **Multi-Asset Support**: Native ETH, USDC, MATIC, and additional ERC20 tokens
- **Collateralized Lending**: Secure borrowing with multiple collateral types
- **Dynamic Credit Scoring**: Risk-based interest rates and collateral requirements
- **Yield Distribution**: Automatic yield distribution through rebasing saTokens
- **Liquidation System**: Automated liquidation of undercollateralized positions

### Advanced Features
- **Utilization-Based Interest Rates**: Dynamic rates based on protocol utilization
- **Credit Tier System**: Multiple tiers (NEW, BRONZE, SILVER, GOLD, PREMIUM)
- **Protocol Fee Management**: Transparent fee collection and distribution
- **Emergency Controls**: Pausable functionality for security incidents

## 🏗️ Architecture

### Smart Contracts

#### Core Contracts
- **`LendingVaults.sol`**: Main protocol contract handling deposits, borrows, and credit management
- **`YieldToken.sol`**: Rebasing ERC20 tokens representing protocol shares
- **`ILendingVaults.sol`**: Interface defining all protocol functions and events

#### Key Components
- **Credit Profile System**: Tracks user borrowing history and credit scores
- **Borrow Position Management**: Handles individual loan positions and collateral
- **Interest Rate Model**: Dynamic rates based on utilization and credit scores
- **Liquidation Engine**: Automated protection against undercollateralization

## 🔒 Security Features & Attack Prevention

### 1. Reentrancy Protection
```solidity
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract LendingVaults is ReentrancyGuard {
    function deposit(address asset, uint256 amount) external payable nonReentrant {
        // Protected against reentrancy attacks
    }
}
```
- **Prevents**: Reentrancy attacks on deposit/withdraw functions
- **Implementation**: OpenZeppelin's ReentrancyGuard modifier
- **Coverage**: All state-changing functions

### 2. Access Control & Ownership
```solidity
contract LendingVaults is Ownable {
    modifier onlyOwner() {
        require(msg.sender == owner(), "Not authorized");
        _;
    }
}
```
- **Prevents**: Unauthorized administrative actions
- **Features**: 
  - Owner-only asset management
  - Emergency pause functionality
  - Fee withdrawal controls

### 3. Input Validation & Bounds Checking
```solidity
// Credit score bounds
uint256 public constant MIN_CREDIT_SCORE = 100;
uint256 public constant MAX_CREDIT_SCORE = 1000;

// Utilization rate limits
uint256 public constant MAX_UTILIZATION = 9500; // 95%
```
- **Prevents**: Invalid inputs and overflow attacks
- **Validations**:
  - Credit score bounds (100-1000)
  - Utilization rate limits (0-95%)
  - Minimum deposit amounts
  - Valid asset addresses

### 4. Blacklist System
```solidity
struct CreditProfile {
    bool isBlacklisted; // User blacklist status
}

modifier notBlacklisted() {
    if (creditProfiles[msg.sender].isBlacklisted) revert UserBlacklisted();
    _;
}
```
- **Prevents**: Malicious user activities
- **Features**: Owner-controlled blacklisting
- **Protection**: Blocks blacklisted users from all operations

### 5. Collateral Protection
```solidity
uint256 public constant LIQUIDATION_THRESHOLD = 95; // 95% of collateral value

function liquidate(address borrower, uint256 positionIndex) external {
    // Only liquidate when collateral ratio drops below threshold
}
```
- **Prevents**: Protocol insolvency from undercollateralized positions
- **Features**:
  - 95% liquidation threshold
  - Automated liquidation triggers
  - Incentivized liquidator rewards

### 6. Rate Limiting & Anti-Frontrunning
```solidity
uint256 public constant MIN_TIME_BETWEEN_DEPOSITS = 1 hours;

modifier rateLimited() {
    if (block.timestamp < _lastDepositTime[msg.sender] + MIN_TIME_BETWEEN_DEPOSITS) {
        revert RateLimitExceeded();
    }
    _;
}
```
- **Prevents**: Frontrunning attacks and rapid deposit/withdraw cycles
- **Features**:
  - 1-hour minimum between deposits
  - Transfer amount locking
  - Bootstrap attack prevention

### 7. Donation Attack Prevention
```solidity
uint256 public totalMintedAssets; // Total assets from minting
uint256 public totalTrackedAssets; // Total assets tracked

function _calculateSharesFromAssets(uint256 assets) internal view returns (uint256) {
    // Prevents donation attacks by tracking minted vs tracked assets
}
```
- **Prevents**: Donation attacks that manipulate share calculations
- **Implementation**: Separate tracking of minted vs. tracked assets

### 8. Emergency Pause
```solidity
import "@openzeppelin/contracts/utils/Pausable.sol";

contract LendingVaults is Pausable {
    function pause() external onlyOwner {
        _pause();
    }
}
```
- **Prevents**: Continued operation during security incidents
- **Features**: Owner-controlled emergency pause
- **Scope**: All critical functions when paused

### 9. Precision Loss Protection
```solidity
uint256 public constant UTILIZATION_PRECISION = 10000; // 100% = 10000 basis points

function getUtilizationRate(address asset) public view returns (uint256) {
    // High precision calculations to prevent rounding errors
}
```
- **Prevents**: Precision loss in interest calculations
- **Implementation**: High-precision basis point calculations
- **Coverage**: All rate and fee calculations

### 10. Comprehensive Error Handling
```solidity
error UserBlacklisted();
error UnsupportedAsset();
error InsufficientCollateral();
error PositionNotLiquidatable();
```
- **Prevents**: Silent failures and unexpected behavior
- **Features**: Custom error types for gas efficiency
- **Coverage**: All function validations

## 🛠️ Installation & Setup

### Prerequisites
- [Foundry](https://getfoundry.sh/) (latest version)
- Node.js 18+ (for testing)
- Git

### Quick Start
```bash
# Clone the repository
git clone <repository-url>
cd linum-lending

# Install dependencies
forge install

# Compile contracts
forge build

# Run tests
forge test

# Run tests with coverage
forge coverage
```

### Environment Setup
```bash
# Copy environment template
cp .env.example .env

# Set required environment variables
export ETHEREUM_RPC_URL="your_ethereum_rpc_url"
export POLYGON_RPC_URL="your_polygon_rpc_url"
export ETHERSCAN_MAINNET_KEY="your_etherscan_key"
export ETHERSCAN_API_KEY="your_polygonscan_key"
```

## 🧪 Testing

### Test Structure
```
test/
├── LendingVaults.t.sol    # Main protocol tests
└── YieldToken.t.sol       # Yield token tests
```

### Running Tests
```bash
# Run all tests
forge test

# Run specific test file
forge test --match-contract LendingVaultsTest

# Run with verbose output
forge test -vvv

# Run with gas reporting
forge test --gas-report
```

### Test Coverage
```bash
# Generate coverage report
forge coverage

# Generate coverage report with lcov
forge coverage --report lcov
```

## 📊 Protocol Parameters

### Interest Rate Model
- **Base Rate**: 2% minimum
- **Optimal Utilization**: 80%
- **Max Utilization**: 95%
- **Rate Slope 1** (0-80%): 1.5%
- **Rate Slope 2** (80-95%): 5%

### Credit Scoring
- **Initial Score**: 300 (NEW tier)
- **Score Range**: 100-1000
- **Credit Discount**: 0.1% per 100 points
- **Tiers**: NEW, BRONZE, SILVER, GOLD, PREMIUM

### Loan Terms
- **Standard Duration**: 30 days
- **Liquidation Threshold**: 95%
- **Protocol Fee**: 0.5%
- **Late Penalty**: 10%

## 🔧 Configuration

### Supported Assets
- **ETH**: Native Ethereum
- **USDC**: USD Coin (6 decimals)
- **MATIC**: Polygon token (18 decimals)
- **Additional ERC20**: Configurable via admin functions

### Borrow Limits
- **Global Limit**: 10M USDC equivalent
- **Per-Asset Limits**: Configurable by asset
- **User Limits**: Based on credit score and collateral

## 🚨 Emergency Procedures

### Pause Protocol
```solidity
// Only owner can pause
function pause() external onlyOwner {
    _pause();
}

// Resume protocol
function unpause() external onlyOwner {
    _unpause();
}
```

### Blacklist User
```solidity
// Blacklist malicious user
function blacklistUser(address user) external onlyOwner {
    creditProfiles[user].isBlacklisted = true;
}
```

### Emergency Withdrawal
```solidity
// Emergency withdrawal of protocol fees
function withdrawProtocolFees(address asset) external onlyOwner {
    // Withdraw accumulated fees
}
```

## 📈 Usage Examples

### Deposit Assets
```solidity
// Deposit ETH
lendingVaults.deposit{value: 10 ether}(address(0), 0);

// Deposit USDC
usdc.approve(address(lendingVaults), 1000 * 10**6);
lendingVaults.deposit(address(usdc), 1000 * 10**6);
```

### Borrow with Collateral
```solidity
// Borrow USDC with ETH collateral
lendingVaults.borrow{value: 5 ether}(
    address(usdc),           // borrow asset
    1000 * 10**6,           // borrow amount
    address(0),             // collateral asset (ETH)
    5 ether                 // collateral amount
);
```

### Repay Loan
```solidity
// Repay loan
usdc.approve(address(lendingVaults), 1000 * 10**6);
lendingVaults.repay(0, 1000 * 10**6); // position index, amount
```

### Liquidate Position
```solidity
// Liquidate undercollateralized position
lendingVaults.liquidate(borrower, positionIndex);
```

## 🔍 Monitoring & Analytics

### Key Metrics
- **Total Value Locked (TVL)**: Sum of all deposited assets
- **Utilization Rate**: Borrowed/Deposited ratio per asset
- **Credit Score Distribution**: User tier breakdown
- **Liquidation Events**: Failed positions and liquidations
- **Protocol Fees**: Accumulated fees by asset

### Events to Monitor
```solidity
event Deposit(address indexed user, address indexed asset, uint256 amount, uint256 shares);
event Borrow(address indexed user, address indexed borrowAsset, uint256 borrowAmount, ...);
event Liquidation(address indexed user, uint256 positionIndex, address indexed liquidator);
event CreditScoreUpdated(address indexed user, uint256 oldScore, uint256 newScore);
```

## 🤝 Contributing

### Development Guidelines
1. **Code Style**: Follow Solidity style guide
2. **Testing**: 100% test coverage required
3. **Documentation**: Comprehensive NatSpec comments
4. **Security**: All changes must pass security review

### Pull Request Process
1. Fork the repository
2. Create feature branch
3. Add tests for new functionality
4. Ensure all tests pass
5. Submit pull request with detailed description

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## ⚠️ Disclaimer

This software is provided "as is" without warranty of any kind. Users should:
- Conduct their own security audits
- Understand the risks of DeFi protocols
- Never invest more than they can afford to lose
- Verify all contract addresses before interaction

## 🔗 Links

- **Documentation**: [Protocol Docs](https://docs.linum.finance)
- **Security**: [Security Policy](SECURITY.md)
- **Audit Reports**: [Audit Documentation](audits/)
- **Discord**: [Community Chat](https://discord.gg/linum)
- **Twitter**: [@LinumFinance](https://twitter.com/LinumFinance)

---

**Built with ❤️ by the Linum Team**
