// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/utils/Nonces.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title  Padi Governance Token (PADI-GOV)
/// @notice Mirrors PadiToken supply for on-chain voting & permits
contract PadiGovernanceToken is ERC20, ERC20Permit, ERC20Votes, Ownable {
    /// @notice Only this address may mint/burn (set to your PadiToken)
    address public minter;

    /// @notice Must match your stable’s cap
    uint256 public constant MAX_SUPPLY = 1_000_000_000 * 10**18;

    constructor(address _minter)
        ERC20("Padi Governance Token", "PADI-GOV")
        ERC20Permit("Padi Governance Token")
        Ownable(msg.sender)
    {
        require(_minter != address(0), "Gov: minter zero");
        minter = _minter;
    }

    function setMinter(address _minter) external onlyOwner {
        require(_minter != address(0), "Gov: minter zero");
        minter = _minter;
    }

    function mint(address to, uint256 amount) external {
        require(msg.sender == minter, "Gov: only minter");
        require(totalSupply() + amount <= MAX_SUPPLY, "Gov: cap exceeded");
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external {
        require(msg.sender == minter, "Gov: only minter");
        _burn(from, amount);
    }

    // ────────────────────────────────────────────
    // RESOLVE DIAMOND INHERITANCE: ERC20 + ERC20Votes
    // ────────────────────────────────────────────
    function _update(address from, address to, uint256 amount)
        internal
        override(ERC20, ERC20Votes)
    {
        super._update(from, to, amount);
    }

    // ────────────────────────────────────────────
    // RESOLVE NONCES COLLISION: ERC20Permit + Nonces
    // ────────────────────────────────────────────
    function nonces(address owner)
        public
        view
        override(ERC20Permit, Nonces)
        returns (uint256)
    {
        return super.nonces(owner);
    }
}
