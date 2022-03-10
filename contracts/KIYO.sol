// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./Base64.sol";

/// @notice Error library for centralised error messaging
library Errors {
    string constant invalidMembershipId = "Unknown Membership ID";
}

contract KIYO is
    ERC1155,
    Ownable,
    ReentrancyGuard
{
    // We use safemath to avoid under and over flows
    using SafeMath for uint256;
    // At the time of writing, a new membership costs 0.25 ether.
    // This variable can change by the appropriate function
    uint256 private membershipCost = 90 * 1e18;
    // Internal Ids that are used to differentiate between the different memberships
    uint256 private constant GENESIS_NFT_ID = 1;
    uint256 private constant STANDARD_NFT_ID = 2;
    
    // Events
    event LogEthDeposit(address);
    event LegislatureChanged(string, uint256);
    // ERC1155
    uint256 private mintedStandardsCounter = 0;
    uint256 private mintedGenesisCounter = 0;
    // NFT metadata
    mapping(uint256 => string) private tokenURIs;
    mapping(uint256 => string) private nftDescriptions;

    /// @notice Initialise KIYO smart contract with the appropriate address and ItemIds of the
    /// Open Sea shared storefront smart contract and the Memberships that are locked in it.
    constructor()
        Ownable()
        ERC1155("")
    {
        tokenURIs[
            STANDARD_NFT_ID
        ] = "ipfs://QmdsKVbwtDjH11bfsxg3Hex8o2yeoeymuqtzTWdvZ7a9hS";
        tokenURIs[
            GENESIS_NFT_ID
        ] = "ipfs://QmdsKVbwtDjH11bfsxg3Hex8o2yeoeymuqtzTWdvZ7a9hS";
        nftDescriptions[STANDARD_NFT_ID] = "KIYO Standard";
        nftDescriptions[GENESIS_NFT_ID] = "KIYO Genesis";
    }

    /// @notice Transfer regular Memberships from the KIYO owner address to the user.
    /// @param _amount How many KIYOs will be transfered.
    /// The user must include in the transaction, the appropriate number of ether in Wei.
    function applyForMembership(uint256 _amount)
        public
        payable
        nonReentrant
    {
        require(
            msg.value >= membershipCost * _amount,
            "ser, the state machine needs oil"
        );
        _safeTransferFrom(
            this.owner(),
            msg.sender,
            STANDARD_NFT_ID,
            _amount,
            ""
        );
    }

    /// @notice Transfer regular Memberships from the KIYO owner address to the user.
    /// @param _amount How many KIYOs will be transfered.
    /// The user must include in the transaction, the appropriate number of ether in Wei.
    function applyForGenesisMembership(uint256 _amount)
        public
        payable
        nonReentrant
    {
        // require(
        //     msg.value >= membershipCost * _amount,
        //     "ser, the state machine needs oil"
        // );
        _safeTransferFrom(
            this.owner(),
            msg.sender,
            STANDARD_NFT_ID,
            _amount,
            ""
        );
    }

    ///@notice Mint new KIYOs to an address, usually that of KIYO.
    function issueMembership(
        address _to,
        uint256 _membershipType,
        uint256 _numberOfMemberships
    ) public onlyOwner {
        if (_membershipType == STANDARD_NFT_ID) {
            mintedStandardsCounter = mintedStandardsCounter.add(
                _numberOfMemberships
            );
        } else if (_membershipType == GENESIS_NFT_ID) {
            mintedGenesisCounter = mintedGenesisCounter.add(
                _numberOfMemberships
            );
        } else {
            revert(Errors.invalidMembershipId);
        }
        _mint(_to, _membershipType, _numberOfMemberships, "");
    }

    function initializeMembership() external onlyOwner {
        issueMembership(
            msg.sender,
            STANDARD_NFT_ID,
            1000
        );
        issueMembership(
            msg.sender,
            GENESIS_NFT_ID,
            100
        );
    }

    /// @notice Change the cost for minting a new regular membership
    /// Can only be called by the owner of the smart contract.
    function legislateCostOfEntry(uint256 _stampCost) external onlyOwner {
        membershipCost = _stampCost;
        emit LegislatureChanged("stampCost", _stampCost);
    }

    /// @notice Mint new memberships to the owner of the smart contract
    /// Can only be called by the owner of the smart contract.
    function mintStandardMemberships(uint256 _newMemberships) external onlyOwner {
        emit LegislatureChanged("Minted new standard memberships", _newMemberships);
        issueMembership(msg.sender, STANDARD_NFT_ID, _newMemberships);
    }

    /// @notice Return the current cost of minting a new regular membership.
    function inquireCostOfEntry() external view returns (uint256) {
        return membershipCost;
    }

    /// @notice Return the current maximum number of  minted Founding Memberships
    function countStandard() external view returns (uint256) {
        return mintedStandardsCounter;
    }

    /// @notice Return the current maximum number of  minted Founding Memberships
    function countGenesis() external view returns (uint256) {
        return mintedGenesisCounter;
    }

    /// @notice Withdraw the funds locked in the smart contract,
    /// originating from the minting of new regular Memberships.
    /// Can only becalled by the owner of the smart contract.
    function raidTheCoffers() external onlyOwner {
        uint256 amount = address(this).balance;
        (bool success, ) = owner().call{value: amount}("");
        require(success, "Anti-corruption agencies stopped the transfer");
    }

    fallback() external payable {
        emit LogEthDeposit(msg.sender);
    }

    receive() external payable {
        emit LogEthDeposit(msg.sender);
    }

    /// @notice Airdrop NFTs to users. The NFTs must first be minted to the owner address.
    function airdropMemberships(
        address[] calldata _awardees,
        uint256[] calldata _numberOfMemberships,
        uint256 _membershipType
    ) external onlyOwner {
        require(
            _awardees.length == _numberOfMemberships.length,
            "array length not equal"
        );
        address daoAddress = this.owner();
        for (uint256 i = 0; i < _awardees.length; i++) {
            safeTransferFrom(
                daoAddress,
                _awardees[i],
                _membershipType,
                _numberOfMemberships[i],
                ""
            );
        }
    }

    /// @notice returns the uri metadata. Used by marketplaces and wallets to show the NFT
    function uri(uint256 _nftId)
        public
        view
        override
        returns (string memory)
    {
        string memory json = Base64.encode(
            bytes(
                string(
                    abi.encodePacked(
                        '{ "name": "',
                        nftDescriptions[_nftId],
                        '", ',
                        '"description" : ',
                        '"Community NFT membership for Kiyo",',
                        '"image": "',
                        tokenURIs[_nftId],
                        '"'
                        "}"
                    )
                )
            )
        );
        return string(abi.encodePacked("data:application/json;base64,", json));
    }

    /// @notice Change the URI of Memberships
    /// @param _tokenURIs Array of new token URIs
    /// @param _nftIds Array of Membership Ids (69 OR 42 OR 7) for the respective URIs
    function changeURIs(
        string[] calldata _tokenURIs,
        uint256[] calldata _nftIds
    ) external onlyOwner {
        for (uint256 i = 0; i < _tokenURIs.length; i++) {
            tokenURIs[_nftIds[i]] = _tokenURIs[i];
        }
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC1155)
        returns (bool)
    {
        return
            super.supportsInterface(interfaceId);
    }
}