//SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import "openzeppelin/contracts/access/Ownable.sol";
import "openzeppelin/contracts/security/ReentrancyGuard.sol";

/// @title Partner Protocol - v1
/// @dev This contract manages affiliate tracking and rewards. The contract inhereting this contract must implement their own business and minting logic.
/// @notice This contract has NOT been audited - the authors make no guarantees of it's

contract PartnerProtocol {
    //primary numerator for affiliate rewards (EX: 125/1000 = 12.5%)
    uint256 public immutable affiliateRewardPrimary;
    //secondary numerator for affiliate rewards (EX: 50/1000 = 5%)
    uint256 public immutable affiliateRewardSecondary;
    //denominator for affiliate rewards (10 = 10% degree of precision, 100 = 1% degree of precision, 1000 = 0.1% degree of precision)
    uint256 public immutable affiliateRewardDenominator;

    //global rewards tracking
    uint256 public totalRewards;
    //global rewards claimed tracking
    uint256 public claimedRewards;

    //stores total rewards for each affiliate address
    mapping(address => uint256) public userTotalRewards;
    //stores total rewards claimed for each affiliate address
    mapping(address => uint256) public userRewardsClaimed;

    //event emitted after minting with an affiliate tracking id
    event AffiliatePurchase(uint256 quantity, string clickid);

    // ============ Modifiers ============

    ///@notice This modifier ensures that the minter is not being credited for affiliate rewards, and that the primary and secondary affiliate address are not equal.
    ///@param affiliates array of addresses containing any affiliates.
    modifier affiliateNotSender(address[] calldata affiliates) {
        if (affiliates.length == 0) {
            _;
            return;
        }
        if (affiliates.length > 1) {
            for (uint256 i = 0; i < affiliates.length; i++) {
                require(affiliates[i] != msg.sender, "Affiliate cannot be sender.");
            }
            require(affiliates[0] != affiliates[1], "Affiliates cannot be the same.");
        } else {
            require(affiliates[0] != msg.sender, "Affiliate cannot be sender.");
        }
        _;
    }

    ///@notice constructor to set up immutible rewards variables upon deployment.
    ///@dev affiliateRewardPrimary and affiliateRewardSecondary are numerators, affiliateRewardDenominator is the denominator. affiliateRewardDenominator cannot be zero or smaller than the numerators.
    ///@param _affiliateRewardPrimary Primary affiliate reward numerator.
    ///@param _affiliateRewardSecondary Secondary affiliate reward numerator.
    ///@param _affiliateRewardDenominator Affiliate reward denominator.
    constructor(
        uint256 _affiliateRewardPrimary,
        uint256 _affiliateRewardSecondary,
        uint256 _affiliateRewardDenominator
    ) {
        require(
            _affiliateRewardDenominator > _affiliateRewardPrimary &&
                _affiliateRewardDenominator > _affiliateRewardSecondary,
            "Numerators must be smaller than denominator."
        );
        require(_affiliateRewardDenominator > 0, "Denominator cannot be zero.");
        affiliateRewardPrimary = _affiliateRewardPrimary;
        affiliateRewardSecondary = _affiliateRewardSecondary;
        affiliateRewardDenominator = _affiliateRewardDenominator;
    }

    // ============ Public Write Functions ============

    ///@notice manages affiliate rewards crediting.
    ///@dev Emits AffiliatePurchase Event which is indexed in off-chain affiliate tracking software.
    ///@param quantity Quantity of rewards (tokens/mints) to be credited. This is strictly used for event emission and does not affect the rewards calculation.
    ///@param affiliates An array of addresses containing the primary affiliate (REQUIRED in position 0) and the secondary affiliate (OPTIONAL in position 1).
    ///@param clickid A unique string passed throsugh contract and utilized by off-chain tracking software.
    function _creditAffiliates(
        uint256 quantity,
        address[] calldata affiliates,
        string calldata clickid
    ) internal affiliateNotSender(affiliates) {
        if (affiliates.length == 0) return;
        if (affiliates.length > 1) {
            uint256 primaryReward = (msg.value * affiliateRewardPrimary) / affiliateRewardDenominator;
            uint256 secondaryReward = (msg.value * affiliateRewardSecondary) / affiliateRewardDenominator;
            unchecked {
                userTotalRewards[affiliates[0]] += primaryReward;
                userTotalRewards[affiliates[1]] += secondaryReward;
                totalRewards += (primaryReward + secondaryReward);
            }
        } else {
            uint256 primaryReward = (msg.value * affiliateRewardPrimary) / affiliateRewardDenominator;
            unchecked {
                userTotalRewards[affiliates[0]] += primaryReward;
                totalRewards += primaryReward;
            }
        }
        emit AffiliatePurchase(quantity, clickid);
    }

    ///@notice Claim function for affiliates to claim rewards.
    ///@dev Does not reduce total rewards, instead increases claimed rewards.
    function collectAffiliateRewards() external {
        uint256 balance = userTotalRewards[msg.sender] - userRewardsClaimed[msg.sender];
        claimedRewards += balance;
        userRewardsClaimed[msg.sender] += balance;
        (bool callSuccess, ) = payable(msg.sender).call{value: balance}("");
        require(callSuccess, "Call failed");
    }

    // ============ Read Functions ============

    ///@notice Calculates unclaimed affiliate rewards for param affiliate.
    function getUnclaimedAffiliateReward(address affiliate) external view returns (uint256) {
        return userTotalRewards[affiliate] - userRewardsClaimed[affiliate];
    }

    ///@notice Calculates total unclaimed rewards for the contract.
    ///@dev Public
    function getUnclaimedRewards() public view returns (uint256) {
        return totalRewards - claimedRewards;
    }

    ///@notice internal function to process withdraw of non-reward funds.
    ///@dev EXTERNAL IMPLEMENTATION MUST BE ACCESS CONTROLLED
    function _withdrawMinusRewards(address _address) internal {
        uint256 balance = address(this).balance - getUnclaimedRewards();
        (bool callSuccess, ) = payable(_address).call{value: balance}("");
        require(callSuccess, "Call failed");
    }
}
