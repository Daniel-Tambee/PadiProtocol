// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./PadiTypes.sol";
import "./IPadiStorage.sol";

contract PadiProtocol is ERC721, Ownable {
    using SafeERC20 for IERC20;
    using PadiTypes for *;

    IPadiStorage public storageContract;
    IERC20 public paymentToken;
    address public padiWallet;
    uint256 private _nftIdCounter = 1;

    modifier onlyMember(address member) {
        require(
            msg.sender == member || 
            msg.sender == getRepresentative(member),
            "Unauthorized: Not member or representative"
        );
        _;
    }

    modifier onlyActiveLawyer(address lawyer) {
        require(storageContract.isLawyer(lawyer), "Not registered lawyer");
        PadiTypes.Lawyer memory l = storageContract.lawyers(lawyer);
        require(l.active, "Lawyer inactive");
        _;
    }

    constructor(
        address _storage,
        address _paymentToken,
        address _padiWallet
    ) 
        ERC721("Padi Membership", "PADI")
        Ownable(msg.sender)
    {
        storageContract = IPadiStorage(_storage);
        paymentToken = IERC20(_paymentToken);
        padiWallet = _padiWallet;
    }

    function mintMembershipNFT(
        address member,
        string calldata metadataURI,
        uint256 paymentAmount
    ) external {
        require(balanceOf(member) == 0, "Already has membership NFT");
        paymentToken.safeTransferFrom(msg.sender, padiWallet, paymentAmount);

        uint256 nftId = _nftIdCounter++;
        _mint(member, nftId);

        PadiTypes.Member memory newMember = PadiTypes.Member({
            wallet: member,
            nftId: nftId,
            metadataURI: metadataURI,
            joinDate: block.timestamp,
            totalCases: 0,
            representative: address(0),
            active: true
        });

        storageContract.addOrUpdateMember(newMember);
    }

    function assignRepresentative(
        address member,
        address representative
    ) external onlyMember(member) {
        PadiTypes.Member memory m = storageContract.members(member);
        m.representative = representative;
        storageContract.addOrUpdateMember(m);
    }

    function createCase(
        address lawyer,
        string calldata description,
        uint256 reward
    ) external onlyMember(msg.sender) {
        require(balanceOf(msg.sender) > 0, "Membership NFT required");

        uint256 caseId = storageContract.getAndIncrementCaseId();
        PadiTypes.Case memory newCase = PadiTypes.Case({
            id: caseId,
            member: msg.sender,
            lawyer: lawyer,
            descriptionMetadata: description,
            creationDate: block.timestamp,
            resolutionDate: 0,
            resolved: false,
            rewardAmount: reward
        });

        storageContract.addOrUpdateCase(newCase);
        paymentToken.safeTransferFrom(msg.sender, address(this), reward);
    }

function resolveCase(uint256 caseId) external onlyActiveLawyer(msg.sender) {
    PadiTypes.Case memory c = storageContract.cases(caseId);
    require(c.lawyer == msg.sender, "Case not assigned to lawyer");
    require(!c.resolved, "Case already resolved");

    // Mark the case as resolved
    c.resolved = true;
    c.resolutionDate = block.timestamp;
    storageContract.addOrUpdateCase(c);

    // Fetch lawyer and update stats
    PadiTypes.Lawyer memory l = storageContract.lawyers(msg.sender);
    uint256[] memory existingIds = l.caseIds;
    uint256[] memory updatedIds = new uint256[](existingIds.length + 1);
    bool alreadyExists = false;

    for (uint256 i = 0; i < existingIds.length; i++) {
        updatedIds[i] = existingIds[i];
        if (existingIds[i] == caseId) {
            alreadyExists = true;
        }
    }

    if (!alreadyExists) {
        updatedIds[existingIds.length] = caseId;
    }

    l.caseIds = updatedIds;
    l.totalRewards += c.rewardAmount;
    storageContract.addOrUpdateLawyer(l);

    paymentToken.safeTransfer(msg.sender, c.rewardAmount);
}

    function getRepresentative(address member) public view returns (address) {
        return storageContract.members(member).representative;
    }

    function getOpenCases(address lawyer) external view returns (uint256[] memory) {
        (uint256[] memory open,) = storageContract.getLawyerCases(lawyer);
        return open;
    }

    function registerLawyer(
        address lawyer,
        string calldata profileURI
    ) external onlyOwner {
        PadiTypes.Lawyer memory newLawyer = PadiTypes.Lawyer({
            wallet: lawyer,
            caseIds: new uint256[](0),
            profileURI: profileURI,
            joinDate: block.timestamp,
            totalRewards: 0,
            active: true
        });
        storageContract.addOrUpdateLawyer(newLawyer);
    }

    function setPaymentToken(address token) external onlyOwner {
        paymentToken = IERC20(token);
    }
}
