// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

/// @title interface for game token GCRED
/// @author Tamer Fouad
interface IGCREDToken {
    /// @dev Emitted when staking contract address updated
    /// @param _STAKING_REWARD staking contract address
    event StakingRewardUpdated(address _STAKING_REWARD);

    /// @dev Emitted when the owner update MD(metaverse development) wallet address
    /// @param MD_ADDRESS new MD wallet address
    event MDAddressUpdated(address MD_ADDRESS);

    /// @dev Emitted when the owner update DAO wallet address
    /// @param DAO_ADDRESS new DAO wallet address
    event DAOAddressUpdated(address DAO_ADDRESS);

    /// @dev Mint GCRED via bridge
    /// @param to Address to mint
    /// @param amount Token amount to mint
    function bridgeMint(address to, uint256 amount) external;

    /// @dev Burn GCRED via bridge
    /// @param owner Address to burn
    /// @param amount Token amount to burn
    function bridgeBurn(address owner, uint256 amount) external;

    /// @dev Mint GCRED via EXO for daily reward
    /// @param to Address to mint
    /// @param amount Token amount to mint
    function mintForReward(address to, uint256 amount) external;

    /**
     * @dev Set Staking reward contract address
     * @param _STAKING_REWARD staking contract address
     *
     * Emits a {StakingRewardUpdated} event
     */
    function setStakingReward(address _STAKING_REWARD) external;

    /**
     * @dev Set MD(Metaverse Development) wallet address
     * @param _MD_ADDRESS MD wallet address
     *
     * Emits a {MDAddressUpdated} event
     */
    function setMDAddress(address _MD_ADDRESS) external;

    /**
     * @dev Set DAO wallet address
     * @param _DAO_ADDRESS DAO wallet address
     *
     * Emits a {DAOAddressUpdated} event
     */
    function setDAOAddress(address _DAO_ADDRESS) external;
}
