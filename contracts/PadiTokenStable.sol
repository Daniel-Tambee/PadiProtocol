// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title  Padi Token (PADI) — 1:1 CUSD‑backed, pausable, fee‑on‑mint/redeem
/// @notice Mint and redeem at exactly 1 CUSD per PADI, minus a small protocol fee.
/// @dev    Fees accrue to a designated treasury; owner can update fees & treasury.
contract PadiToken is ERC20, Ownable, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @notice Celo Stable USD (CUSD) token on Celo Mainnet
    IERC20 public immutable cusd;

    /// @notice Address that receives protocol fees
    address public treasury;

    /// @dev Basis points denominator (100.00%)
    uint16 public constant MAX_BPS = 10_000;

    /// @notice Fee on mint, in basis points (e.g. 2 = 0.02%)
    uint16 public mintFeeBps;

    /// @notice Fee on redeem, in basis points
    uint16 public redeemFeeBps;

    /// @notice Maximum PADI that can ever exist (1 billion * 10⁻¹⁸)
    uint256 public constant MAX_SUPPLY = 1_000_000_000 * 10**18;

    /// @dev Emitted when PADI are minted: `to` receives `netAmount`, `fee` goes to `treasury`
    event Minted(address indexed to, uint256 netAmount, uint256 fee);

    /// @dev Emitted when PADI are redeemed: `from` burns `amount`, `netCUSD` returned, `fee` sent to `treasury`
    event Redeemed(address indexed from, uint256 amount, uint256 netCUSD, uint256 fee);

    /// @dev Emitted when fees are updated
    event FeesUpdated(uint16 newMintFeeBps, uint16 newRedeemFeeBps);

    /// @dev Emitted when treasury address is changed
    event TreasuryUpdated(address newTreasury);

    /// @param _cusdAddress  The deployed CUSD token address
    /// @param _treasury     The address to collect fees
    /// @param _mintFeeBps   Initial mint fee (bps)
    /// @param _redeemFeeBps Initial redeem fee (bps)
    constructor(
        address _cusdAddress,
        address _treasury,
        uint16 _mintFeeBps,
        uint16 _redeemFeeBps
    ) ERC20("Padi Token", "PADI")Ownable(msg.sender) {
        
        require(_cusdAddress != address(0), "Invalid CUSD address");
        require(_treasury != address(0), "Invalid treasury");
        require(_mintFeeBps <= MAX_BPS, "Mint fee too high");
        require(_redeemFeeBps <= MAX_BPS, "Redeem fee too high");

        cusd = IERC20(_cusdAddress);
        treasury = _treasury;
        mintFeeBps = _mintFeeBps;
        redeemFeeBps = _redeemFeeBps;
    }

    /// @notice Update the mint & redeem fees (only owner)
    function setFees(uint16 _mintFeeBps, uint16 _redeemFeeBps) external onlyOwner {
        require(_mintFeeBps <= MAX_BPS, "Mint fee too high");
        require(_redeemFeeBps <= MAX_BPS, "Redeem fee too high");
        mintFeeBps = _mintFeeBps;
        redeemFeeBps = _redeemFeeBps;
        emit FeesUpdated(_mintFeeBps, _redeemFeeBps);
    }

    /// @notice Change the treasury address (only owner)
    function setTreasury(address _treasury) external onlyOwner {
        require(_treasury != address(0), "Invalid treasury");
        treasury = _treasury;
        emit TreasuryUpdated(_treasury);
    }

    /// @notice Lock CUSD and mint PADI, after deducting mint fee
    /// @param amount The gross amount of CUSD to deposit
    function mint(uint256 amount)
        external
        whenNotPaused
        nonReentrant
    {
        require(amount > 0, "Amount must be > 0");
        require(totalSupply() + amount <= MAX_SUPPLY, "Exceeds max supply");

        // Pull in collateral
        cusd.safeTransferFrom(msg.sender, address(this), amount);

        // Calculate fee & net mint
        uint256 fee = (amount * mintFeeBps) / MAX_BPS;
        uint256 net = amount - fee;

        // Mint net to user, fee to treasury
        _mint(msg.sender, net);
        if (fee > 0) {
            _mint(treasury, fee);
        }

        emit Minted(msg.sender, net, fee);
    }

    /// @notice Burn PADI and redeem CUSD, after deducting redeem fee
    /// @param amount The gross amount of PADI to burn
    function redeem(uint256 amount)
        external
        whenNotPaused
        nonReentrant
    {
        require(amount > 0, "Amount must be > 0");

        // Calculate fee & net payout
        uint256 fee = (amount * redeemFeeBps) / MAX_BPS;
        uint256 net = amount - fee;

        // Burn total amount from user
        _burn(msg.sender, amount);

        // Transfer net CUSD back, fee to treasury
        cusd.safeTransfer(msg.sender, net);
        if (fee > 0) {
            cusd.safeTransfer(treasury, fee);
        }

        emit Redeemed(msg.sender, amount, net, fee);
    }

    /// @notice Pause minting & redemption in an emergency (only owner)
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice Unpause minting & redemption (only owner)
    function unpause() external onlyOwner {
        _unpause();
    }

    // /// @dev Prevent transfers while paused
    // function _beforeTokenTransfer(
    //     address from,
    //     address to,
    //     uint256 amount
    // ) internal override {
    //     super._beforeTokenTransfer(from, to, amount);
    //     require(!paused(), "Token transfer while paused");
    // }
}
