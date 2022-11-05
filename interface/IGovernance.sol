// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

/// @title interface for Governance logic
/// @author Tamer Fouad
interface IGovernance {
    /// @notice List: sub list of the vote
    /// @param title Vote list title
    /// @param voteCount Vote count
    struct Proposal {
        string title;
        uint256 voteCount;
    }

    /// @notice Struct for the vote
    /// @param index Vote index
    /// @param startDate Vote start date
    /// @param endDate Vote end date
    /// @param subject Vote subject
    /// @param proposalCount Proposal count
    /// @param lists Proposal array
    struct Vote {
        uint256 index;
        uint256 startDate;
        uint256 endDate;
        string subject;
    }

    /// @dev Emitted when a new vote created
    /// @param subject Subject string
    /// @param start Start date of the voting period
    /// @param end End date of the voting period
    /// @param timestamp created time
    event NewVote(
        string subject,
        uint256 start,
        uint256 end,
        uint256 timestamp
    );

    /// @dev Emitted when voter cast a vote
    /// @param voter voter address
    /// @param voteId vote id
    /// @param proposalId proposal id
    /// @param weight voting weight
    event VoteCast(
        address indexed voter,
        uint256 indexed voteId,
        uint256 weight,
        uint8 indexed proposalId
    );

    /// @dev Emitted when exo address updated
    /// @param _EXO_ADDRESS EXO token address
    event EXOAddressUpdated(address _EXO_ADDRESS);

    /// @dev Emitted when staking contract address updated
    /// @param _STAKING_REWARD staking contract address
    event StakingAddressUpdated(address _STAKING_REWARD);

    /**
     * @notice Create a new vote
     * @param _subject string subject
     * @param _startDate Start date of the voting period
     * @param _endDate End date of the voting period
     * @param _proposals Proposal list
     *
     * Requirements
     *
     * - Only owner can create a new vote
     * - Validate voting period with `_startDate` and `_endDate`
     *
     * Emits a {NewVote} event
     */
    function createVote(
        uint256 _startDate,
        uint256 _endDate,
        string memory _subject,
        string[] memory _proposals
    ) external;

    /**
     * @notice Cast a vote
     * @dev Returns a vote weight
     * @param _voteId Vote Id
     * @param _proposalId Proposal Id
     * @return _weight Vote weight
     *
     * Requirements
     *
     * - Validate `_voteId`
     * - Validate `_proposalId`
     * - Check the voting period
     *
     * Emits a {VoteCast} event
     */
    function castVote(uint256 _voteId, uint8 _proposalId)
        external
        returns (uint256);

    /**
     * @dev Set EXO token address
     * @param _EXO_ADDRESS EXO token address
     *
     * Emits a {EXOAddressUpdated} event
     */
    function setEXOAddress(address _EXO_ADDRESS) external;

    /**
     * @dev Set staking contract address
     * @param _STAKING_REWARD staking contract address
     *
     * Emits a {StakingAddressUpdated} event
     */
    function setStakingAddress(address _STAKING_REWARD) external;

    /// @dev Returns all votes in array
    /// @return allVotes All vote array
    function getAllVotes() external view returns (Vote[] memory);

    /// @dev Returns all active votes in array
    /// @return activeVotes Active vote array
    function getActiveVotes() external view returns (Vote[] memory);

    /// @dev Returns all future votes in array
    /// @return futureVotes Future array
    function getFutureVotes() external view returns (Vote[] memory);

    /// @dev Returns a specific proposal with `voteId` and `proposalId`
    /// @param _voteId Vote id
    /// @param _proposalId Proposal id
    /// @return proposal Proposal
    function getProposal(uint256 _voteId, uint256 _proposalId)
        external
        view
        returns (Proposal memory);
}
