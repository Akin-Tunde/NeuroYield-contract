// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// Interface for the strategy contract that manages the underlying assets.
interface IStrategy {
    function deposit(uint256 amount) external;
    function withdraw(uint256 amount) external;
    function totalAssets() external view returns (uint256);
}

/**
 * @title AIYieldVault
 * @dev An ERC4626 tokenized vault that delegates yield generation to a separate strategy contract.
 * This implementation overrides the public deposit/withdraw functions to interact with the strategy.
 */
contract AIYieldVault is ERC4626, Ownable {
    using SafeERC20 for IERC20;

    // The address of the active yield-generating strategy
    IStrategy public strategy;
    // The ID of the AI model from the ModelRegistry that powers this vault's strategy
    uint256 public modelId;

    event StrategyUpdated(address indexed newStrategy);
    event ModelUpdated(uint256 indexed newModelId);

    constructor(
        IERC20 _asset,
        string memory _name,
        string memory _symbol,
        address _strategyAddress,
        uint256 _modelId
    ) ERC4626(_asset) ERC20(_name, _symbol) Ownable(msg.sender) {
        require(_strategyAddress != address(0), "AIYieldVault: Invalid strategy address");
        strategy = IStrategy(_strategyAddress);
        modelId = _modelId;

        // Grant the strategy an infinite approval to spend this vault's assets.
        // This is a one-time setup that simplifies the deposit logic and saves gas.
        IERC20(asset()).approve(address(strategy), type(uint256).max);
    }

    /**
     * @dev Overrides the default ERC4626 behavior to query the strategy contract
     * for the total amount of underlying assets managed. This is the source of truth for TVL.
     */
    function totalAssets() public view override returns (uint256) {
        return strategy.totalAssets();
    }

    /**
     * @dev Deposits assets into the vault and transfers them to the strategy.
     * This function overrides the standard ERC4626 deposit to add the strategy interaction.
     * @return shares The amount of shares minted.
     */
    function deposit(uint256 assets, address receiver) public override returns (uint256 shares) {
        // First, call the internal ERC4626 deposit logic. This calculates shares,
        // pulls assets from the user, and mints shares to the receiver.
        shares = super.deposit(assets, receiver);

        // Then, transfer the newly received assets from this vault to the strategy contract.
        IERC20(asset()).safeTransfer(address(strategy), assets);
    }

    /**
     * @dev Withdraws assets from the strategy and the vault.
     * This function overrides the standard ERC4626 withdraw to add the strategy interaction.
     * @return assets The amount of assets returned.
     */
    function withdraw(uint256 assets, address receiver, address owner) public override returns (uint256) {
        // First, pull the required assets from the strategy back to this vault.
        strategy.withdraw(assets);

        // Now, call the original ERC4626 withdraw logic, which will burn the user's
        // shares and transfer the assets from this vault's balance to the receiver.
        return super.withdraw(assets, receiver, owner);
    }


    // --- Governance Functions ---

    /**
     * @dev Allows the owner (governance) to update the strategy contract.
     * @param _newStrategyAddress The address of the new strategy contract.
     */
    function setStrategy(address _newStrategyAddress) external onlyOwner {
        require(_newStrategyAddress != address(0), "AIYieldVault: Invalid new strategy address");
        
        // A production-ready vault MUST include a robust migration process here
        // to safely transfer all assets from the old strategy to the new one.

        // Revoke approval from the old strategy and grant it to the new one.
        IERC20(asset()).approve(address(strategy), 0);
        IERC20(asset()).approve(_newStrategyAddress, type(uint256).max);

        strategy = IStrategy(_newStrategyAddress);
        emit StrategyUpdated(_newStrategyAddress);
    }

    /**
     * @dev Allows the owner (governance) to update the associated AI model ID for on-chain tracking.
     * @param _newModelId The new model ID from the ModelRegistry.
     */
    function setModelId(uint256 _newModelId) external onlyOwner {
        modelId = _newModelId;
        emit ModelUpdated(_newModelId);
    }
}