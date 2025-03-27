// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./PadiTypes.sol";

interface IPadiStorage {
    function members(address memberAddress) external view returns (PadiTypes.Member memory);
    function lawyers(address lawyerAddress) external view returns (PadiTypes.Lawyer memory);
    function cases(uint256 caseId) external view returns (PadiTypes.Case memory);
    function isMember(address user) external view returns (bool);
    function isLawyer(address user) external view returns (bool);
    function getLawyerCases(address lawyer) external view returns (uint256[] memory, uint256[] memory);
    function addOrUpdateMember(PadiTypes.Member calldata member) external;
    function addOrUpdateLawyer(PadiTypes.Lawyer calldata lawyer) external;
    function addOrUpdateCase(PadiTypes.Case calldata _case) external;
    function getAndIncrementCaseId() external returns (uint256);
}