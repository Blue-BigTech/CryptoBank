// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "../interface/IStakingReward.sol";
import "../interface/IEXOToken.sol";

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract EXOToken is
    Initializable,
    IEXOToken,
    ERC20Upgradeable,
    ERC20BurnableUpgradeable,
    PausableUpgradeable,
    AccessControlUpgradeable
{
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BRIDGE_ROLE = keccak256("BRIDGE_ROLE");

    uint256 constant decimal = 1e18;
    uint256 _totalSupply;

    address public STAKING_REWARD;

    // Bridge contract address that can mint or burn
    address public bridge;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize() public initializer {
        __ERC20_init("EXO Token", "EXO");
        __ERC20Burnable_init();
        __Pausable_init();
        __AccessControl_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);

        _totalSupply = 1e28;
    }

    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }


    /// @inheritdoc IEXOToken
    function bridgeMint(address to, uint256 amount)
        external
        override
        onlyRole(BRIDGE_ROLE)
    {
        _mint(to, amount);
    }

    /// @inheritdoc IEXOToken
    function bridgeBurn(address owner, uint256 amount)
        external
        override
        onlyRole(BRIDGE_ROLE)
    {
        _burn(owner, amount);
    }

    /// @inheritdoc IEXOToken
    function setBridge(address _bridge)
        external
        override
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(_bridge != address(0x0), "Can not be zero address");
        _revokeRole(BRIDGE_ROLE, bridge);
        bridge = _bridge;
        _grantRole(BRIDGE_ROLE, bridge);
    }

    /// @inheritdoc IEXOToken
    function setStakingReward(address _STAKING_REWARD)
        external
        override
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(_STAKING_REWARD != address(0x0), "Can not be zero address");
        _revokeRole(MINTER_ROLE, STAKING_REWARD);
        STAKING_REWARD = _STAKING_REWARD;
        _grantRole(MINTER_ROLE, STAKING_REWARD);
    }

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override whenNotPaused {
        super._beforeTokenTransfer(from, to, amount);
    }

    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override whenNotPaused {
        super._afterTokenTransfer(from, to, amount);

        address user = _msgSender();
        uint8 tier = IStakingReward(STAKING_REWARD).getTier(user);
        uint256 stakingCount = IStakingReward(STAKING_REWARD).getStakingCount(
            user
        );
        // Check if should downgrade user's tier
        if (tier > 0) {
            uint88[4] memory minimumAmount = IStakingReward(STAKING_REWARD)
                .getTierMinAmount();
            uint256 balance = balanceOf(user);
            if (
                balance < uint256(minimumAmount[tier]) * decimal &&
                stakingCount < 1
            ) IStakingReward(STAKING_REWARD).setTier(user, tier - 1);
        }
    }
}
