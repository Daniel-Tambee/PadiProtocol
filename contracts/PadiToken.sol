// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title Padi Token Contract
/// @notice ERC20 token used as the payment token in the Padi Protocol.

contract PadiToken is ERC20 {
    // Define the maximum supply of 1 billion tokens (with 18 decimals)
    uint256 public constant MAX_SUPPLY = 1_000_000_000 * 10 ** 18;

    constructor() ERC20("Padi Token", "PADI") {
        // Mint the maximum supply to the contract deployer's address
        _mint(msg.sender, MAX_SUPPLY);
    }
}
