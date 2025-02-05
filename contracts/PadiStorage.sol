// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./PadiTypes.sol";
import "./IPadiStorage.sol";

 contract PadiStorage is IPadiStorage, Ownable {
    using PadiTypes for *;

    address public padiProtocol;
    uint256 public nextMemberId = 1;
    uint256 public nextCaseId = 1;

    mapping(address => PadiTypes.Member) public membersMap;
    mapping(address => PadiTypes.Lawyer) public lawyersMap;
    mapping(uint256 => PadiTypes.Case) public casesMap;
    mapping(address => bool) public isMemberMap;
    mapping(address => bool) public isLawyerMap;

    // Case tracking optimizations
    mapping(address => uint256[]) private lawyerOpenCases;
    mapping(address => uint256[]) private lawyerClosedCases;

    modifier onlyPadiProtocol() {
        require(msg.sender == padiProtocol, "Unauthorized access");
        _;
    }

    constructor()Ownable(msg.sender) {
    }

    function initializeProtocol(address _padiProtocol) external onlyOwner {
        require(_padiProtocol != address(0), "Invalid protocol address");
        padiProtocol = _padiProtocol;
    }

    // Member functions
    function addOrUpdateMember(PadiTypes.Member calldata member) 
        external 
        onlyPadiProtocol 
    {
        require(member.wallet != address(0), "Invalid member address");
        membersMap[member.wallet] = member;
        isMemberMap[member.wallet] = member.active;
        emit MemberUpdated(member.wallet, member.nftId, member.active);
    }

    // Lawyer functions
    function addOrUpdateLawyer(PadiTypes.Lawyer calldata lawyer) 
        external 
        onlyPadiProtocol 
    {
        require(lawyer.wallet != address(0), "Invalid lawyer address");
        lawyersMap[lawyer.wallet] = lawyer;
        isLawyerMap[lawyer.wallet] = lawyer.active;
        emit LawyerUpdated(lawyer.wallet, lawyer.active);
    }

    // Case functions
    function addOrUpdateCase(PadiTypes.Case calldata _case) 
        external 
        onlyPadiProtocol 
    {
        require(_case.id != 0, "Invalid case ID");
        require(_case.member != address(0), "Invalid member");
        require(_case.lawyer != address(0), "Invalid lawyer");

        // Update case tracking
        if (_case.resolved) {
            _moveCaseToClosed(_case);
        } else {
            _addToOpenCases(_case);
        }

        casesMap[_case.id] = _case;
        emit CaseUpdated(_case.id, _case.member, _case.lawyer, _case.resolved);
    }

    // View functions
    function getLawyerCases(address lawyer) 
        external 
        view 
        returns (uint256[] memory open, uint256[] memory closed) 
    {
        return (lawyerOpenCases[lawyer], lawyerClosedCases[lawyer]);
    }

    // Internal helpers
    function _addToOpenCases(PadiTypes.Case calldata _case) private {
        uint256[] storage cases = lawyerOpenCases[_case.lawyer];
        if (!_existsInArray(cases, _case.id)) {
            cases.push(_case.id);
        }
    }

    function _moveCaseToClosed(PadiTypes.Case calldata _case) private {
        uint256[] storage open = lawyerOpenCases[_case.lawyer];
        for (uint256 i = 0; i < open.length; i++) {
            if (open[i] == _case.id) {
                open[i] = open[open.length - 1];
                open.pop();
                break;
            }
        }
        lawyerClosedCases[_case.lawyer].push(_case.id);
    }

    function _existsInArray(uint256[] storage arr, uint256 value) 
        private 
        view 
        returns (bool) 
    {
        for (uint256 i = 0; i < arr.length; i++) {
            if (arr[i] == value) return true;
        }
        return false;
    }

    function isMember(address user) external view returns (bool) {
    return isMemberMap[user];
}

function isLawyer(address user) external view returns (bool) {
    return isLawyerMap[user];
}

function lawyers(address lawyerAddress) external view override returns (PadiTypes.Lawyer memory) {
    return lawyersMap[lawyerAddress];
}

function members(address memberAddress) external view override returns (PadiTypes.Member memory) {
    return membersMap[memberAddress];
}
function cases(uint256 caseId) external view override returns (PadiTypes.Case memory) {
    return casesMap[caseId];
}
}