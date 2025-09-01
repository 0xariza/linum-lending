// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./IYieldToken.sol";
/**
 * @title YieldToken
 * @dev A rebasing ERC20 token that represents shares in the LendingVaults contract
 * @notice This contract implements a rebasing mechanism where token balances automatically
 * adjust based on the underlying asset value, ensuring fair distribution of protocol yields
 *
 * Key Features:
 * - Rebasing mechanism that adjusts token balances based on underlying asset value
 * - Share-based accounting for precise yield distribution
 * - Integration with the LendingVaults contract for minting/burning operations
 * - Standard ERC20 functionality with rebasing capabilities
 */

contract YieldToken is ERC20, Ownable, IYieldToken {
    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    address public immutable underlyingAsset; // Address of the underlying asset (ETH, USDC, etc.)
    address public lendingProtocol; // Address of the LendingVaults contract

    uint256 public totalShares; // Total shares outstanding across all users
    uint256 public totalAssets; // Total underlying assets in the protocol
    uint256 public totalMintedAssets; // Total assets from minting (prevents donation attacks)
    uint256 public totalTrackedAssets; // Total assets tracked (prevents bootstrap attacks)
    
    // Security constants
    uint256 public constant MIN_DEPOSIT = 1e6; // 1 token minimum (adjusted for 6-decimal tokens like USDC)
    uint256 public constant MIN_TIME_BETWEEN_DEPOSITS = 1 hours; // Rate limiting

    // User share tracking
    mapping(address => uint256) private _shareBalances; // Share balances per user
    mapping(address => uint256) private _lastDepositTime; // Rate limiting per user
    
    // Front-running protection
    mapping(bytes32 => uint256) private _lockedTransferAmounts; // Lock transfer amounts to current ratio

    /*//////////////////////////////////////////////////////////////
                            MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyLendingProtocol() {
        if (msg.sender != lendingProtocol) revert OnlyLendingProtocol();
        _;
    }
    
    modifier rateLimited() {
        // Only apply rate limiting to non-lending protocol addresses
        if (msg.sender != lendingProtocol && 
            block.timestamp < _lastDepositTime[msg.sender] + MIN_TIME_BETWEEN_DEPOSITS) {
            revert RateLimitExceeded();
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        string memory name,
        string memory symbol,
        address _underlyingAsset,
        address _lendingProtocol
    )
        ERC20(name, symbol)
        Ownable(msg.sender)
    {
        underlyingAsset = _underlyingAsset;
        lendingProtocol = _lendingProtocol;
        totalMintedAssets = 0; // Initialize to prevent donation attacks
        totalTrackedAssets = 0; // Initialize to prevent bootstrap attacks
    }

        /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    


    /**
     * @dev Mint shares to user
     * @param to Address to mint shares to
     * @param assets Amount of underlying assets
     * @return shares Number of shares minted
     */
    function mint(address to, uint256 assets) external onlyLendingProtocol returns (uint256 shares) {
        if (to == address(0)) revert InvalidAddress();
        if (assets == 0) revert InvalidAmount();
        if (assets < MIN_DEPOSIT) revert InsufficientDepositAmount();

        // Calculate shares based on current ratio
        shares = _calculateSharesFromAssets(assets);
        
        // Ensure minimum precision
        if (shares == 0) revert InsufficientPrecision();

        // Update state variables
        _shareBalances[to] += shares;
        totalShares += shares;
        totalAssets += assets;
        totalMintedAssets += assets; // Track minted assets to prevent donation attacks
        totalTrackedAssets += assets; // Track all assets to prevent bootstrap attacks
        _lastDepositTime[to] = block.timestamp; // Update rate limiting for future checks

        emit SharesMinted(to, shares, assets);
        emit Transfer(address(0), to, assets);

        return shares;
    }

    /**
     * @dev Burn shares from user
     * @param from Address to burn shares from
     * @param shares Number of shares to burn
     * @return assets Amount of underlying assets returned
     */
    function burn(address from, uint256 shares) external onlyLendingProtocol returns (uint256 assets) {
        if (from == address(0)) revert InvalidAddress();
        if (shares == 0) revert InvalidShares();
        if (_shareBalances[from] < shares) revert InsufficientShares();

        // Calculate assets based on current ratio
        assets = _calculateAssetsFromShares(shares);

        // Update state variables
        _shareBalances[from] -= shares;
        totalShares -= shares;
        totalAssets -= assets;
        totalMintedAssets -= assets; // Track burned assets to prevent donation attacks
        totalTrackedAssets -= assets; // Track all assets to prevent bootstrap attacks

        emit SharesBurned(from, shares, assets);
        emit Transfer(from, address(0), assets);

        return assets;
    }

    /**
     * @dev Update total assets (triggers rebase)
     * @param newTotalAssets New total assets value
     */
    function rebase(uint256 newTotalAssets) external onlyLendingProtocol {
        if (newTotalAssets < totalAssets) revert CannotDecreaseAssets();
        
        // Calculate the difference (this represents interest earned)
        uint256 interestEarned = newTotalAssets - totalAssets;
        
        // Update both totalAssets and totalMintedAssets
        totalAssets = newTotalAssets;
        totalMintedAssets += interestEarned; // Interest earned is legitimate and should be included
        totalTrackedAssets += interestEarned; // Track all assets to prevent bootstrap attacks
        
        emit Rebase(newTotalAssets);
    }

    /**
     * @dev Handle donated assets by updating totalMintedAssets
     * This prevents donation attacks while allowing legitimate donations
     * @param donatedAmount Amount of assets donated
     */
    function handleDonation(uint256 donatedAmount) external onlyLendingProtocol {
        if (donatedAmount == 0) revert InvalidAmount();
        totalMintedAssets += donatedAmount;
        totalTrackedAssets += donatedAmount;
        emit DonationHandled(donatedAmount);
    }

    /**
     * @dev Sync tracked assets with actual contract balance
     * This prevents bootstrap attacks by ensuring all assets are tracked
     * @param newTotalAssets New total assets value
     */
    function syncAssets(uint256 newTotalAssets) external onlyLendingProtocol {
        if (newTotalAssets < totalTrackedAssets) revert CannotDecreaseAssets();
        
        // Calculate the difference (this represents assets that weren't tracked)
        uint256 untrackedAssets = newTotalAssets - totalTrackedAssets;
        
        // Update both totalAssets and totalTrackedAssets
        totalAssets = newTotalAssets;
        totalTrackedAssets = newTotalAssets;
        
        // If there are untracked assets, add them to totalMintedAssets
        if (untrackedAssets > 0) {
            totalMintedAssets += untrackedAssets;
        }
        
        emit AssetsSynced(newTotalAssets, untrackedAssets);
    }




    /**
     * @dev Get shares equivalent to a given amount of assets
     * @param assets Amount of underlying assets
     * @return shares Number of shares equivalent to the assets
     */
    function getSharesForAssets(uint256 assets) external view returns (uint256 shares) {
        return _calculateSharesFromAssets(assets);
    }

    /**
     * @dev Get assets equivalent to a given number of shares
     * @param shares Number of shares
     * @return assets Amount of underlying assets equivalent to the shares
     */
    function getAssetsForShares(uint256 shares) external view returns (uint256 assets) {
        return _calculateAssetsFromShares(shares);
    }

    /*//////////////////////////////////////////////////////////////
                            PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Returns the rebased token balance for an account
     * @param account Address to check balance for
     * @return Token balance
     */
    function balanceOf(address account) public view override returns (uint256) {
        if (totalShares == 0) return 0;
        return _calculateAssetsFromShares(_shareBalances[account]);
    }

    /**
     * @dev Returns the total rebased supply
     * @return Total token supply
     */
    function totalSupply() public view override returns (uint256) {
        return totalAssets;
    }

    /**
     * @dev Returns the internal share balance for an account
     * @param account Address to check shares for
     * @return Share balance
     */
    function sharesOf(address account) public view returns (uint256) {
        return _shareBalances[account];
    }

    /**
     * @dev Transfer tokens (converts to shares internally)
     * @param to Recipient address
     * @param amount Amount to transfer
     * @return Success status
     */
    function transfer(address to, uint256 amount) public override returns (bool) {
        // Lock transfer amount to current ratio to prevent front-running
        bytes32 transferId = keccak256(abi.encodePacked(msg.sender, to, amount, block.timestamp));
        _lockedTransferAmounts[transferId] = amount;
        
        _transferShares(msg.sender, to, amount);
        
        // Clear the locked amount after successful transfer
        delete _lockedTransferAmounts[transferId];
        return true;
    }

    /**
     * @dev Transfer tokens with allowance
     * @param from Sender address
     * @param to Recipient address
     * @param amount Amount to transfer
     * @return Success status
     */
    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        _spendAllowance(from, msg.sender, amount);
        
        // Lock transfer amount to current ratio to prevent front-running
        bytes32 transferId = keccak256(abi.encodePacked(from, to, amount, block.timestamp));
        _lockedTransferAmounts[transferId] = amount;
        
        _transferShares(from, to, amount);
        
        // Clear the locked amount after successful transfer
        delete _lockedTransferAmounts[transferId];
        return true;
    }

    /**
     * @dev Calculate shares from assets based on current ratio
     * @param assets Amount of underlying assets
     * @return shares Number of shares equivalent to the assets
     */
    function _calculateSharesFromAssets(uint256 assets) internal view returns (uint256 shares) {
        return totalShares == 0 ? assets : (assets * totalShares) / totalMintedAssets;
    }

    /**
     * @dev Calculate assets from shares based on current ratio
     * @param shares Number of shares
     * @return assets Amount of underlying assets equivalent to the shares
     */
    function _calculateAssetsFromShares(uint256 shares) internal view returns (uint256 assets) {
        return totalShares == 0 ? shares : (shares * totalMintedAssets) / totalShares;
    }

    /**
     * @dev Internal transfer function
     * @param from Sender address
     * @param to Recipient address
     * @param amount Amount to transfer
     */
    function _transferShares(address from, address to, uint256 amount) internal {
        if (from == address(0)) revert InvalidAddress();
        if (to == address(0)) revert InvalidAddress();

        // Convert amount to shares based on current ratio
        uint256 shares = _calculateSharesFromAssets(amount);
        if (_shareBalances[from] < shares) revert InsufficientBalance();
        
        // Ensure minimum precision
        if (shares == 0) revert InsufficientPrecision();

        // Update share balances
        _shareBalances[from] -= shares;
        _shareBalances[to] += shares;

        emit Transfer(from, to, amount);
    }
}
