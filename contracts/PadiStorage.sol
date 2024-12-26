// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "contracts/PadiTypes.sol";
import "contracts/IPadiStorage.sol";


/// @title Padi Storage Contract
/// @notice Handles storage for members, lawyers, and cases in the Padi Protocol
/// @dev Added access control, input validation, and additional safety checks
contract PadiStorage is ERC721 {
using PadiTypes for *;
    address public owner;
    mapping(address => bool) public admins;

   

    mapping(address => PadiTypes.Member) public membersMap;
    mapping(address => PadiTypes.Lawyer) public lawyersMap;
    mapping(uint256 => PadiTypes.Case) public casesMap;
    mapping(address => bool) public isMemberMap;
    mapping(address => bool) public isLawyerMap;

    uint256 public nextCaseId;
    uint256 public nextMemberId;

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

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    modifier onlyAdmin() {
        require(
            admins[msg.sender] || msg.sender == owner,
            "Only admin can call this function"
        );
        _;
    }

    modifier memberExists(address wallet) {
        require(isMemberMap[wallet], "Member does not exist");
        _;
    }

    modifier lawyerExists(address wallet) {
        require(isLawyerMap[wallet], "Lawyer does not exist");
        _;
    }

    modifier caseExists(uint256 caseId) {
        require(casesMap[caseId].id != 0, "Case does not exist");
        _;
    }

    constructor() ERC721("Padi Protocol NFT", "PADI") {
        owner = msg.sender;
        admins[msg.sender] = true;
    }

 // Fetch a member by their address
    function members(address memberId) external view returns (PadiTypes.Member memory) {
        require(isMemberMap[memberId], "Address is not a registered member");
        return membersMap[memberId];
    }

    // Fetch a lawyer by their address
    function lawyers(address lawyerAddress) external view returns (PadiTypes.Lawyer memory) {
        require(isLawyerMap[lawyerAddress], "Address is not a registered lawyer");
        return lawyersMap[lawyerAddress];
    }

    // Fetch a case by its ID
    function cases(uint256 caseId) external view returns (PadiTypes.Case memory) {
        require(casesMap[caseId].member != address(0), "Case ID does not exist");
        return casesMap[caseId];
    }    function addAdmin(address admin) external onlyOwner {
        require(admin != address(0), "Invalid admin address");
        admins[admin] = true;
        emit AdminAdded(admin);
    }

    function removeAdmin(address admin) external onlyOwner {
        require(admin != owner, "Cannot remove owner as admin");
        admins[admin] = false;
        emit AdminRemoved(admin);
    }

    function addOrUpdateMember(PadiTypes.Member memory member) external onlyAdmin {
        require(member.wallet != address(0), "Invalid member address");
        require(bytes(member.metadataURI).length > 0, "Invalid metadata URI");

        if (!isMemberMap[member.wallet]) {
            member.joinDate = block.timestamp;
            member.totalCases = 0;
            member.nftId = nextMemberId++;
            _mint(member.wallet, member.nftId); // Mint an NFT for the new member
        }

        membersMap[member.wallet] = member;
        isMemberMap[member.wallet] = true;
        emit MemberUpdated(member.wallet, member.nftId, member.active);
    }

    function addOrUpdateLawyer(PadiTypes.Lawyer memory lawyer) external onlyAdmin {
        require(lawyer.wallet != address(0), "Invalid lawyer address");
        require(bytes(lawyer.profileURI).length > 0, "Invalid profile URI");

        if (!isLawyerMap[lawyer.wallet]) {
            lawyer.joinDate = block.timestamp;
            lawyer.totalRewards = 0;
        }

        lawyersMap[lawyer.wallet] = lawyer;
        isLawyerMap[lawyer.wallet] = true;
        emit LawyerUpdated(lawyer.wallet, lawyer.active);
    }

    function addOrUpdateCase(
        PadiTypes.Case memory _case
    ) external onlyAdmin caseExists(_case.id) {
        require(_case.member != address(0), "Invalid member address");
        require(_case.lawyer != address(0), "Invalid lawyer address");
        require(bytes(_case.description).length > 0, "Invalid description");
        require(isMemberMap[_case.member], "Member not registered");
        require(isLawyerMap[_case.lawyer], "Lawyer not registered");

        if (casesMap[_case.id].id == 0) {
            _case.creationDate = block.timestamp;
            membersMap[_case.member].totalCases++;
            lawyersMap[_case.lawyer].caseIds.push(_case.id);
        }

        casesMap[_case.id] = _case;
        emit CaseUpdated(_case.id, _case.member, _case.lawyer, _case.resolved);
    }

    function getNextMemberId() external onlyAdmin returns (uint256) {
        return nextMemberId++;
    }

    function getNextCaseId() external onlyAdmin returns (uint256) {
        return nextCaseId++;
    }

    function getLawyerCases(
        address lawyer
    ) external view returns (uint256[] memory) {
        require(isLawyerMap[lawyer], "Lawyer not registered");
        return lawyersMap[lawyer].caseIds;
    }
   function isMember(address member) external view returns (bool) {
        return isMemberMap[member];
    }

    // Manually implemented getter function for isLawyer
    function isLawyer(address lawyer) external view returns (bool) {
        return isLawyerMap[lawyer];
    }
}
