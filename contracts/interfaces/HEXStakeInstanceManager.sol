// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "./HEX.sol";
import "../declarations/Types.sol";

interface IHEXStakeInstanceManager {
    event Approval(
        address indexed owner,
        address indexed approved,
        uint256 indexed tokenId
    );
    event ApprovalForAll(
        address indexed owner,
        address indexed operator,
        bool approved
    );
    event HSIDetokenize(
        uint256 timestamp,
        uint256 indexed hsiTokenId,
        address indexed hsiAddress,
        address indexed staker
    );
    event HSIEnd(
        uint256 timestamp,
        address indexed hsiAddress,
        address indexed staker
    );
    event HSIStart(
        uint256 timestamp,
        address indexed hsiAddress,
        address indexed staker
    );
    event HSITokenize(
        uint256 timestamp,
        uint256 indexed hsiTokenId,
        address indexed hsiAddress,
        address indexed staker
    );
    event HSITransfer(
        uint256 timestamp,
        address indexed hsiAddress,
        address indexed oldStaker,
        address indexed newStaker
    );
    event RoyaltiesSet(uint256 tokenId, LibPart.Part[] royalties);
    event Transfer(
        address indexed from,
        address indexed to,
        uint256 indexed tokenId
    );

    function approve(address to, uint256 tokenId) external;

    function balanceOf(address owner) external view returns (uint256);

    function getApproved(uint256 tokenId) external view returns (address);

    function getRaribleV2Royalties(uint256 id)
        external
        view
        returns (LibPart.Part[] memory);

    function hexStakeDetokenize(uint256 tokenId) external returns (address);

    function hexStakeEnd(uint256 hsiIndex, address hsiAddress)
        external
        returns (uint256);

    function hexStakeStart(uint256 amount, uint256 length)
        external
        returns (address);

    function hexStakeTokenize(uint256 hsiIndex, address hsiAddress)
        external
        returns (uint256);

    function hsiCount(address user) external view returns (uint256);

    function hsiLists(address, uint256) external view returns (address);

    function hsiToken(uint256) external view returns (address);

    function hsiTransfer(
        address currentHolder,
        uint256 hsiIndex,
        address hsiAddress,
        address newHolder
    ) external;

    function hsiUpdate(
        address holder,
        uint256 hsiIndex,
        address hsiAddress,
        ShareCache memory share
    ) external;

    function isApprovedForAll(address owner, address operator)
        external
        view
        returns (bool);

    function name() external view returns (string memory);

    function owner() external pure returns (address);

    function ownerOf(uint256 tokenId) external view returns (address);

    function royaltyInfo(uint256 tokenId, uint256 salePrice)
        external
        view
        returns (address receiver, uint256 royaltyAmount);

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) external;

    function setApprovalForAll(address operator, bool approved) external;

    function stakeCount(address user) external view returns (uint256);

    function stakeLists(address user, uint256 hsiIndex)
        external
        view
        returns (HEXStake memory);

    function supportsInterface(bytes4 interfaceId) external view returns (bool);

    function symbol() external view returns (string memory);

    function tokenByIndex(uint256 index) external view returns (uint256);

    function tokenOfOwnerByIndex(address owner, uint256 index)
        external
        view
        returns (uint256);

    function tokenURI(uint256 tokenId) external view returns (string memory);

    function totalSupply() external view returns (uint256);

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;
}