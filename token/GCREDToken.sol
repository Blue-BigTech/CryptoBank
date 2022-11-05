// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "../interface/IGCREDToken.sol";

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract GCREDToken is
    Initializable,
    IGCREDToken,
    ERC20Upgradeable,
    ERC20BurnableUpgradeable,
    PausableUpgradeable,
    AccessControlUpgradeable
{
    bytes32 public constant OWNER_ROLE = keccak256("OWNER_ROLE");
    bytes32 public constant BRIDGE_ROLE = keccak256("BRIDGE_ROLE");
    bytes32 public constant STAKING_ROLE = keccak256("STAKING_ROLE");

    // Metaverse development wallet address
    address public MD_ADDRESS;
    // DAO wallet address
    address public DAO_ADDRESS;
    // EXO contract address
    address public STAKING_REWARD;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _MD_ADDRESS, address _DAO_ADDRESS)
        public
        initializer
    {
        __ERC20_init("GCRED Token", "GCRED");
        __ERC20Burnable_init();
        __Pausable_init();
        __AccessControl_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(OWNER_ROLE, msg.sender);

        MD_ADDRESS = _MD_ADDRESS;
        DAO_ADDRESS = _DAO_ADDRESS;
    }

    /// @inheritdoc IGCREDToken
    function mintForReward(address to, uint256 amount)
        external
        onlyRole(STAKING_ROLE)
    {
        _mint(to, amount);
    }

    /// @inheritdoc IGCREDToken
    function bridgeMint(address to, uint256 amount)
        external
        onlyRole(BRIDGE_ROLE)
    {
        _mint(to, amount);
    }

    /// @inheritdoc IGCREDToken
    function bridgeBurn(address owner, uint256 amount)
        external
        onlyRole(BRIDGE_ROLE)
    {
        _burn(owner, amount);
    }

    /// @inheritdoc IGCREDToken
    function setStakingReward(address _STAKING_REWARD)
        external
        onlyRole(OWNER_ROLE)
    {
        _revokeRole(STAKING_ROLE, STAKING_REWARD);
        STAKING_REWARD = _STAKING_REWARD;
        _grantRole(STAKING_ROLE, STAKING_REWARD);

        emit StakingRewardUpdated(STAKING_REWARD);
    }

    /// @inheritdoc IGCREDToken
    function setMDAddress(address _MD_ADDRESS) external onlyRole(OWNER_ROLE) {
        MD_ADDRESS = _MD_ADDRESS;

        emit MDAddressUpdated(MD_ADDRESS);
    }

    /// @inheritdoc IGCREDToken
    function setDAOAddress(address _DAO_ADDRESS) external onlyRole(OWNER_ROLE) {
        DAO_ADDRESS = _DAO_ADDRESS;

        emit DAOAddressUpdated(DAO_ADDRESS);
    }

    /// @notice NPC game transaction breakdown
    /// @dev Breakdown transaction amount to MD, DAO, burn
    /// @param amount Token amount
    /// @return success
    function buyItem(uint256 amount) external returns (bool) {
        address _owner = _msgSender();
        uint256 burnAmount = (amount * 70) / 100;
        uint256 MD_amount = (amount * 25) / 100;
        uint256 DAO_amount = (amount * 5) / 100;
        _transfer(_owner, MD_ADDRESS, MD_amount);
        _transfer(_owner, DAO_ADDRESS, DAO_amount);
        _burn(_owner, burnAmount);
        return true;
    }

    function mint(address to, uint256 amount) public onlyRole(OWNER_ROLE) {
        _mint(to, amount);
    }

    function pause() public onlyRole(OWNER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(OWNER_ROLE) {
        _unpause();
    }

    /// @notice Redefine transfer function for P2P game transactions breakdown from tokenomics
    /// @dev Breakdown transaction amount to MD, burn
    /// @inheritdoc IERC20Upgradeable
    function transfer(address to, uint256 amount)
        public
        virtual
        override
        returns (bool)
    {
        address owner = _msgSender();
        if (to == MD_ADDRESS || to == DAO_ADDRESS) {
            _transfer(owner, to, amount);
            return true;
        }
        uint256 MDAmount = (amount * 2) / 100;
        uint256 burnAmount = (amount * 3) / 100;
        uint256 transferAmount = amount - MDAmount - burnAmount;

        _transfer(owner, to, transferAmount);
        _transfer(owner, MD_ADDRESS, MDAmount);
        _burn(owner, burnAmount);
        return true;
    }

    /// @notice Redefine transfer function for P2P game transactions breakdown from tokenomics
    /// @dev Breakdown transaction amount to MD, burn
    /// @inheritdoc IERC20Upgradeable
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public virtual override returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, amount);
        if (to == MD_ADDRESS || to == DAO_ADDRESS) {
            _transfer(from, to, amount);
            return true;
        }
        uint256 MDAmount = (amount * 2) / 100;
        uint256 burnAmount = (amount * 3) / 100;
        uint256 transferAmount = amount - MDAmount - burnAmount;

        _transfer(from, to, transferAmount);
        _transfer(from, MD_ADDRESS, MDAmount);
        _burn(from, burnAmount);
        return true;
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override whenNotPaused {
        super._beforeTokenTransfer(from, to, amount);
    }
}
