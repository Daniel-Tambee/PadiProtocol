// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library PadiTypes {
    enum Status {item1, item2 }
    struct Member {
        address wallet;
        address representative;     // Legal representative's address
        uint256 nftId;
        string metadataURI;
        uint256 joinDate;
        uint256 totalCases;
        bool active;
    }

    struct Lawyer {
        address wallet;
        uint256[] caseIds;
        string profileURI;
        uint256 joinDate;
        uint256 totalRewards;
        bool active;
    }

    struct Case {
        uint256 id;
        address member;
        address lawyer;
        string descriptionMetadata;
        uint256 creationDate;
        uint256 resolutionDate;
        bool resolved;
        uint256 rewardAmount;
    }
}
