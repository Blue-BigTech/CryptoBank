// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

/// @title interface for bridge
/// @author Tamer Fouad
interface IBridge {
    enum Step {
        Burn,
        Mint
    }

    /// @dev Emitted when token transfered via bridge
    /// @param from address
    /// @param to address
    /// @param amount token amount
    /// @param nonce random number for each transfer
    /// @param step whether mint or burn
    event Transfer(
        address indexed from,
        address indexed to,
        uint256 amount,
        uint256 nonce,
        Step indexed step
    );
}
