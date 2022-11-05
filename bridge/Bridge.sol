// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "../interface/IBridge.sol";
import "../interface/IBridgeToken.sol";

import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Bridge is IBridge, Pausable, Ownable {
    address public TOKEN_ADDRESS;

    uint256 private _nonce;
    mapping(uint256 => bool) private _processedNonces;

    constructor(address _TOKEN_ADDRESS) {
        TOKEN_ADDRESS = _TOKEN_ADDRESS;
    }

    function mint(
        address from,
        address to,
        uint256 amount,
        uint256 otherChainNonce
    ) public onlyOwner whenNotPaused {
        require(
            !_processedNonces[otherChainNonce],
            "Bridge: transfer already processed"
        );
        _processedNonces[otherChainNonce] = true;

        IBridgeToken(TOKEN_ADDRESS).bridgeMint(to, amount);

        emit Transfer(from, to, amount, otherChainNonce, Step.Mint);
    }

    function burn(address to, uint256 amount) public whenNotPaused {
        IBridgeToken(TOKEN_ADDRESS).bridgeBurn(msg.sender, amount);

        emit Transfer(msg.sender, to, amount, _nonce, Step.Burn);
        _nonce++;
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }
}
