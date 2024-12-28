// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./IPadiProtocol.sol";
import "./IPadiStorage.sol";
import "./PadiStorage.sol";
import "./PadiTypes.sol";

contract PadiProtocol is IPadiProtocol {
    using PadiTypes for *;

    IPadiStorage public storageContract;
    IERC20 public paymentToken;

    constructor(address _storageContract, address _paymentToken) {
        require(
            _storageContract != address(0),
            "Invalid storage contract address"
        );
        require(_paymentToken != address(0), "Invalid payment token address");

        storageContract = IPadiStorage(_storageContract);
        paymentToken = IERC20(_paymentToken);
    }

    function mintMembershipNFT(
        address memberAddress,
        string calldata metadataURI,
        uint256 paymentAmount
    ) external override {
        require(paymentAmount > 0, "Payment amount must be greater than zero");
        require(
            paymentToken.balanceOf(msg.sender) >= paymentAmount,
            "Insufficient token balance"
        );
        require(
            paymentToken.allowance(msg.sender, address(this)) >= paymentAmount,
            "Insufficient token allowance"
        );

        // Transfer the payment tokens from the sender to the contract
        bool success = paymentToken.transferFrom(
            msg.sender,
            address(this),
            paymentAmount
        );
        require(success, "Token transfer failed");

        PadiTypes.Member memory newMember = PadiTypes.Member({
            wallet: memberAddress,
            nftId: storageContract.getNextMemberId() == 0 ? 1 : storageContract.getNextMemberId(), // Assign appropriate value
            metadataURI: metadataURI,
            joinDate: block.timestamp,
            totalCases: 0,
            representative:address(0),
            active: true
        });

        storageContract.addOrUpdateMember(newMember);
    }

function assignRepresentative(
        address memberAddress,
        address representativeAddress
    ) external override {

        require(
            representativeAddress != address(0),
            "Invalid representative address"
        );

        // Fetch the member's current data
        PadiTypes.Member memory member = storageContract.members(
            memberAddress
        );

        // Update the representative address
        member.representative = representativeAddress;

        // Save the updated member data back to storage
        storageContract.addOrUpdateMember(member);
    }

function confirmEmergencyResponse(
    address memberAddress,
    uint256 caseId,
    address lawyerAddress
) external  {
    // Ensure the member exists and is active
    require(storageContract.isMember(memberAddress), "Member does not exist");
    PadiTypes.Member memory member = storageContract.members(memberAddress);
    require(member.active, "Member is not active");

    // Ensure the case exists and is associated with the member
    PadiTypes.Case memory _case = storageContract.cases(caseId);
    require(_case.id != 0, "Case does not exist");
    require(_case.member == memberAddress, "Case is not associated with this member");

    // Ensure the lawyer exists and is valid
    require(storageContract.isLawyer(lawyerAddress), "Lawyer does not exist");
    PadiTypes.Lawyer memory lawyer = storageContract.lawyers(lawyerAddress);
    require(lawyer.active, "Lawyer is not active");

    // Perform the emergency response confirmation logic
    // Update the case as resolved or in-progress (for example)
    _case.resolved = true;  // or any other status depending on your use case

    // Save the updated case back to storage
    storageContract.addOrUpdateCase(_case);

    // Emit an event for emergency response confirmation
}


    function rewardLawyerForEmergency(
    address lawyerAddress,
    uint256 caseId,
    uint256 rewardAmount
) external override {
    // Ensure the lawyer is registered and active
    require(storageContract.isLawyer(lawyerAddress), "Lawyer is not registered");
    PadiTypes.Lawyer memory lawyer = storageContract.lawyers(lawyerAddress);
    require(lawyer.active, "Lawyer is not active");

    // Ensure the case exists and is associated with the lawyer
    PadiTypes.Case memory _case = storageContract.cases(caseId);
    require(_case.id != 0, "Case does not exist");
    require(_case.lawyer == lawyerAddress, "Lawyer is not handling this case");

    // Ensure sufficient payment
    require(paymentToken.balanceOf(address(this)) >= rewardAmount, "Insufficient contract balance");

    // Transfer the reward to the lawyer
    bool success = paymentToken.transfer(lawyerAddress, rewardAmount);
    require(success, "Reward transfer failed");

    // Emit an event for rewarding the lawyer
    emit LawyerRewarded(lawyerAddress, caseId, rewardAmount);
}

    function signUpLawyer(address lawyerAddress, string calldata profileUri) external override {
    require(lawyerAddress != address(0), "Invalid address");
    require(!storageContract.isLawyer(lawyerAddress), "Lawyer is already registered");

    // Create a new Lawyer struct
    PadiTypes.Lawyer memory newLawyer = PadiTypes.Lawyer({
        wallet: lawyerAddress,
        caseIds: new uint256[](0), 
        profileURI: profileUri, // Profile URI can be added later
        joinDate: block.timestamp, // Set the join date to the current block timestamp
        totalRewards: 0, // No rewards initially
        active: true // The lawyer is active upon registration
    });

    // Add the lawyer to storage
    storageContract.addOrUpdateLawyer(newLawyer);

    // Emit event for lawyer registration
    emit LawyerSignedUp(lawyerAddress);
}



    function addCase(
    address lawyerAddress,
    address memberAddress,
    string calldata descriptionMetadata, // Added descriptionMetadata parameter
    uint256 rewardAmount // Added rewardAmount parameter
) external override {
    require(lawyerAddress != address(0), "Invalid lawyer address");
    require(memberAddress != address(0), "Invalid member address");
    require(storageContract.isLawyer(lawyerAddress), "Lawyer is not registered");
    require(storageContract.isMember(memberAddress), "Member is not registered");


    PadiTypes.Case memory newCase = PadiTypes.Case({
        id: storageContract.getNextCaseId() == 0 ? 1 : storageContract.getNextCaseId(),
        member: memberAddress,
        lawyer: lawyerAddress,
        descriptionMetadata: descriptionMetadata, // Set the descriptionMetadata from input
        creationDate: block.timestamp, // Set the creation date
        resolutionDate: 0, // Set resolution date to 0 initially
        resolved: false, // Set resolved to false initially
        rewardAmount: rewardAmount // Set the reward amount for the case
    });

    // Add the case to storage
    storageContract.addOrUpdateCase(newCase);

    // // Emit an event for adding a new case
    // emit CaseAdded(caseId, memberAddress, lawyerAddress);
}



   function resolveCase(
    address lawyerAddress,
    uint256 caseId
) external override {
    require(storageContract.isLawyer(lawyerAddress), "Lawyer is not registered");

    // Fetch the case and ensure it's not already resolved
    PadiTypes.Case memory _case = storageContract.cases(caseId);
    require(_case.id != 0, "Case does not exist");
    require(_case.lawyer == lawyerAddress, "Lawyer is not handling this case");
    require(!_case.resolved, "Case is already resolved");

    // Mark the case as resolved
    _case.resolved = true;

    // Save the updated case to storage
    storageContract.addOrUpdateCase(_case);

    // Emit an event for case resolution
    // emit CaseResolved(caseId, lawyerAddress);
}


    function getOpenCases(
    address lawyerAddress
) external  override returns (uint256[] memory caseIds) {
    require(storageContract.isLawyer(lawyerAddress), "Lawyer is not registered");

    uint256 totalCases = storageContract.getNextCaseId(); 
    uint256[] memory openCases = new uint256[](totalCases);
    uint256 index = 0;

    for (uint256 i = 1; i <= totalCases; i++) {
        PadiTypes.Case memory _case = storageContract.cases(i);
        if (_case.lawyer == lawyerAddress && !_case.resolved) {
            openCases[index] = _case.id;
            index++;
        }
    }

    return openCases;
}


   function isMember(
    address memberAddress
) external view override returns (bool isVerified) {
    return storageContract.isMember(memberAddress);
}


    function isLawyer(
    address lawyerAddress
) external view override returns (bool isRegistered) {
    return storageContract.isLawyer(lawyerAddress);
}


    function getRepresentative(
    address memberAddress
) external view override returns (address representativeAddress) {
    PadiTypes.Member memory member = storageContract.members(memberAddress);
    return member.representative;
}


   function setPaymentToken(address tokenAddress) external override {
    require(tokenAddress != address(0), "Invalid token address");
    paymentToken = IERC20(tokenAddress);
    emit PaymentTokenUpdated(tokenAddress);
}


    function getPaymentToken() external view override returns (address) {
        return address(paymentToken);
    }
}
