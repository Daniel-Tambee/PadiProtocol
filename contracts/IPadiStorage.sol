// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./PadiTypes.sol";

interface IPadiStorage {
    // Membership status functions
    function isMember(address user) external view returns (bool);
    function isLawyer(address user) external view returns (bool);
    function lawyers(address lawyerAddress) external view returns (PadiTypes.Lawyer memory);
    function members(address memberAddress) external view returns (PadiTypes.Member memory);
    function cases(uint256 caseId) external view returns (PadiTypes.Case memory);

    // Core functions
    function addOrUpdateMember(PadiTypes.Member calldata member) external;
    function initializeProtocol(address _padiProtocol) external;
    function addOrUpdateLawyer(PadiTypes.Lawyer calldata lawyer) external;
    function addOrUpdateCase(PadiTypes.Case calldata _case) external;

    // Next ID getters (using public variable getters)
    function nextMemberId() external view returns (uint256);
    function nextCaseId() external view returns (uint256);

    // Case tracking: returns (openCases, closedCases)
    function getLawyerCases(address lawyer)
        external
        view
        returns (uint256[] memory open, uint256[] memory closed);

    // Event declarations
    event MemberUpdated(address indexed member, uint256 nftId, bool active);
    event LawyerUpdated(address indexed lawyer, bool active);
    event CaseUpdated(
        uint256 indexed caseId,
        address member,
        address lawyer,
        bool resolved
    );
}
