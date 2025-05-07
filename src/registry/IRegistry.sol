// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

interface IRegistry {
    // Events
    event SetStrategy(address indexed implementation, bool allowed);
    event SetHook(address indexed implementation, bool allowed);
    event SetAsset(address indexed asset, bool allowed);
    event Deploy(address indexed strategy, address indexed sToken, address indexed asset);
    event DeployWithController(address indexed strategy, address indexed sToken, address indexed controller);

    // Errors
    error ZeroAddress();
    error UnauthorizedStrategy();
    error UnauthorizedHook();
    error UnauthorizedAsset();
    error InvalidInitialization();

    function conduit() external view returns (address);

    function allowedStrategies(address implementation) external view returns (bool);
    function allowedHooks(address implementation) external view returns (bool);
    function allowedAssets(address asset) external view returns (bool);

    function isStrategy(address implementation) external view returns (bool);
    function allStrategies() external view returns (address[] memory);
    function isToken(address token) external view returns (bool);
    function allTokens() external view returns (address[] memory tokens);

    function deploy(
        address _implementation,
        string memory _name,
        string memory _symbol,
        address _asset,
        uint8 _assetDecimals,
        address _manager,
        bytes memory _initData
    ) external returns (address strategy, address token);
}
