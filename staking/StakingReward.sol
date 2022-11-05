// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "../interface/IStakingReward.sol";
import "../interface/IEXOToken.sol";
import "../interface/IGCREDToken.sol";

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract StakingReward is
    Initializable,
    IStakingReward,
    PausableUpgradeable,
    AccessControlUpgradeable
{
    bytes32 public constant OWNER_ROLE = keccak256("OWNER_ROLE");
    bytes32 public constant EXO_ROLE = keccak256("EXO_ROLE");

    uint256 constant MAX_REWRAD = 35e26;
    /// TODO should be updated when deploying
    /*------------------Test Only------------------*/
    // uint256 constant CLAIM_DELAY = 1 minutes;
    /*---------------------------------------------*/
    uint256 constant CLAIM_DELAY = 1 days;
    // Counter for staking
    uint256 public stakingCounter;
    // EXO token address
    address public EXO_ADDRESS;
    // GCRED token address
    address public GCRED_ADDRESS;
    // Foundation Node wallet which is releasing EXO to prevent inflation
    address public FOUNDATION_NODE;
    // Reward amount from FN wallet
    uint256 public FN_REWARD;
    // Last staking timestamp
    uint256 private latestStakingTime;
    // Last claimed time
    uint256 public latestClaimTime;
    // All staking infors
    StakingInfo[] public stakingInfos;
    // Tier of the user; Tier 0 ~ 3
    mapping(address => uint8) public tier;
    // Whether holder can upgrade tier status
    mapping(address => bool) public tierCandidate;
    // Mapping from holder to list of staking infos
    mapping(address => mapping(uint256 => uint256)) private _stakedTokens;
    // Mapping from staking index to index of the holder staking list
    mapping(uint256 => uint256) private _stakedTokensIndex;
    // Mapping from holder to count of staking
    mapping(address => uint256) private _stakingCounter;
    // Mapping from staking index to address
    mapping(uint256 => address) private _stakingHolder;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _EXO_ADDRESS, address _GCRED_ADDRESS)
        public
        initializer
    {
        __Pausable_init();
        __AccessControl_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(OWNER_ROLE, msg.sender);
        _grantRole(EXO_ROLE, _EXO_ADDRESS);

        EXO_ADDRESS = _EXO_ADDRESS;
        GCRED_ADDRESS = _GCRED_ADDRESS;
    }

    /// @inheritdoc	IStakingReward
    function stake(uint256 _amount, uint8 _duration)
        external
        override
        whenNotPaused
    {
        address holder = _msgSender();
        require(
            _amount <= IERC20Upgradeable(EXO_ADDRESS).balanceOf(holder),
            "StakingReward: Not enough EXO token to stake"
        );
        require(_duration < 4, "StakingReward: Duration does not match");

        if (holder == FOUNDATION_NODE) {
            // Calculate reward amount from Foudation Node wallet
            FN_REWARD = (_amount * 75) / 1000 / 365;
        } else {
            uint88[4] memory minAmount = _getTierMinAmount();
            uint24[4] memory period = _getStakingPeriod();
            latestStakingTime = block.timestamp;
            uint8 interestRate = tier[holder] * 4 + _duration;

            stakingInfos.push(
                StakingInfo(
                    holder,
                    _amount,
                    latestStakingTime,
                    latestStakingTime + uint256(period[_duration]),
                    _duration,
                    block.timestamp,
                    interestRate
                )
            );
            // Check user can upgrade tier
            if (
                tier[holder] < 3 &&
                _amount >= uint256(minAmount[tier[holder] + 1]) &&
                _duration > tier[holder]
            ) tierCandidate[holder] = true;
            _addStakingToHolderEnumeration(holder, stakingCounter);
        }

        IERC20Upgradeable(EXO_ADDRESS).transferFrom(
            holder,
            address(this),
            _amount
        );
        emit Stake(holder, _amount, block.timestamp);
    }

    function claimBatch() external onlyRole(OWNER_ROLE) whenNotPaused {
        require(stakingInfos.length > 0, "StakingReward: Nobody staked");
        require(
            latestClaimTime != 0 ||
                block.timestamp - latestClaimTime >= CLAIM_DELAY,
            "StakingReward: Not started new multi claim"
        );
        // Staking holder counter in each `interestRate`
        uint256[16] memory interestHolderCounter;

        for (uint256 i = 0; i < stakingInfos.length; ) {
            address stakingHolder = stakingInfos[i].holder;
            uint256 stakingAmount = stakingInfos[i].amount;
            uint256 interestRate = stakingInfos[i].interestRate;
            if (block.timestamp < stakingInfos[i].expireDate) {
                // Claim reward every day
                if (
                    block.timestamp - stakingInfos[i].latestClaimDate >=
                    CLAIM_DELAY
                ) {
                    // Count
                    interestHolderCounter[interestRate] += 1;
                    // Calculate reward EXO amount
                    uint256 REWARD_APR = _getEXORewardAPR(
                        stakingInfos[i].interestRate
                    );
                    uint256 reward = _calcReward(stakingAmount, REWARD_APR);
                    // Mint reward to staking holder
                    IEXOToken(EXO_ADDRESS).mint(stakingHolder, reward);
                    // Calculate GCRED daily reward
                    uint256 GCRED_REWARD = (stakingInfos[i].amount * 
                        _getGCREDReturn(stakingInfos[i].interestRate)) / 1e6;
                    // send GCRED to holder
                    _sendGCRED(stakingHolder, GCRED_REWARD);
                    // Update latest claimed date
                    stakingInfos[i].latestClaimDate = block.timestamp;

                    emit Claim(stakingHolder, block.timestamp);
                }
                i++;
            } else {
                /* The staking date is expired */
                // Upgrade holder's tier
                if (
                    stakingInfos[i].duration >= tier[stakingHolder] &&
                    tierCandidate[stakingHolder]
                ) {
                    if (tier[stakingHolder] < 3) {
                        tier[stakingHolder] += 1;
                    }
                    tierCandidate[stakingHolder] = false;
                }
                // Remove holder's staking index array
                _removeStakingFromHolderEnumeration(stakingHolder, i);
                _removeStakingFromAllStakingEnumeration(i);
                // Return staked EXO to holder
                IERC20Upgradeable(EXO_ADDRESS).transfer(
                    stakingHolder,
                    stakingAmount
                );
                emit UnStake(stakingHolder, stakingAmount, block.timestamp);
            }
        }
        _getRewardFromFN(interestHolderCounter);
        latestClaimTime = block.timestamp;
    }

    /// @inheritdoc IStakingReward
    function setEXOAddress(address _EXO_ADDRESS)
        external
        override
        onlyRole(OWNER_ROLE)
    {
        EXO_ADDRESS = _EXO_ADDRESS;

        emit EXOAddressUpdated(EXO_ADDRESS);
    }

    /// @inheritdoc IStakingReward
    function setGCREDAddress(address _GCRED_ADDRESS)
        external
        override
        onlyRole(OWNER_ROLE)
    {
        GCRED_ADDRESS = _GCRED_ADDRESS;

        emit GCREDAddressUpdated(GCRED_ADDRESS);
    }

    function setFNAddress(address _FOUNDATION_NODE)
        external
        override
        onlyRole(OWNER_ROLE)
    {
        FOUNDATION_NODE = _FOUNDATION_NODE;

        emit FoundationNodeUpdated(FOUNDATION_NODE);
    }

    function setTier(address _holder, uint8 _tier)
        external
        override
        onlyRole(EXO_ROLE)
    {
        tier[_holder] = _tier;
    }

    function getStakingInfos(address _holder)
        external
        view
        override
        returns (StakingInfo[] memory)
    {
        require(stakingCounter > 0, "EXO: Nobody staked");
        uint256 stakingCount = _stakingCounter[_holder];
        if (stakingCount == 0) {
            // Return an empty array
            return new StakingInfo[](0);
        } else {
            StakingInfo[] memory result = new StakingInfo[](stakingCount);
            for (uint256 index = 0; index < stakingCount; index++) {
                uint256 stakedIndex = stakingOfHolderByIndex(_holder, index);
                result[index] = stakingInfos[stakedIndex];
            }
            return result;
        }
    }

    function getStakingCount(address _holder)
        external
        view
        override
        returns (uint256)
    {
        return _stakingCounter[_holder];
    }

    /// @inheritdoc IStakingReward
    function getTier(address _user) external view returns (uint8) {
        return tier[_user];
    }

    /// @dev Minimum EXO amount in tier
    function getTierMinAmount()
        external
        pure
        override
        returns (uint88[4] memory)
    {
        uint88[4] memory tierMinimumAmount = [
            0,
            2_0000_0000_0000_0000_0000_0000,
            4_0000_0000_0000_0000_0000_0000,
            8_0000_0000_0000_0000_0000_0000
        ];
        return tierMinimumAmount;
    }

    function pause() public onlyRole(OWNER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(OWNER_ROLE) {
        _unpause();
    }

    function stakingOfHolderByIndex(address holder, uint256 index)
        public
        view
        virtual
        returns (uint256)
    {
        require(
            index < _stakingCounter[holder],
            "StakingReward: invalid staking index"
        );
        return _stakedTokens[holder][index];
    }

    function _getRewardFromFN(uint256[16] memory _interestHolderCounter)
        internal
    {
        uint8[16] memory FN_REWARD_PERCENT = _getFNRewardPercent();
        uint256[16] memory _rewardAmountFn;
        for (uint256 i = 0; i < 16; i++) {
            if (_interestHolderCounter[i] == 0) {
                _rewardAmountFn[i] = 0;
            } else {
                _rewardAmountFn[i] =
                    (FN_REWARD * uint256(FN_REWARD_PERCENT[i])) /
                    _interestHolderCounter[i] /
                    1000;
            }
        }
        for (uint256 i = 0; i < stakingInfos.length; i++) {
            uint256 _rewardAmount = _rewardAmountFn[
                stakingInfos[i].interestRate
            ];
            if (_rewardAmount != 0) {
                IEXOToken(EXO_ADDRESS).mint(
                    stakingInfos[i].holder,
                    _rewardAmount
                );
                emit ClaimFN(
                    stakingInfos[i].holder,
                    _rewardAmount,
                    block.timestamp
                );
            }
        }
    }

    /// @dev Staking period
    function _getStakingPeriod() internal pure returns (uint24[4] memory) {
        uint24[4] memory stakingPeriod = [0, 30 days, 60 days, 90 days];
        return stakingPeriod;
    }

    /// @dev Minimum EXO amount in tier
    function _getTierMinAmount() internal pure returns (uint88[4] memory) {
        uint88[4] memory tierMinimumAmount = [
            0,
            2_0000_0000_0000_0000_0000_0000,
            4_0000_0000_0000_0000_0000_0000,
            8_0000_0000_0000_0000_0000_0000
        ];
        return tierMinimumAmount;
    }

    /// @dev EXO Staking reward APR
    function _getEXORewardAPR(uint8 _interestRate)
        internal
        pure
        returns (uint8)
    {
        uint8[16] memory EXO_REWARD_APR = [
            50,
            55,
            60,
            65,
            60,
            65,
            70,
            75,
            60,
            65,
            70,
            75,
            60,
            65,
            70,
            75
        ];
        return EXO_REWARD_APR[_interestRate];
    }

    /// @dev Foundation Node Reward Percent Array
    function _getFNRewardPercent() internal pure returns (uint8[16] memory) {
        uint8[16] memory FN_REWARD_PERCENT = [
            0,
            0,
            0,
            0,
            30,
            60,
            85,
            115,
            40,
            70,
            95,
            125,
            50,
            80,
            105,
            145
        ];
        return FN_REWARD_PERCENT;
    }

    /// @dev GCRED reward per day
    function _getGCREDReturn(uint8 _interest) internal pure returns (uint16) {
        uint16[16] memory GCRED_RETURN = [
            0,
            0,
            0,
            242,
            0,
            0,
            266,
            354,
            0,
            0,
            293,
            390,
            0,
            0,
            322,
            426
        ];
        return GCRED_RETURN[_interest];
    }

    function _sendGCRED(address _address, uint256 _amount) internal {
        IGCREDToken(GCRED_ADDRESS).mintForReward(_address, _amount);

        emit ClaimGCRED(_address, _amount, block.timestamp);
    }

    function _calcReward(uint256 _amount, uint256 _percent)
        internal
        pure
        returns (uint256)
    {
        return (_amount * _percent) / 365000;
    }

    function _addStakingToHolderEnumeration(
        address holder,
        uint256 stakingIndex
    ) private {
        uint256 length = _stakingCounter[holder];
        _stakedTokens[holder][length] = stakingIndex;
        _stakedTokensIndex[stakingIndex] = length;
        _stakingHolder[stakingIndex] = holder;
        _stakingCounter[holder]++;
        stakingCounter++;
    }

    function _removeStakingFromHolderEnumeration(
        address holder,
        uint256 removeStaking
    ) private {
        // To prevent a gap in from's tokens array, we store the last token in the index of the token to delete, and
        // then delete the last slot (swap and pop).
        uint256 lastStakingIndex = _stakingCounter[holder] - 1;
        uint256 stakingIndexOfHolder = _stakedTokensIndex[removeStaking];

        // When the token to delete is the last token, the swap operation is unnecessary
        if (stakingIndexOfHolder != lastStakingIndex) {
            uint256 lastStakingIndex_ = _stakedTokens[holder][lastStakingIndex];

            _stakedTokens[holder][stakingIndexOfHolder] = lastStakingIndex_; // Move the last token to the slot of the to-delete token
            _stakedTokensIndex[lastStakingIndex_] = stakingIndexOfHolder; // Update the moved token's index
        }

        // This also deletes the contents at the last position of the array
        delete _stakedTokensIndex[removeStaking];
        delete _stakedTokens[holder][lastStakingIndex];
        _stakingCounter[holder]--;
    }

    function _removeStakingFromAllStakingEnumeration(uint256 index) private {
        // Update total staking array
        uint256 lastStakingIndex = stakingInfos.length - 1;
        stakingInfos[index] = stakingInfos[lastStakingIndex];
        stakingInfos.pop();
        stakingCounter--;

        address holder = _stakingHolder[lastStakingIndex];
        uint256 stakingIndexOfHolder = _stakedTokensIndex[lastStakingIndex];
        _stakedTokens[holder][stakingIndexOfHolder] = index;
        _stakedTokensIndex[index] = stakingIndexOfHolder;
        _stakingHolder[index] = holder;
        delete _stakedTokensIndex[lastStakingIndex];
        delete _stakingHolder[lastStakingIndex];
    }
}
