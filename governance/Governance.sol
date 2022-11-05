// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "../interface/IGovernance.sol";
import "../interface/IStakingReward.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract Governance is
    Initializable,
    IGovernance,
    PausableUpgradeable,
    OwnableUpgradeable
{
    // Counter for votes
    uint256 public voteCounter;
    // EXO token contract address
    address public EXO_ADDRESS;
    // Staking reward contract address
    address public STAKING_REWARD;

    // All registered votes
    // Mapping from vote index to the Vote struct
    mapping(uint256 => Vote) public registeredVotes;
    // Mapping from vote index to Proposal array
    mapping(uint256 => Proposal[]) public registeredProposals;
    // Whether voter can vote to the specific vote->proposal
    mapping(uint256 => mapping(address => bool)) public hasVoted;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _EXO_ADDRESS, address _STAKING_REWARD)
        public
        initializer
    {
        __Pausable_init();
        __Ownable_init();
        EXO_ADDRESS = _EXO_ADDRESS;
        STAKING_REWARD = _STAKING_REWARD;
    }

    /// @inheritdoc	IGovernance
    function createVote(
        uint256 _startDate,
        uint256 _endDate,
        string memory _subject,
        string[] memory _proposals
    ) external override onlyOwner whenNotPaused {
        // Validate voting period
        require(_startDate > block.timestamp, "Governance: Invalid start date");
        require(_startDate < _endDate, "Governance: Invalid end date");
        // Register a new vote
        registeredVotes[voteCounter] = Vote(
            voteCounter,
            _startDate,
            _endDate,
            _subject
        );
        Proposal[] storage proposals = registeredProposals[voteCounter];
        for (uint256 i = 0; i < _proposals.length; i++) {
            proposals.push(Proposal(_proposals[i], 0));
        }
        voteCounter++;

        emit NewVote(_subject, _startDate, _endDate, block.timestamp);
    }

    /// @inheritdoc	IGovernance
    function castVote(uint256 _voteId, uint8 _proposalId)
        external
        override
        whenNotPaused
        returns (uint256)
    {
        address voter = _msgSender();
        // Validate vote id
        require(_voteId < voteCounter, "Governance: Not valid Vote ID");
        // Validate if EXO holder
        require(
            IERC20Upgradeable(EXO_ADDRESS).balanceOf(voter) > 0,
            "Governance: Not EXO holder"
        );
        // Check if already voted or not
        require(!hasVoted[_voteId][voter], "Governance: User already voted");
        // Register a new vote
        Vote memory vote = registeredVotes[_voteId];
        Proposal[] storage proposals = registeredProposals[_voteId];
        require(
            vote.endDate > block.timestamp,
            "Governance: Vote is already expired"
        );
        require(
            vote.startDate <= block.timestamp,
            "Governance: Vote is not started yet"
        );
        require(
            _proposalId < proposals.length,
            "Governance: Not valid proposal id"
        );
        // Calculate vote weight using user's tier and EXO balance
        uint8 tier = IStakingReward(STAKING_REWARD).getTier(voter);
        uint256 balance = IERC20Upgradeable(EXO_ADDRESS).balanceOf(voter);
        uint256 voteWeight = ((uint256(_getVoteWeightPerEXO(tier)) / 100) *
            balance) / 1e18;
        proposals[_proposalId].voteCount += voteWeight;
        // Set true `hasVoted` flag
        hasVoted[_voteId][voter] = true;

        emit VoteCast(voter, _voteId, voteWeight, _proposalId);

        return voteWeight;
    }

    /// @inheritdoc	IGovernance
    function setEXOAddress(address _EXO_ADDRESS) external onlyOwner {
        EXO_ADDRESS = _EXO_ADDRESS;

        emit EXOAddressUpdated(_EXO_ADDRESS);
    }

    /// @inheritdoc	IGovernance
    function setStakingAddress(address _STAKING_REWARD) external onlyOwner {
        STAKING_REWARD = _STAKING_REWARD;

        emit StakingAddressUpdated(STAKING_REWARD);
    }

    /// @inheritdoc	IGovernance
    function getAllVotes() external view override returns (Vote[] memory) {
        require(voteCounter > 0, "EXO: Registered votes Empty");
        Vote[] memory allVotes = new Vote[](voteCounter);
        for (uint256 i = 0; i < voteCounter; i++) {
            Vote storage tmp_vote = registeredVotes[i];
            allVotes[i] = tmp_vote;
        }
        return allVotes;
    }

    /// @inheritdoc	IGovernance
    function getActiveVotes() external view override returns (Vote[] memory) {
        require(voteCounter > 0, "EXO: Vote Empty");
        Vote[] memory activeVotes;
        uint256 j = 0;
        for (uint256 i = 0; i < voteCounter; i++) {
            Vote memory activeVote = registeredVotes[i];
            if (
                activeVote.startDate < block.timestamp &&
                activeVote.endDate > block.timestamp
            ) {
                activeVotes[j++] = activeVote;
            }
        }
        return activeVotes;
    }

    /// @inheritdoc	IGovernance
    function getFutureVotes() external view override returns (Vote[] memory) {
        require(voteCounter > 0, "EXO: Vote Empty");
        Vote[] memory futureVotes;
        uint256 j = 0;
        for (uint256 i = 0; i < voteCounter; i++) {
            Vote memory tmp_vote = registeredVotes[i];
            if (tmp_vote.startDate > block.timestamp) {
                futureVotes[j++] = tmp_vote;
            }
        }
        return futureVotes;
    }

    /// @inheritdoc	IGovernance
    function getProposal(uint256 _voteId, uint256 _proposalId)
        external
        view
        override
        returns (Proposal memory)
    {
        Proposal memory targetProposal = registeredProposals[_voteId][
            _proposalId
        ];
        return targetProposal;
    }

    /// @dev Pause contract
    function pause() public onlyOwner {
        _pause();
    }

    /// @dev Unpause contract
    function unpause() public onlyOwner {
        _unpause();
    }

    /// @dev Vote weight per EXO
    function _getVoteWeightPerEXO(uint8 tier) internal pure returns (uint8) {
        uint8[4] memory weight = [100, 125, 175, 250];
        return weight[tier];
    }
}
