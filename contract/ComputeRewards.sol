// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract ComputeRewards is AccessControl, ReentrancyGuard {
    IERC20 public immutable rewardToken; // $AIBOT
    bytes32 public constant ORACLE_ROLE = keccak256("ORACLE_ROLE");

    mapping(address => uint256) public rewards;

    event RewardsAllocated(address indexed user, uint256 amount);
    event RewardClaimed(address indexed user, uint256 amount);

    constructor(address _rewardTokenAddress) {
        rewardToken = IERC20(_rewardTokenAddress);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ORACLE_ROLE, msg.sender);
    }

    function allocateRewards(address[] calldata _users, uint256[] calldata _amounts) external onlyRole(ORACLE_ROLE) {
        require(_users.length == _amounts.length, "ComputeRewards: Input array length mismatch");
        for (uint i = 0; i < _users.length; i++) {
            rewards[_users[i]] += _amounts[i];
            emit RewardsAllocated(_users[i], _amounts[i]);
        }
    }

    function claimReward() external nonReentrant {
        uint256 reward = rewards[msg.sender];
        require(reward > 0, "ComputeRewards: No rewards to claim");
        
        rewards[msg.sender] = 0;
        
        require(rewardToken.transfer(msg.sender, reward), "ComputeRewards: Token transfer failed");
        emit RewardClaimed(msg.sender, reward);
    }

    function availableRewards(address _user) external view returns (uint256) {
        return rewards[_user];
    }
}