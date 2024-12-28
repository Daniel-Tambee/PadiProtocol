// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IPadiProtocol {
    /**
     * @notice Mint an NFT ID card for a new member.
     * @param memberAddress The address of the new member.
     * @param metadataURI The metadata URI for the NFT.
     * @param paymentAmount The amount of the specific token to be paid.
     */
    function mintMembershipNFT(
        address memberAddress,
        string calldata metadataURI,
        uint256 paymentAmount
    ) external;

    /**
     * @notice Assign a legal representative (Padi) to a member.
     * @param memberAddress The address of the member.
     * @param representativeAddress The address of the legal representative.
     */
    function assignRepresentative(
        address memberAddress,
        address representativeAddress
    ) external;

    /**
     * @notice Confirm that a lawyer (Padi) has responded to an emergency call from a member.
     * @param memberAddress The address of the member calling for help.
     * @param caseId The unique identifier for the case.
     * @param lawyerAddress The address of the lawyer (Padi) responding to the emergency.
     */
    function confirmEmergencyResponse(
        address memberAddress,
        uint256 caseId,
        address lawyerAddress
    ) external;

    /**
     * @notice Reward a lawyer (Padi) after confirming their response to an emergency.
     * @param lawyerAddress The address of the lawyer (Padi).
     * @param caseId The unique identifier for the case.
     * @param rewardAmount The amount of tokens to reward the lawyer.
     */
    function rewardLawyerForEmergency(
        address lawyerAddress,
        uint256 caseId,
        uint256 rewardAmount
    ) external;

    /**
     * @notice Sign up a lawyer as a legal representative.
     * @param lawyerAddress The address of the lawyer signing up.
     */
    function signUpLawyer(address lawyerAddress,string calldata profileUri) external;

    /**
     * @notice Track a new case for a lawyer.
     * @param lawyerAddress The address of the lawyer handling the case.
     * @param memberAddress The address of the member involved in the case.
     */
    function addCase(
       address lawyerAddress,
    address memberAddress,
    string calldata descriptionMetadata, // Added descriptionMetadata parameter
    uint256 rewardAmount
    ) external;

    /**
     * @notice Mark a case as resolved for a lawyer.
     * @param lawyerAddress The address of the lawyer handling the case.
     * @param caseId The unique identifier for the case.
     */
    function resolveCase(address lawyerAddress, uint256 caseId) external;

    /**
     * @notice Get the list of open cases for a lawyer.
     * @param lawyerAddress The address of the lawyer.
     * @return caseIds An array of unique identifiers for open cases.
     */
    function getOpenCases(
        address lawyerAddress
    ) external  returns (uint256[] memory caseIds);

    /**
     * @notice Check if an address is a verified member.
     * @param memberAddress The address to check.
     * @return isVerified True if the address is a verified member.
     */
    function isMember(
        address memberAddress
    ) external view returns (bool isVerified);

    /**
     * @notice Check if an address is a registered lawyer.
     * @param lawyerAddress The address to check.
     * @return isRegistered True if the address is a registered lawyer.
     */
    function isLawyer(
        address lawyerAddress
    ) external view returns (bool isRegistered);

    /**
     * @notice Get the legal representative of a member.
     * @param memberAddress The address of the member.
     * @return representativeAddress The address of the legal representative.
     */
    function getRepresentative(
        address memberAddress
    ) external view returns (address representativeAddress);

    /**
     * @notice Set the token contract address used for payments.
     * @param tokenAddress The address of the token contract.
     */
    function setPaymentToken(address tokenAddress) external;

    /**
     * @notice Get the current token contract address used for payments.
     * @return tokenAddress The address of the token contract.
     */
    function getPaymentToken() external view returns (address tokenAddress);

    /**
     * @notice Event emitted when a membership NFT is minted.
     * @param memberAddress The address of the new member.
     * @param tokenId The ID of the minted NFT.
     */
    event MembershipNFTMinted(
        address indexed memberAddress,
        uint256 indexed tokenId
    );

    /**
     * @notice Event emitted when a legal representative is assigned to a member.
     * @param memberAddress The address of the member.
     * @param representativeAddress The address of the legal representative.
     */
    event RepresentativeAssigned(
        address indexed memberAddress,
        address indexed representativeAddress
    );

    /**
     * @notice Event emitted when a lawyer is rewarded after confirming an emergency response.
     * @param lawyerAddress The address of the lawyer receiving the reward.
     * @param rewardAmount The amount of reward given to the lawyer.
     * @param caseId The unique identifier for the case.
     */
    event LawyerRewarded(
        address indexed lawyerAddress,
        uint256 rewardAmount,
        uint256 caseId
    );

    /**
     * @notice Event emitted when a lawyer signs up as a legal representative.
     * @param lawyerAddress The address of the lawyer signing up.
     */
    event LawyerSignedUp(address indexed lawyerAddress);

    /**
     * @notice Event emitted when a new case is added for a lawyer.
     * @param lawyerAddress The address of the lawyer handling the case.
     * @param caseId The unique identifier for the case.
     * @param memberAddress The address of the member involved in the case.
     */
    event CaseAdded(
        address indexed lawyerAddress,
        uint256 indexed caseId,
        address indexed memberAddress
    );

    /**
     * @notice Event emitted when a case is resolved for a lawyer.
     * @param lawyerAddress The address of the lawyer handling the case.
     * @param caseId The unique identifier for the case.
     */
    event CaseResolved(address indexed lawyerAddress, uint256 indexed caseId);

    /**
     * @notice Event emitted when the payment token is updated.
     * @param tokenAddress The new token contract address.
     */
    event PaymentTokenUpdated(address indexed tokenAddress);

    /**
     * @notice Event emitted when an emergency response is confirmed by a lawyer.
     * @param lawyerAddress The address of the lawyer responding to the emergency.
     * @param caseId The unique identifier for the case.
     * @param memberAddress The address of the member involved.
     * @param timestamp The time when the response was confirmed.
     */
    event EmergencyResponseConfirmed(
        address indexed lawyerAddress,
        uint256 indexed caseId,
        address indexed memberAddress,
        uint256 timestamp
    );
}
