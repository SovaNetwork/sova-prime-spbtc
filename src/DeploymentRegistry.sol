// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.25;

/**
 * @title DeploymentRegistry
 * @notice Central registry for tracking BTC Vault deployments across multiple networks
 * @dev Maintains deployment history, versions, and network-specific addresses
 */
contract DeploymentRegistry {
    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;
    bytes32 public constant DEPLOYER_ROLE = keccak256("DEPLOYER_ROLE");

    mapping(bytes32 => mapping(address => bool)) private _roles;
    mapping(bytes32 => address) private _roleAdmin;

    struct Deployment {
        uint256 chainId;
        address strategyAddress;
        address tokenAddress;
        address oracleAddress;
        string version;
        uint256 timestamp;
        bool isActive;
    }

    struct NetworkInfo {
        string name;
        uint256 totalDeployments;
        uint256 activeDeployment;
    }

    // Mapping from deployment ID to Deployment struct
    mapping(uint256 => Deployment) public deployments;

    // Mapping from chainId to array of deployment IDs
    mapping(uint256 => uint256[]) public networkDeployments;

    // Mapping from chainId to NetworkInfo
    mapping(uint256 => NetworkInfo) public networks;

    // Counter for deployment IDs
    uint256 public deploymentCounter;

    // Events
    event DeploymentRegistered(
        uint256 indexed deploymentId,
        uint256 indexed chainId,
        address strategyAddress,
        address tokenAddress,
        string version
    );

    event DeploymentDeactivated(uint256 indexed deploymentId, uint256 indexed chainId);

    event DeploymentActivated(uint256 indexed deploymentId, uint256 indexed chainId);

    error InvalidChainId(uint256 chainId);
    error InvalidAddress(address addr);
    error DeploymentNotFound(uint256 deploymentId);
    error DeploymentAlreadyActive();
    error DeploymentAlreadyInactive();

    modifier onlyRole(bytes32 role) {
        require(hasRole(role, msg.sender), "Access denied");
        _;
    }

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(DEPLOYER_ROLE, msg.sender);
    }

    function hasRole(bytes32 role, address account) public view returns (bool) {
        return _roles[role][account];
    }

    function grantRole(bytes32 role, address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(role, account);
    }

    function revokeRole(bytes32 role, address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _roles[role][account] = false;
    }

    function _grantRole(bytes32 role, address account) internal {
        _roles[role][account] = true;
    }

    /**
     * @notice Register a new deployment
     * @param chainId The chain ID where deployment occurred
     * @param strategyAddress The deployed strategy contract address
     * @param tokenAddress The deployed token contract address
     * @param oracleAddress The oracle contract address used
     * @param version The version string for this deployment
     * @param networkName The name of the network
     * @return deploymentId The ID assigned to this deployment
     */
    function registerDeployment(
        uint256 chainId,
        address strategyAddress,
        address tokenAddress,
        address oracleAddress,
        string memory version,
        string memory networkName
    ) external onlyRole(DEPLOYER_ROLE) returns (uint256 deploymentId) {
        if (chainId == 0) revert InvalidChainId(chainId);
        if (strategyAddress == address(0)) revert InvalidAddress(strategyAddress);
        if (tokenAddress == address(0)) revert InvalidAddress(tokenAddress);

        deploymentId = ++deploymentCounter;

        deployments[deploymentId] = Deployment({
            chainId: chainId,
            strategyAddress: strategyAddress,
            tokenAddress: tokenAddress,
            oracleAddress: oracleAddress,
            version: version,
            timestamp: block.timestamp,
            isActive: true
        });

        // Add to network deployments
        networkDeployments[chainId].push(deploymentId);

        // Update network info
        if (networks[chainId].totalDeployments == 0) {
            networks[chainId].name = networkName;
        }
        networks[chainId].totalDeployments++;
        networks[chainId].activeDeployment = deploymentId;

        emit DeploymentRegistered(deploymentId, chainId, strategyAddress, tokenAddress, version);
    }

    /**
     * @notice Deactivate a deployment (e.g., when upgrading)
     * @param deploymentId The deployment ID to deactivate
     */
    function deactivateDeployment(uint256 deploymentId) external onlyRole(DEPLOYER_ROLE) {
        if (deploymentId == 0 || deploymentId > deploymentCounter) {
            revert DeploymentNotFound(deploymentId);
        }

        Deployment storage deployment = deployments[deploymentId];
        if (!deployment.isActive) revert DeploymentAlreadyInactive();

        deployment.isActive = false;

        // Update active deployment for network
        uint256 chainId = deployment.chainId;
        if (networks[chainId].activeDeployment == deploymentId) {
            networks[chainId].activeDeployment = 0;
        }

        emit DeploymentDeactivated(deploymentId, chainId);
    }

    /**
     * @notice Reactivate a deployment
     * @param deploymentId The deployment ID to activate
     */
    function activateDeployment(uint256 deploymentId) external onlyRole(DEPLOYER_ROLE) {
        if (deploymentId == 0 || deploymentId > deploymentCounter) {
            revert DeploymentNotFound(deploymentId);
        }

        Deployment storage deployment = deployments[deploymentId];
        if (deployment.isActive) revert DeploymentAlreadyActive();

        deployment.isActive = true;
        networks[deployment.chainId].activeDeployment = deploymentId;

        emit DeploymentActivated(deploymentId, deployment.chainId);
    }

    /**
     * @notice Get all deployment IDs for a specific network
     * @param chainId The chain ID to query
     * @return Array of deployment IDs
     */
    function getNetworkDeployments(uint256 chainId) external view returns (uint256[] memory) {
        return networkDeployments[chainId];
    }

    /**
     * @notice Get the active deployment for a network
     * @param chainId The chain ID to query
     * @return deployment The active deployment details
     */
    function getActiveDeployment(uint256 chainId) external view returns (Deployment memory deployment) {
        uint256 activeId = networks[chainId].activeDeployment;
        if (activeId == 0) revert DeploymentNotFound(0);
        return deployments[activeId];
    }

    /**
     * @notice Get deployment details by ID
     * @param deploymentId The deployment ID to query
     * @return deployment The deployment details
     */
    function getDeployment(uint256 deploymentId) external view returns (Deployment memory deployment) {
        if (deploymentId == 0 || deploymentId > deploymentCounter) {
            revert DeploymentNotFound(deploymentId);
        }
        return deployments[deploymentId];
    }

    /**
     * @notice Get all active deployments across all networks
     * @return activeDeployments Array of active deployments
     */
    function getAllActiveDeployments() external view returns (Deployment[] memory activeDeployments) {
        uint256 activeCount = 0;

        // Count active deployments
        for (uint256 i = 1; i <= deploymentCounter; i++) {
            if (deployments[i].isActive) {
                activeCount++;
            }
        }

        // Collect active deployments
        activeDeployments = new Deployment[](activeCount);
        uint256 index = 0;
        for (uint256 i = 1; i <= deploymentCounter; i++) {
            if (deployments[i].isActive) {
                activeDeployments[index++] = deployments[i];
            }
        }
    }

    /**
     * @notice Check if a deployment exists and is active
     * @param deploymentId The deployment ID to check
     * @return True if deployment exists and is active
     */
    function isDeploymentActive(uint256 deploymentId) external view returns (bool) {
        if (deploymentId == 0 || deploymentId > deploymentCounter) {
            return false;
        }
        return deployments[deploymentId].isActive;
    }

    /**
     * @notice Get network information
     * @param chainId The chain ID to query
     * @return NetworkInfo struct with network details
     */
    function getNetworkInfo(uint256 chainId) external view returns (NetworkInfo memory) {
        return networks[chainId];
    }
}
