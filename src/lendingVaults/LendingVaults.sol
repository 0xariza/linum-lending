// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "../yieldToken/YieldToken.sol";
import "./ILendingVaults.sol";
/**
 * @title LendingVaults
 * @dev A lending vault contract that manages deposits, borrows, and credit scoring
 * @notice This contract implements the core lending functionality with the following features:
 * - Multi-asset support (ETH, USDC, MATIC, and additional ERC20 tokens)
 * - Credit scoring system that affects borrowing terms and collateral requirements
 * - Collateralized lending with liquidation mechanisms
 * - Interest distribution to lenders through rebasing saTokens
 * - Protocol fee collection and management
 * - Pausable functionality for emergency situations
 */

contract LendingVaults is Ownable, ReentrancyGuard, Pausable, ILendingVaults {


    /*//////////////////////////////////////////////////////////////
                            CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 public constant BASE_INTEREST_RATE = 500; // 5% base interest rate
    uint256 public constant CREDIT_DISCOUNT_RATE = 10; // 0.1% discount per 100 credit score points (in basis points)
    uint256 public constant LATE_PENALTY_RATE = 1000; // 10% penalty rate for late payments

    // Utilization rate constants
    uint256 public constant OPTIMAL_UTILIZATION = 8000; // 80% optimal utilization
    uint256 public constant MAX_UTILIZATION = 9500; // 95% max utilization before emergency
    uint256 public constant UTILIZATION_PRECISION = 10000; // 100% = 10000 basis points
    
    // Interest rate model parameters
    uint256 public constant RATE_SLOPE_1 = 150; // 1.5% slope for low utilization (0-80%)
    uint256 public constant RATE_SLOPE_2 = 500; // 5% slope for high utilization (80-95%)
    uint256 public constant BASE_RATE = 200; // 2% minimum base rate

    uint256 public constant DEFAULT_CREDIT_SCORE = 300; // Initial credit score for new users (300 = NEW tier)
    uint256 public constant MIN_CREDIT_SCORE = 100; // Minimum possible credit score (100 = lowest tier)
    uint256 public constant MAX_CREDIT_SCORE = 1000; // Maximum possible credit score (1000 = PREMIUM tier)

    uint256 public constant LOAN_DURATION = 30 days; // Standard loan duration
    uint256 public constant LIQUIDATION_THRESHOLD = 95; // 95% of collateral value threshold
    uint256 public constant PROTOCOL_FEE = 50; // 0.5% protocol fee (in basis points)

    address public constant ETH_ADDRESS = address(0); // Native ETH address
    address public immutable USDC; // USDC token address
    address public immutable MATIC; // MATIC token address

    uint256 public override globalBorrowLimit = 10_000_000 * 10 ** 6; // Global borrow limit (10M USDC equivalent)

    /*//////////////////////////////////////////////////////////////
                             MAPPINGS
    //////////////////////////////////////////////////////////////*/

    // Asset management mappings
    mapping(address => uint256) public override totalReserves; // Total assets deposited per asset
    mapping(address => uint256) public override totalBorrowed; // Total assets borrowed per asset
    mapping(address => uint256) public override accumulatedFees; // Protocol fees accumulated per asset
    mapping(address => YieldToken) public override saTokens; // YieldToken contracts per asset
    mapping(address => bool) public supportedAssets; // Whether an asset is supported

    // User data mappings
    mapping(address => CreditProfile) public override creditProfiles; // User credit profiles
    mapping(address => BorrowPosition[]) public override borrowPositions; // User borrow positions

    // Borrow limit management
    mapping(address => uint256) public override maxBorrowLimit; // Per-asset borrow limits







    /*//////////////////////////////////////////////////////////////
                            MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier notBlacklisted() {
        if (creditProfiles[msg.sender].isBlacklisted) revert UserBlacklisted();
        _;
    }

    modifier validAsset(address asset) {
        if (!supportedAssets[asset]) revert UnsupportedAsset();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address _usdc, address _matic, address owner) Ownable(owner) {
        USDC = _usdc;
        MATIC = _matic;

        saTokens[ETH_ADDRESS] = new YieldToken("Share ETH", "saETH", ETH_ADDRESS, address(this));
        saTokens[USDC] = new YieldToken("Share USDC", "saUSDC", USDC, address(this));
        saTokens[MATIC] = new YieldToken("Share MATIC", "saMATIC", MATIC, address(this));

        supportedAssets[ETH_ADDRESS] = true;
        supportedAssets[USDC] = true;
        supportedAssets[MATIC] = true;

        maxBorrowLimit[ETH_ADDRESS] = 1000 ether;
        maxBorrowLimit[USDC] = 5_000_000 * 10 ** 6; // 5M USDC
        maxBorrowLimit[MATIC] = 3_000_000 * 10 ** 18; // 3M MATIC
    }

    /*//////////////////////////////////////////////////////////////
                            DEPOSIT FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Single deposit function - no WETH conversion
     * @param asset ETH_ADDRESS for ETH, token address for ERC20
     * @param amount Amount for ERC20 (0 for ETH, use msg.value)
     */
    function deposit(address asset, uint256 amount) external payable nonReentrant whenNotPaused validAsset(asset) {
        uint256 depositAmount;

        if (asset == ETH_ADDRESS) {
            if (msg.value == 0) revert ETHAmountTooSmall();
            if (amount != 0) revert ETHAmountShouldBeZero();
            depositAmount = msg.value;
        } else {
            if (amount == 0) revert AmountTooSmall();
            if (msg.value != 0) revert ETHNotAllowedForERC20();

            ERC20(asset).transferFrom(msg.sender, address(this), amount);
            depositAmount = amount;
        }

        uint256 
        shares = saTokens[asset].getSharesForAssets(depositAmount);
        totalReserves[asset] += depositAmount;
        saTokens[asset].mint(msg.sender, depositAmount);
        

        emit Deposit(msg.sender, asset, depositAmount, shares);
    }

    /**
     * @dev Redeem saTokens for underlying assets
     * @param asset ETH_ADDRESS for ETH, token address for ERC20
     * @param shares Amount of shares to burn
     */
    function redeem(address asset, uint256 shares) external nonReentrant validAsset(asset) {
        if (shares == 0) revert SharesTooSmall();

        uint256 assets = saTokens[asset].getAssetsForShares(shares);
        uint256 availableLiquidity = getAvailableLiquidity(asset);
        if (availableLiquidity < assets) revert InsufficientLiquidity();

        totalReserves[asset] -= assets;
        saTokens[asset].burn(msg.sender, shares);


        if (asset == ETH_ADDRESS) {
            payable(msg.sender).transfer(assets);
        } else {
            ERC20(asset).transfer(msg.sender, assets);
        }

        emit Redeem(msg.sender, asset, assets, shares);
    }

    /*//////////////////////////////////////////////////////////////
                            BORROWING FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Borrow assets using collateral
     * @param borrowAsset Asset to borrow
     * @param borrowAmount Amount to borrow
     * @param collateralAsset Asset to use as collateral
     * @param collateralAmount Amount of collateral
     */
    function borrow(
        address borrowAsset,
        uint256 borrowAmount,
        address collateralAsset,
        uint256 collateralAmount
    )
        external
        payable
        nonReentrant
        whenNotPaused
        notBlacklisted
        validAsset(borrowAsset)
        validAsset(collateralAsset)
    {
        _createCreditProfile(msg.sender);
        if (borrowAmount == 0) revert BorrowAmountTooSmall();

        if (totalBorrowed[borrowAsset] + borrowAmount > maxBorrowLimit[borrowAsset]) revert BorrowLimitExceeded();

  
        // Get required collateral ratio based on user's credit tier
        (, uint256 requiredRatio,) = _getCreditTier(msg.sender);


        if (borrowAsset == collateralAsset) {
            uint256 requiredCollateral = (borrowAmount * requiredRatio) / 10_000;
            if (collateralAmount < requiredCollateral) revert InsufficientCollateral();
        } else {
            // TODO: Remove this restriction when oracle is implemented
            revert CrossAssetCollateralNotSupported();
        }

        uint256 availableLiquidity = getAvailableLiquidity(borrowAsset);
        if (availableLiquidity < borrowAmount) revert InsufficientLiquidity();

        if (collateralAsset == ETH_ADDRESS) {
            if (msg.value != collateralAmount) revert ETHAmountMismatch();
        } else {
            ERC20(collateralAsset).transferFrom(msg.sender, address(this), collateralAmount);
        }

        uint256 interestRate = getUserBorrowInterestRate(msg.sender, borrowAsset);

        borrowPositions[msg.sender].push(
            BorrowPosition({
                borrowedAsset: borrowAsset,
                borrowedAmount: borrowAmount,
                interestRate: interestRate,
                accruedInterest: 0,
                collateralAsset: collateralAsset,
                collateralAmount: collateralAmount,
                borrowTime: block.timestamp,
                dueDate: block.timestamp + LOAN_DURATION,
                isActive: true
            })
        );

        totalBorrowed[borrowAsset] += borrowAmount;
        creditProfiles[msg.sender].totalBorrowed += borrowAmount;

        if (borrowAsset == ETH_ADDRESS) {
            payable(msg.sender).transfer(borrowAmount);
        } else {
            ERC20(borrowAsset).transfer(msg.sender, borrowAmount);
        }

        emit Borrow(
            msg.sender,
            borrowAsset,
            borrowAmount,
            collateralAsset,
            collateralAmount,
            interestRate,
            block.timestamp + LOAN_DURATION
        );
    }

    /**
     * @dev Repay a borrow position
     * @param positionIndex Index of the position to repay
     * @param repayAmount Amount to repay
     */
    function repay(uint256 positionIndex, uint256 repayAmount) external payable nonReentrant whenNotPaused {
        if (positionIndex >= borrowPositions[msg.sender].length) revert InvalidPositionIndex();

        BorrowPosition storage position = borrowPositions[msg.sender][positionIndex];
        if (!position.isActive) revert PositionNotActive();
        if (repayAmount == 0) revert RepayAmountTooSmall();

        uint256 timeElapsed = block.timestamp - position.borrowTime;
        uint256 currentInterest = (position.borrowedAmount * position.interestRate * timeElapsed) / (365 days * 10_000);
        uint256 totalDebt = position.borrowedAmount + currentInterest;

        uint256 actualRepayAmount = repayAmount > totalDebt ? totalDebt : repayAmount;

        if (position.borrowedAsset == ETH_ADDRESS) {
            if (msg.value < actualRepayAmount) revert InsufficientETHSent();
            if (msg.value > actualRepayAmount) {
                payable(msg.sender).transfer(msg.value - actualRepayAmount);
            }
        } else {
            ERC20(position.borrowedAsset).transferFrom(msg.sender, address(this), actualRepayAmount);
        }

        uint256 interestPaid = 0;
        uint256 principalPaid = 0;

        if (actualRepayAmount <= currentInterest) {
            interestPaid = actualRepayAmount;
            position.accruedInterest += interestPaid;
        } else {
            interestPaid = currentInterest;
            principalPaid = actualRepayAmount - currentInterest;
            position.borrowedAmount -= principalPaid;
            position.accruedInterest += interestPaid;
        }

        if (principalPaid > 0) {
            totalBorrowed[position.borrowedAsset] -= principalPaid;
        }

        if (interestPaid > 0) {
            _distributeInterest(position.borrowedAsset, interestPaid);
        }

        bool isFullyRepaid = position.borrowedAmount == 0;

        if (isFullyRepaid) {
            if (position.collateralAsset == ETH_ADDRESS) {
                payable(msg.sender).transfer(position.collateralAmount);
            } else {
                ERC20(position.collateralAsset).transfer(msg.sender, position.collateralAmount);
            }

            bool isOnTime = block.timestamp <= position.dueDate;

            creditProfiles[msg.sender].totalRepaid += actualRepayAmount;

            if (isOnTime) {
                creditProfiles[msg.sender].onTimePayments++;
                _updateCreditScore(msg.sender, true, 0);
            } else {
                creditProfiles[msg.sender].latePayments++;
                _updateCreditScore(msg.sender, false, 0);
            }

            position.isActive = false;
        } else {
            creditProfiles[msg.sender].totalRepaid += actualRepayAmount;
        }

        emit Repay(msg.sender, positionIndex, principalPaid, interestPaid, isFullyRepaid);
    }

    /**
     * @dev Liquidate a borrow position
     * @param borrower Address of the borrower
     * @param positionIndex Index of the position to liquidate
     */
    function liquidate(address borrower, uint256 positionIndex) external payable nonReentrant whenNotPaused {
        if (positionIndex >= borrowPositions[borrower].length) revert InvalidPositionIndex();

        BorrowPosition storage position = borrowPositions[borrower][positionIndex];
        if (!position.isActive) revert PositionNotActive();
        if (block.timestamp <= position.dueDate) revert PositionNotLiquidatable();


        uint256 timeElapsed = block.timestamp - position.borrowTime;
        uint256 interest = (position.borrowedAmount * position.interestRate * timeElapsed) / (365 days * 10_000);
        uint256 totalDebt = position.borrowedAmount + interest;

        if (position.borrowedAsset == ETH_ADDRESS) {
            if (msg.value < totalDebt) revert InsufficientETHSent();
            if (msg.value > totalDebt) {
                payable(msg.sender).transfer(msg.value - totalDebt);
            }
        } else {
            ERC20(position.borrowedAsset).transferFrom(msg.sender, address(this), totalDebt);
        }

        totalBorrowed[position.borrowedAsset] -= position.borrowedAmount;

        _distributeInterest(position.borrowedAsset, interest);

        if (position.collateralAsset == ETH_ADDRESS) {
            payable(msg.sender).transfer(position.collateralAmount);
        } else {
            ERC20(position.collateralAsset).transfer(msg.sender, position.collateralAmount);
        }

        creditProfiles[borrower].liquidatedPrincipal += position.borrowedAmount;
        _updateCreditScore(borrower, false, position.borrowedAmount);

        position.isActive = false;

        emit Liquidation(borrower, positionIndex, msg.sender);
    }

    /*//////////////////////////////////////////////////////////////
                            ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Add a new supported asset with its saToken
     * @param asset Address of the asset (use address(0) for ETH)
     * @param name Name for the saToken (e.g., "Share USDT")
     * @param symbol Symbol for the saToken (e.g., "saUSDT")
     * @param borrowLimit Maximum amount that can be borrowed for this asset
     */
    function addSupportedAsset(
        address asset,
        string memory name,
        string memory symbol,
        uint256 borrowLimit
    )
        external
        onlyOwner
    {
        if (supportedAssets[asset]) revert AssetAlreadySupported();
        if (borrowLimit == 0) revert BorrowLimitTooSmall();
        if (bytes(name).length == 0) revert NameEmpty();
        if (bytes(symbol).length == 0) revert SymbolEmpty();

        if (asset != ETH_ADDRESS) {
            if (asset == address(0)) revert InvalidAssetAddress();

            try ERC20(asset).totalSupply() returns (uint256) { }
            catch {
                revert InvalidERC20Token();
            }

            try ERC20(asset).decimals() returns (uint8) { }
            catch {
                revert TokenMissingDecimals();
            }
        }

        YieldToken newYieldToken = new YieldToken(name, symbol, asset, address(this));

        saTokens[asset] = newYieldToken;
        supportedAssets[asset] = true;
        maxBorrowLimit[asset] = borrowLimit;

        emit AssetAdded(asset, address(newYieldToken), borrowLimit);
    }

    /**
     * @dev Remove a supported asset (only if no active positions)
     * @param asset Address of the asset to remove
     */
    function removeSupportedAsset(address asset) external onlyOwner {
        if (!supportedAssets[asset]) revert AssetNotSupported();
        if (asset == ETH_ADDRESS) revert CannotRemoveETH();
        if (asset == USDC) revert CannotRemoveInitialAssets();
        if (asset == MATIC) revert CannotRemoveInitialAssets();
        if (totalReserves[asset] > 0) revert AssetHasActiveReserves();
        if (totalBorrowed[asset] > 0) revert AssetHasActiveBorrows();

        delete supportedAssets[asset];
        delete maxBorrowLimit[asset];
        delete saTokens[asset];

        emit AssetRemoved(asset);
    }

    /**
     * @dev Update borrow limit for an existing asset
     * @param asset Address of the asset
     * @param newLimit New borrow limit
     */
    function updateBorrowLimit(address asset, uint256 newLimit) external onlyOwner {
        if (!supportedAssets[asset]) revert AssetNotSupported();
        if (newLimit == 0) revert LimitTooSmall();

        maxBorrowLimit[asset] = newLimit;

        emit BorrowLimitUpdated(asset, newLimit);
    }

    /**
     * @dev Set borrow limit for an asset
     * @param asset Address of the asset
     * @param newLimit New borrow limit
     */
    function setBorrowLimit(address asset, uint256 newLimit) external onlyOwner {
        maxBorrowLimit[asset] = newLimit;
        emit BorrowLimitUpdated(asset, newLimit);
    }

    /**
     * @dev Set global borrow limit
     * @param newLimit New global borrow limit
     */
    function setGlobalBorrowLimit(uint256 newLimit) external onlyOwner {
        globalBorrowLimit = newLimit;
    }

    /**
     * @dev Withdraw accumulated protocol fees
     * @param asset Address of the asset
     */
    function withdrawProtocolFees(address asset) external onlyOwner {
        uint256 amount = accumulatedFees[asset];
        if (amount == 0) revert NoFeesToWithdraw();

        accumulatedFees[asset] = 0;

        if (asset == ETH_ADDRESS) {
            payable(owner()).transfer(amount);
        } else {
            ERC20(asset).transfer(owner(), amount);
        }
    }

    /**
     * @dev Pause the protocol
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @dev Unpause the protocol
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /*//////////////////////////////////////////////////////////////
                            CREDIT SYSTEM FUNCTIONS
    //////////////////////////////////////////////////////////////*/



    /**
     * @dev Get user's credit tier information including collateral ratio and rate discount
     * @param user Address of the user
     * @return tier Credit tier name (NEW, BRONZE, SILVER, GOLD, PREMIUM, BLACKLISTED)
     * @return collateralRatio Required collateral ratio in basis points (e.g., 20000 = 200%)
     * @return rateDiscount Interest rate discount in basis points (e.g., 80 = 0.8%)
     */
    function getCreditTier(address user) external view returns (
        string memory tier,
        uint256 collateralRatio,
        uint256 rateDiscount
    ) {
        return _getCreditTier(user);
    }

    /**
     * @dev Get base interest rate based on utilization rate (Aave-style kink model)
     * @param asset Address of the asset
     * @return Base interest rate in basis points
     */
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

    /**
     * @dev Get user-specific interest rate combining utilization rate and credit score
     * @param user Address of the user
     * @param asset Address of the asset being borrowed
     * @return User-specific interest rate in basis points
     */
    function getUserBorrowInterestRate(address user, address asset) public view returns (uint256) {
        uint256 baseRate = getBorrowInterestRate(asset);
        uint256 score = creditProfiles[user].score;
        
        // Calculate credit score discount: 0.1% per 100 points
        uint256 discount = (score * CREDIT_DISCOUNT_RATE) / 1000;
        
        // Apply discount while maintaining minimum base rate
        return baseRate > discount ? baseRate - discount : BASE_RATE;
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Internal function to get credit tier information
     * @param user Address of the user
     * @return tier Credit tier name (NEW, BRONZE, SILVER, GOLD, PREMIUM, BLACKLISTED)
     * @return collateralRatio Required collateral ratio in basis points (e.g., 20000 = 200%)
     * @return rateDiscount Interest rate discount in basis points (e.g., 80 = 0.8%)
     */
    function _getCreditTier(address user) internal view returns (
        string memory tier,
        uint256 collateralRatio,
        uint256 rateDiscount
    ) {
        uint256 score = creditProfiles[user].score;
        CreditProfile storage profile = creditProfiles[user];
        
        if (profile.isBlacklisted) {
            return ("BLACKLISTED", 25_000, 0);   // 250% collateral ratio, no discount
        } else if (score >= 800) {
            return ("PREMIUM", 11_000, 80);      // 110% collateral ratio, 0.8% discount
        } else if (score >= 600) {
            return ("GOLD", 13_000, 60);         // 130% collateral ratio, 0.6% discount
        } else if (score >= 400) {
            return ("SILVER", 15_000, 40);       // 150% collateral ratio, 0.4% discount
        } else if (score >= 200) {
            return ("BRONZE", 18_000, 20);       // 180% collateral ratio, 0.2% discount
        } else {
            return ("NEW", 20_000, 0);           // 200% collateral ratio, no discount
        }
    }

    /**
     * @dev Create credit profile for new user
     * @param user Address of the user
     */
    function _createCreditProfile(address user) internal {
        if (!creditProfiles[user].isActive) {
            creditProfiles[user] = CreditProfile({
                score: DEFAULT_CREDIT_SCORE,
                totalBorrowed: 0,
                totalRepaid: 0,
                onTimePayments: 0,
                latePayments: 0,
                liquidatedPrincipal: 0,
                isActive: true,
                isBlacklisted: false
            });

            emit CreditProfileCreated(user, DEFAULT_CREDIT_SCORE);
        }
    }

    /**
     * @dev Distribute interest to lenders and protocol
     * @param asset Address of the asset
     * @param interest Interest amount to distribute
     */
    function _distributeInterest(address asset, uint256 interest) internal {
        if (interest == 0) return;

        uint256 protocolFee = (interest * PROTOCOL_FEE) / 10_000;
        uint256 lenderInterest = interest - protocolFee;

        accumulatedFees[asset] += protocolFee;

        totalReserves[asset] += lenderInterest;

        if (asset == ETH_ADDRESS) {
            saTokens[ETH_ADDRESS].rebase(totalReserves[ETH_ADDRESS]);
        } else if (asset == USDC) {
            saTokens[USDC].rebase(totalReserves[USDC]);
        } else if (asset == MATIC) {
            saTokens[MATIC].rebase(totalReserves[MATIC]);
        }

        emit InterestDistributed(asset, lenderInterest);
    }

    /**
     * @dev Update user's credit score based on behavior
     * @param user Address of the user
     * @param isPositive Whether the action is positive
     * @param liquidatedAmount Amount liquidated (if any)
     */
    function _updateCreditScore(address user, bool isPositive, uint256 liquidatedAmount) internal {
        CreditProfile storage profile = creditProfiles[user];
        uint256 oldScore = profile.score;
        uint256 newScore = oldScore;

        if (liquidatedAmount > 0) {
            // Liquidation penalty: -100 points
            newScore = newScore > 100 ? newScore - 100 : MIN_CREDIT_SCORE;

            if (profile.liquidatedPrincipal > 100_000 * 10 ** 6) {
                // Blacklist for major losses ($100k equivalent)
                profile.isBlacklisted = true;
            }
        } else if (isPositive) {
            // Reward on-time payments: 15-25 points
            uint256 increase = 15;
            if (profile.onTimePayments > 10) increase = 20;
            if (profile.onTimePayments > 20) increase = 25;

            newScore = newScore + increase > MAX_CREDIT_SCORE ? MAX_CREDIT_SCORE : newScore + increase;
        } else {
            // Late payment penalty: 15-25 points
            uint256 decrease = 15;
            if (profile.latePayments > 5) decrease = 25;

            newScore = newScore > decrease ? newScore - decrease : MIN_CREDIT_SCORE;
        }

        profile.score = newScore;

        if (newScore != oldScore) {
            emit CreditScoreUpdated(user, oldScore, newScore);
        }
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Get available liquidity for an asset
     * @param asset Address of the asset
     * @return Available liquidity amount
     */
    function getAvailableLiquidity(address asset) public view returns (uint256) {
        return totalReserves[asset] - totalBorrowed[asset];
    }

    /**
     * @dev Get all borrow positions for a user
     * @param user Address of the user
     * @return Array of borrow positions
     */
    function getBorrowPositions(address user) external view returns (ILendingVaults.BorrowPosition[] memory) {
        return borrowPositions[user];
    }

    /**
     * @dev Get indices of active borrow positions for a user
     * @param user Address of the user
     * @return Array of active position indices
     */
    function getActiveBorrowPositions(address user) external view returns (uint256[] memory) {
        uint256 count = 0;
        for (uint256 i = 0; i < borrowPositions[user].length; i++) {
            if (borrowPositions[user][i].isActive) count++;
        }

        uint256[] memory activePositions = new uint256[](count);
        uint256 index = 0;
        for (uint256 i = 0; i < borrowPositions[user].length; i++) {
            if (borrowPositions[user][i].isActive) {
                activePositions[index] = i;
                index++;
            }
        }

        return activePositions;
    }

    /**
     * @dev Get user's credit profile
     * @param user Address of the user
     * @return Credit profile struct
     */
    function getCreditProfile(address user) external view returns (ILendingVaults.CreditProfile memory) {
        return creditProfiles[user];
    }

    /**
     * @dev Check if user can borrow
     * @param user Address of the user
     * @return Whether user can borrow
     */
    function canBorrow(address user) external view returns (bool) {
        return creditProfiles[user].isActive && !creditProfiles[user].isBlacklisted
            && creditProfiles[user].score >= MIN_CREDIT_SCORE;
    }

    /**
     * @dev Get utilization rate for an asset
     * @param asset Address of the asset
     * @return Utilization rate in basis points
     */
    function getUtilizationRate(address asset) public view returns (uint256) {
        if (totalReserves[asset] == 0) return 0;
        return (totalBorrowed[asset] * UTILIZATION_PRECISION) / totalReserves[asset];
    }

    /**
     * @dev Get detailed utilization information for an asset
     * @param asset Address of the asset
     * @return utilizationRate Current utilization rate in basis points
     * @return isOptimal Whether utilization is at optimal level
     * @return isHigh Whether utilization is high (above optimal)
     * @return isEmergency Whether utilization is at emergency level
     */
    function getUtilizationInfo(address asset) external view returns (
        uint256 utilizationRate,
        bool isOptimal,
        bool isHigh,
        bool isEmergency
    ) {
        utilizationRate = getUtilizationRate(asset);
        isOptimal = utilizationRate <= OPTIMAL_UTILIZATION;
        isHigh = utilizationRate > OPTIMAL_UTILIZATION && utilizationRate <= MAX_UTILIZATION;
        isEmergency = utilizationRate > MAX_UTILIZATION;
    }

    /**
     * @dev Get interest rate breakdown for transparency
     * @param user Address of the user
     * @param asset Address of the asset
     * @return baseRate Base rate from utilization
     * @return creditDiscount Credit score discount
     * @return finalRate Final user rate
     */
    function getInterestRateBreakdown(address user, address asset) external view returns (
        uint256 baseRate,
        uint256 creditDiscount,
        uint256 finalRate
    ) {
        baseRate = getBorrowInterestRate(asset);
        // Get credit score discount from user's credit tier
        (, , creditDiscount) = _getCreditTier(user);
        finalRate = getUserBorrowInterestRate(user, asset);
    }

    /**
     * @dev Get debt information for a borrow position
     * @param user Address of the user
     * @param positionIndex Index of the position
     * @return principal Principal amount borrowed
     * @return interest Accrued interest
     * @return totalDebt Total debt (principal + interest)
     */
    function getPositionDebt(
        address user,
        uint256 positionIndex
    )
        external
        view
        returns (uint256 principal, uint256 interest, uint256 totalDebt)
    {
        if (positionIndex >= borrowPositions[user].length) revert InvalidPositionIndex();

        BorrowPosition storage position = borrowPositions[user][positionIndex];

        if (!position.isActive) {
            return (0, 0, 0);
        }

        principal = position.borrowedAmount;
        uint256 timeElapsed = block.timestamp - position.borrowTime;
        interest = (principal * position.interestRate * timeElapsed) / (365 days * 10_000);
        totalDebt = principal + interest;
    }

    /*//////////////////////////////////////////////////////////////
                            RECEIVE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    receive() external payable { }
    fallback() external payable { }
}
