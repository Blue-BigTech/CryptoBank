// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

/// @title interface for Governance token EXO
/// @author Tamer Fouad
interface IEXOToken {
    /// @dev Mint EXO
    /// @param to Address to min
    /// @param amount mint amount
    function mint(address to, uint256 amount) external;

    /// @dev Mint EXO via bridge
    /// @param to Address to mint
    /// @param amount Token amount to mint
    function bridgeMint(address to, uint256 amount) external;

    /// @dev Burn EXO via bridge
    /// @param owner Address to burn
    /// @param amount Token amount to burn
    function bridgeBurn(address owner, uint256 amount) external;

    /// @notice Set bridge contract address
    /// @dev Grant `BRIDGE_ROLE` to bridge contract
    /// @param _bridge Bridge contract address
    function setBridge(address _bridge) external;

    /// @notice Set staking contract address
    /// @dev Grant `MINTER_ROLE` to staking contract
    /// @param _staking Staking contract address
    function setStakingReward(address _staking) external;
}
