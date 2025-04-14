// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IPadiProtocol.sol";          // Contains the interface definition for IPadiProtocol
import "./IPadiStorage.sol";           // Contains the interface for storage operations
import "./PadiTypes.sol";              // Contains the definitions for Member, Lawyer, Case, Incident, Corroborator, etc.
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract PadiProtocol is ERC721, Ownable, IPadiProtocol {
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

    // ================================================================
    // Membership and Representative Functions
    // ================================================================

    function mintMembershipNFT(
        address member,
        string calldata metadataURI,
        uint256 paymentAmount
    ) external override {
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
        emit MembershipNFTMinted(member, nftId);
    }

    function assignRepresentative(
        address member,
        address representative
    ) external override onlyMember(member) {
        PadiTypes.Member memory m = storageContract.members(member);
        m.representative = representative;
        storageContract.addOrUpdateMember(m);
        emit RepresentativeAssigned(member, representative);
    }

    function getRepresentative(address member) public view returns (address) {
        return storageContract.members(member).representative;
    }

    // ================================================================
    // Case Functions
    // ================================================================

    // Existing createCase function using msg.sender as the member.
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
        emit CaseAdded(lawyer, caseId, msg.sender);
    }

    // Implementing the interface addCase function (allowing an explicit member address).
    function addCase(
        address lawyerAddress,
        address memberAddress,
        string calldata descriptionMetadata,
        uint256 rewardAmount
    ) external override {
        require(msg.sender == memberAddress, "Only member can create case");
        require(balanceOf(memberAddress) > 0, "Membership NFT required");

        uint256 caseId = storageContract.getAndIncrementCaseId();
        PadiTypes.Case memory newCase = PadiTypes.Case({
            id: caseId,
            member: memberAddress,
            lawyer: lawyerAddress,
            descriptionMetadata: descriptionMetadata,
            creationDate: block.timestamp,
            resolutionDate: 0,
            resolved: false,
            rewardAmount: rewardAmount
        });

        storageContract.addOrUpdateCase(newCase);
        paymentToken.safeTransferFrom(memberAddress, address(this), rewardAmount);
        emit CaseAdded(lawyerAddress, caseId, memberAddress);
    }

    // Modified resolveCase to match the interface signature.
    function resolveCase(address lawyerAddress, uint256 caseId) external override onlyActiveLawyer(lawyerAddress) {
        require(lawyerAddress == msg.sender, "Unauthorized: Only assigned lawyer can resolve");
        PadiTypes.Case memory c = storageContract.cases(caseId);
        require(c.lawyer == lawyerAddress, "Case not assigned to lawyer");
        require(!c.resolved, "Case already resolved");

        // Mark the case as resolved.
        c.resolved = true;
        c.resolutionDate = block.timestamp;
        storageContract.addOrUpdateCase(c);

        // Update the lawyer's stats.
        PadiTypes.Lawyer memory l = storageContract.lawyers(lawyerAddress);
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
        emit CaseResolved(lawyerAddress, caseId);
    }

    function getOpenCases(address lawyer) external view override returns (uint256[] memory) {
        (uint256[] memory open, ) = storageContract.getLawyerCases(lawyer);
        return open;
    }

    // ================================================================
    // Lawyer Functions
    // ================================================================

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
        emit LawyerSignedUp(lawyer);
    }

    // Self-registration for lawyers.
    function signUpLawyer(
        address lawyer,
        string calldata profileURI
    ) external override {
        require(msg.sender == lawyer, "Can only sign up self");
        PadiTypes.Lawyer memory newLawyer = PadiTypes.Lawyer({
            wallet: lawyer,
            caseIds: new uint256[](0),
            profileURI: profileURI,
            joinDate: block.timestamp,
            totalRewards: 0,
            active: true
        });
        storageContract.addOrUpdateLawyer(newLawyer);
        emit LawyerSignedUp(lawyer);
    }

    // ================================================================
    // Emergency Response Functions
    // ================================================================

    function confirmEmergencyResponse(
        address memberAddress,
        uint256 caseId,
        address lawyerAddress
    ) external override {
        // In a real implementation, you could add further checks to validate the emergency.
        emit EmergencyResponseConfirmed(lawyerAddress, caseId, memberAddress, block.timestamp);
    }

    function rewardLawyerForEmergency(
        address lawyerAddress,
        uint256 caseId,
        uint256 rewardAmount
    ) external override {
        // For security, restrict who can call this function.
        require(msg.sender == owner(), "Unauthorized: Only owner can reward");
        paymentToken.safeTransfer(lawyerAddress, rewardAmount);
        emit LawyerRewarded(lawyerAddress, rewardAmount, caseId);
    }

    // ================================================================
    // Payment Token Management
    // ================================================================

    function setPaymentToken(address token) external override onlyOwner {
        paymentToken = IERC20(token);
        emit PaymentTokenUpdated(token);
    }

    // ================================================================
    // Incident and Corroboration Functions
    // ================================================================

    function reportIncident(
        string calldata descriptionMetadata,
        string[] calldata mediaURIs
    ) external override returns (uint256 incidentId) {
        incidentId = storageContract.getAndIncrementIncidentId();
        PadiTypes.Incident memory newIncident = PadiTypes.Incident({
            id: incidentId,
            reporter: msg.sender,
            descriptionMetadata: descriptionMetadata,
            timestamp: block.timestamp,
            status: PadiTypes.VerificationStatus.Unverified,
            verifiedBy: address(0),
            corroborators: new PadiTypes.Corroborator[](0),
            mediaURIs: mediaURIs
        });
        storageContract.addOrUpdateIncident(newIncident);
        emit IncidentReported(incidentId, msg.sender, block.timestamp);
        return incidentId;
    }

    function addCorroboration(
        uint256 incidentId,
        string calldata comment,
        string[] calldata mediaURIs
    ) external override {
        // Create a new corroborator record.
        PadiTypes.Corroborator memory newCorroborator = PadiTypes.Corroborator({
            member: msg.sender,
            timestamp: block.timestamp,
            comment: comment,
            mediaURIs: mediaURIs
        });
        storageContract.addCorroboratorToIncident(incidentId, newCorroborator);
        emit CorroborationAdded(incidentId, msg.sender, block.timestamp);
    }

    function updateIncidentStatus(
        uint256 incidentId,
        uint8 status
    ) external override {
        // For security, require the caller to be authorized (owner or designated verifier).
        require(msg.sender == owner(), "Unauthorized: Only owner can update status");
        PadiTypes.Incident memory inc = storageContract.incidents(incidentId);
        require(inc.id != 0, "Incident does not exist");
        inc.status = PadiTypes.VerificationStatus(status);
        inc.verifiedBy = msg.sender;
        storageContract.addOrUpdateIncident(inc);
        emit IncidentStatusUpdated(incidentId, status, msg.sender);
    }

    // ================================================================
    // Implementation of isMember and isLawyer per IPadiProtocol
    // ================================================================
    
    function isMember(address memberAddress) external view override returns (bool) {
        return storageContract.isMember(memberAddress);
    }

    function isLawyer(address lawyerAddress) external view override returns (bool) {
        return storageContract.isLawyer(lawyerAddress);
    }
}

