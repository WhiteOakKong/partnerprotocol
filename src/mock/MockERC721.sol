// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

///@title MockERC721 with PartnerProtocolInhereted
///@notice This is a mock contract to allow testing of the PartnerProtocol.
///@notice It exposes a basic minting function that allows the user to mint any number of tokens with 1, 2, or 3 affiliates.

import "openzeppelin/contracts/access/Ownable.sol";
import "erc721a/contracts/ERC721A.sol";
import "../PartnerProtocol.sol";

contract MockPartner721 is ERC721A, PartnerProtocol, Ownable {
    constructor(
        uint256 _primaryNumerator,
        uint256 _secondaryNumerator,
        uint256 _denominator
    ) ERC721A("Mock", "MOCK") PartnerProtocol(_primaryNumerator, _secondaryNumerator, _denominator) {}

    function mint(uint64 quantity, address[] calldata affiliates, string calldata clickId) external payable {
        _creditAffiliates(uint256(quantity), affiliates, clickId);
        _mint(msg.sender, quantity);
    }

    ///@notice Overriding the default tokenID start to 1.
    function _startTokenId() internal pure override returns (uint256) {
        return 1;
    }

    function withdraw() external onlyOwner {
        _withdrawMinusRewards(msg.sender);
    }
}
