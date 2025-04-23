// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// Import your governance token interface
import "./PadiGovToken.sol";

/// @title  Padi Token (PADI) — 1:1 CUSD-backed
contract PadiToken is ERC20, Ownable, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20                  public immutable cusd;
    PadiGovernanceToken     public immutable govToken;
    address                 public treasury;

    uint16  public constant MAX_BPS     = 10_000;
    uint16  public          mintFeeBps;
    uint16  public          redeemFeeBps;

    uint256 public constant MAX_SUPPLY  = 1_000_000_000 * 10**18;

    event Minted(address indexed to, uint256 netAmount, uint256 fee);
    event Redeemed(address indexed from, uint256 amount, uint256 netCUSD, uint256 fee);
    event FeesUpdated(uint16 newMintFeeBps, uint16 newRedeemFeeBps);
    event TreasuryUpdated(address newTreasury);

    /// @param _govToken      Deployed PadiGovernanceToken address
    constructor(
        address _cusdAddress,
        address _treasury,
        uint16  _mintFeeBps,
        uint16  _redeemFeeBps,
        address _govToken
    )
        ERC20("Padi Token", "PADI")
        Ownable(msg.sender)
    {
        require(_cusdAddress  != address(0), "Invalid CUSD addr");
        require(_treasury     != address(0), "Invalid treasury");
        require(_mintFeeBps   <= MAX_BPS,   "Mint fee too high");
        require(_redeemFeeBps <= MAX_BPS,   "Redeem fee too high");
        require(_govToken     != address(0), "Invalid govToken");

        cusd         = IERC20(_cusdAddress);
        treasury     = _treasury;
        mintFeeBps   = _mintFeeBps;
        redeemFeeBps = _redeemFeeBps;
        govToken     = PadiGovernanceToken(_govToken);
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

    /// @notice Mint PADI by depositing CUSD; mirrors into GOV
    function mint(uint256 amount) external whenNotPaused nonReentrant {
        require(amount > 0,                          "Amount > 0");
        require(totalSupply() + amount <= MAX_SUPPLY, "Exceeds max supply");

        // 1) pull in CUSD
        cusd.safeTransferFrom(msg.sender, address(this), amount);

        // 2) compute fee + net
        uint256 fee = (amount * mintFeeBps) / MAX_BPS;
        uint256 net = amount - fee;

        // 3) mint stable PADI
        _mint(msg.sender, net);
        if (fee > 0) _mint(treasury, fee);

        // 4) mirror into governance token (revert all if this fails)
        govToken.mint(msg.sender, net);
        if (fee > 0) govToken.mint(treasury, fee);

        emit Minted(msg.sender, net, fee);
    }

    /// @notice Redeem PADI for CUSD; mirrors burn in GOV
    function redeem(uint256 amount) external whenNotPaused nonReentrant {
        require(amount > 0, "Amount > 0");

        uint256 fee = (amount * redeemFeeBps) / MAX_BPS;
        uint256 net = amount - fee;

        // 1) burn stable PADI
        _burn(msg.sender, amount);

        // 2) mirror burn in governance token
        govToken.burn(msg.sender, amount);

        // 3) send CUSD back
        cusd.safeTransfer(msg.sender, net);
        if (fee > 0) cusd.safeTransfer(treasury, fee);

        emit Redeemed(msg.sender, amount, net, fee);
    }

    /// @notice Pause mint/redeem
    function pause()   external onlyOwner { _pause(); }
    /// @notice Unpause
    function unpause() external onlyOwner { _unpause(); }
}
