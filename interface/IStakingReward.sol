// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

/// @title interface for Staking reward logic
/// @author Tamer Fouad
interface IStakingReward {
    /// @notice Struct for staker's info
    /// @param holder Staking holder address
    /// @param amount Staked amount
    /// @param startDate start date of staking
    /// @param expireDate expire date of staking
    /// @param duration Stake duration
    /// @param latestClaimDate Timestamp for the latest claimed date
    /// @param interestRate Interest rate
    struct StakingInfo {
        address holder;
        uint256 amount;
        uint256 startDate;
        uint256 expireDate;
        uint256 duration;
        uint256 latestClaimDate;
        uint8 interestRate;
    }

    /// @dev Emitted when user stake
    /// @param from Staker address
    /// @param amount Staking token amount
    /// @param timestamp Staking time
    event Stake(address indexed from, uint256 amount, uint256 timestamp);

    /// @dev Emitted when a stake holder unstakes
    /// @param from address of the unstaking holder
    /// @param amount token amount
    /// @param timestamp unstaked time
    event UnStake(address indexed from, uint256 amount, uint256 timestamp);

    /// @notice Claim EXO Rewards by staking EXO
    /// @dev Emitted when the user claim reward
    /// @param to address of the claimant
    /// @param timestamp timestamp for the claim
    event Claim(address indexed to, uint256 timestamp);

    /// @notice Claim GCRED by holding EXO
    /// @dev Emitted when the user claim GCRED reward per day
    /// @param to address of the claimant
    /// @param amount a parameter just like in doxygen (must be followed by parameter name)
    /// @param timestamp a parameter just like in doxygen (must be followed by parameter name)
    event ClaimGCRED(address indexed to, uint256 amount, uint256 timestamp);

    /// @notice Claim EXO which is releasing from Foundation Node to prevent inflation
    /// @dev Emitted when the user claim FN reward
    /// @param to address of the claimant
    /// @param amount a parameter just like in doxygen (must be followed by parameter name)
    /// @param timestamp a parameter just like in doxygen (must be followed by parameter name)
    event ClaimFN(address indexed to, uint256 amount, uint256 timestamp);

    /// @dev Emitted when the owner update EXO token address
    /// @param EXO_ADDRESS new EXO token address
    event EXOAddressUpdated(address EXO_ADDRESS);

    /// @dev Emitted when the owner update GCRED token address
    /// @param GCRED_ADDRESS new GCRED token address
    event GCREDAddressUpdated(address GCRED_ADDRESS);

    /// @dev Emitted when the owner update FN wallet address
    /// @param FOUNDATION_NODE new foundation node wallet address
    event FoundationNodeUpdated(address FOUNDATION_NODE);

    /**
     * @notice Stake EXO tokens
     * @param _amount Token amount
     * @param _duration staking lock-up period type
     *
     * Requirements
     *
     * - Validate the balance of EXO holdings
     * - Validate lock-up duration type
     *    0: Soft lock
     *    1: 30 days
     *    2: 60 days
     *    3: 90 days
     *
     * Emits a {Stake} event
     */
    function stake(uint256 _amount, uint8 _duration) external;

    /// @dev Set new `_tier` of `_holder`
    /// @param _holder foundation node address
    /// @param _tier foundation node address
    function setTier(address _holder, uint8 _tier) external;

    /**
     * @dev Set EXO token address
     * @param _EXO_ADDRESS EXO token address
     *
     * Emits a {EXOAddressUpdated} event
     */
    function setEXOAddress(address _EXO_ADDRESS) external;

    /**
     * @dev Set GCRED token address
     * @param _GCRED_ADDRESS GCRED token address
     *
     * Emits a {GCREDAddressUpdated} event
     */
    function setGCREDAddress(address _GCRED_ADDRESS) external;

    /**
     * @dev Set Foundation Node address
     * @param _FOUNDATION_NODE foundation node address
     *
     * Emits a {FoundationNodeUpdated} event
     */
    function setFNAddress(address _FOUNDATION_NODE) external;

    /**
     * @dev Returns user's tier
     * @param _holder Staking holder address
     */
    function getTier(address _holder) external view returns (uint8);

    /**
     * @dev Returns user's staking info array
     * @param _holder Staking holder address
     */
    function getStakingInfos(address _holder)
        external
        view
        returns (StakingInfo[] memory);

    /**
     * @dev Returns staking count of the holder
     * @param _holder staking holder address
     */
    function getStakingCount(address _holder) external view returns (uint256);

    /**
     * @dev Returns minimum token amount in tier
     */
    function getTierMinAmount() external view returns (uint88[4] memory);
}
