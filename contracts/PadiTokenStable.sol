// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title  Padi Governance Token (PADI-GOV)
/// @notice 1:1 cUSD-backed governance token with permit support
contract PadiStableToken is ERC20, ERC20Permit, Ownable, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @notice Underlying collateral
    IERC20 public immutable cusd;

    /// @notice Fee‐collector
    address public treasury;

    uint16 public constant MAX_BPS = 10_000;
    uint16 public mintFeeBps;
    uint16 public redeemFeeBps;

    uint256 public constant MAX_SUPPLY = 1_000_000_000 * 10**18;

    event Minted(address indexed to, uint256 netAmount, uint256 fee);
    event Redeemed(address indexed from, uint256 amount, uint256 netCUSD, uint256 fee);
    event FeesUpdated(uint16 newMintFeeBps, uint16 newRedeemFeeBps);
    event TreasuryUpdated(address newTreasury);

    constructor(
        address _cusd,
        address _treasury,
        uint16  _mintFeeBps,
        uint16  _redeemFeeBps
    )
        ERC20("Padi Governance Token", "PADI-GOV")
        ERC20Permit("Padi Governance Token")
        Ownable(msg.sender)
    {
        require(_cusd     != address(0), "Invalid cUSD addr");
        require(_treasury != address(0), "Invalid treasury");
        require(_mintFeeBps   <= MAX_BPS, "Mint fee too high");
        require(_redeemFeeBps <= MAX_BPS, "Redeem fee too high");

        cusd         = IERC20(_cusd);
        treasury     = _treasury;
        mintFeeBps   = _mintFeeBps;
        redeemFeeBps = _redeemFeeBps;
    }

    /// @notice Update mint/redemption fees (in BPS)
    function setFees(uint16 _mintFeeBps, uint16 _redeemFeeBps) external onlyOwner {
        require(_mintFeeBps   <= MAX_BPS, "Mint fee too high");
        require(_redeemFeeBps <= MAX_BPS, "Redeem fee too high");
        mintFeeBps   = _mintFeeBps;
        redeemFeeBps = _redeemFeeBps;
        emit FeesUpdated(_mintFeeBps, _redeemFeeBps);
    }

    /// @notice Change the fee‐collector address
    function setTreasury(address _treasury) external onlyOwner {
        require(_treasury != address(0), "Invalid treasury");
        treasury = _treasury;
        emit TreasuryUpdated(_treasury);
    }

    /// @notice Mint PADI-GOV by depositing cUSD; fee taken in cUSD
    function mint(uint256 amount) external whenNotPaused nonReentrant {
        require(amount > 0,                           "Amount > 0");
        require(totalSupply() + amount <= MAX_SUPPLY, "Exceeds max supply");

        // 1) pull in cUSD
        cusd.safeTransferFrom(msg.sender, address(this), amount);

        // 2) compute fee + net
        uint256 fee = (amount * mintFeeBps) / MAX_BPS;
        uint256 net = amount - fee;

        // 3) mint governance tokens
        _mint(msg.sender, net);
        if (fee > 0) _mint(treasury, fee);

        emit Minted(msg.sender, net, fee);
    }

    /// @notice Redeem PADI-GOV for cUSD; fee taken in governance tokens
    function redeem(uint256 amount) external whenNotPaused nonReentrant {
        require(amount > 0, "Amount > 0");

        uint256 fee = (amount * redeemFeeBps) / MAX_BPS;
        uint256 net = amount - fee;

        // 1) burn governance tokens
        _burn(msg.sender, amount);

        // 2) send cUSD back
        cusd.safeTransfer(msg.sender, net);
        if (fee > 0) cusd.safeTransfer(treasury, fee);

        emit Redeemed(msg.sender, amount, net, fee);
    }

    /// @notice Pause mint/redeem
    function pause()   external onlyOwner { _pause(); }
    /// @notice Unpause
    function unpause() external onlyOwner { _unpause(); }

    // ERC20Permit brings in `permit()`, `nonces()`, and `DOMAIN_SEPARATOR` automatically.
    // No further overrides needed unless you add ERC20Votes or other extensions.
}
