// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./PadiTypes.sol";

interface IPadiStorage {
function isMember(address) external view returns (bool);
    function isLawyer(address) external view returns (bool);


    // Function signatures
    function addOrUpdateMember(PadiTypes.Member calldata member) external;

    function addOrUpdateLawyer(PadiTypes.Lawyer calldata lawyer) external;

    function addOrUpdateCase(PadiTypes.Case calldata _case) external;

    function getNextMemberId() external returns (uint256);

    function getNextCaseId() external returns (uint256);

    function getLawyerCases(
        address lawyer
    ) external view returns (uint256[] memory);

    function members(address memberId) external view returns (PadiTypes.Member memory);
    function lawyers(address lawyerAddress) external view returns (PadiTypes.Lawyer memory);
    function cases(uint256 caseId) external view returns (PadiTypes.Case memory);


    // Event declarations
    event MemberUpdated(address indexed member, uint256 nftId, bool active);
    event LawyerUpdated(address indexed lawyer, bool active);
    event CaseUpdated(
        uint256 indexed caseId,
        address member,
        address lawyer,
        bool resolved
    );
    event AdminAdded(address indexed admin);
    event AdminRemoved(address indexed admin);
}
