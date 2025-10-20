// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

contract ModelRegistry is Ownable {
    enum ModelStatus { Training, Backtesting, Production, Decommissioned }

    struct AIModel {
        bytes32 modelHash;
        address submitter;
        ModelStatus status;
        string performanceMetrics; // e.g., JSON string with Sharpe ratio, etc.
        bool isVerified;
    }

    mapping(uint256 => AIModel) public models;
    uint256 public modelCount;

    event ModelSubmitted(uint256 indexed modelId, bytes32 indexed modelHash, address indexed submitter);
    event ModelStatusUpdated(uint256 indexed modelId, ModelStatus newStatus);
    event ModelPerformanceUpdated(uint256 indexed modelId, string newMetrics);

    constructor() Ownable(msg.sender) {}

    function submitModel(bytes32 _modelHash, string calldata _initialMetrics) external {
        modelCount++;
        models[modelCount] = AIModel({
            modelHash: _modelHash,
            submitter: msg.sender,
            status: ModelStatus.Training,
            performanceMetrics: _initialMetrics,
            isVerified: false
        });
        emit ModelSubmitted(modelCount, _modelHash, msg.sender);
    }

    function updateModelStatus(uint256 _modelId, ModelStatus _status) external onlyOwner {
        require(_modelId > 0 && _modelId <= modelCount, "ModelRegistry: Invalid model ID");
        models[_modelId].status = _status;
        emit ModelStatusUpdated(_modelId, _status);
    }

    function updatePerformanceMetrics(uint256 _modelId, string calldata _newMetrics) external onlyOwner {
        require(_modelId > 0 && _modelId <= modelCount, "ModelRegistry: Invalid model ID");
        models[_modelId].performanceMetrics = _newMetrics;
        emit ModelPerformanceUpdated(_modelId, _newMetrics);
    }

    function verifyModel(uint256 _modelId) external onlyOwner {
        require(_modelId > 0 && _modelId <= modelCount, "ModelRegistry: Invalid model ID");
        models[_modelId].isVerified = true;
    }
}