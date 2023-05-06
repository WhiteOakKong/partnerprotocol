// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "forge-std/Test.sol";
import "../src/mock/MockERC721.sol";

contract PartnerProtocolTests is Test {
    MockPartner721 mock721Partner;

    address public deployer = vm.addr(111);
    address public minter = vm.addr(222);
    address public affiliate = vm.addr(333);
    address public affiliate2 = vm.addr(444);

    function setUp() public {
        vm.prank(deployer);
        //set up contract with 10% primary, 5% secondary rewards
        mock721Partner = new MockPartner721(100, 50, 1000);
    }

    function test_primaryAffiliateMint(uint64 value) public {
        vm.assume(value < 300 && value > 0);
        uint256 dealAmount = uint256(value) * 0.1 ether;
        vm.deal(minter, dealAmount);
        vm.startPrank(minter);
        address[] memory affiliates = new address[](1);
        affiliates[0] = address(affiliate);
        mock721Partner.mint{value: dealAmount}(value, affiliates, "click123");
        assertEq(
            mock721Partner.getUnclaimedAffiliateReward(affiliate),
            (dealAmount * mock721Partner.affiliateRewardPrimary()) / mock721Partner.affiliateRewardDenominator()
        );
    }

    function test_noAffiliateMint(uint64 value) public {
        vm.assume(value < 300 && value > 0);
        uint256 dealAmount = uint256(value) * 0.1 ether;
        vm.deal(minter, dealAmount);
        vm.startPrank(minter);
        address[] memory affiliates = new address[](0);
        mock721Partner.mint{value: dealAmount}(value, affiliates, "click123");
        assertEq(mock721Partner.getUnclaimedRewards(), 0);
    }

    function test_primaryAndSecondaryAffiliateMint(uint64 value) public {
        vm.assume(value < 300 && value > 0);
        uint256 dealAmount = uint256(value) * 0.1 ether;
        vm.deal(minter, dealAmount);
        vm.startPrank(minter);
        address[] memory affiliates = new address[](2);
        affiliates[0] = address(affiliate);
        affiliates[1] = address(affiliate2);
        mock721Partner.mint{value: dealAmount}(value, affiliates, "click123");
        assertEq(
            mock721Partner.getUnclaimedAffiliateReward(affiliate),
            (dealAmount * mock721Partner.affiliateRewardPrimary()) / mock721Partner.affiliateRewardDenominator()
        );
        assertEq(
            mock721Partner.getUnclaimedAffiliateReward(affiliate2),
            (dealAmount * mock721Partner.affiliateRewardSecondary()) / mock721Partner.affiliateRewardDenominator()
        );
    }

    function test_affiliateWithdraw(uint64 value) public {
        vm.assume(value < 300 && value > 0);
        uint256 dealAmount = uint256(value) * 0.1 ether;
        vm.deal(minter, dealAmount);
        vm.startPrank(minter);
        address[] memory affiliates = new address[](1);
        affiliates[0] = address(affiliate);
        mock721Partner.mint{value: dealAmount}(value, affiliates, "click123");
        vm.stopPrank();
        uint256 startingBalance = affiliate.balance;
        uint256 expectedRewards = mock721Partner.getUnclaimedAffiliateReward(affiliate);
        vm.startPrank(affiliate);
        mock721Partner.collectAffiliateRewards();
        uint256 endingBalance = affiliate.balance;
        assertEq(endingBalance, startingBalance + expectedRewards);
    }

    function test_withdrawMinusRewards(uint64 value) public {
        vm.assume(value < 300 && value > 0);
        uint256 dealAmount = uint256(value) * 0.1 ether;
        vm.deal(minter, dealAmount);
        vm.startPrank(minter);
        address[] memory affiliates = new address[](1);
        affiliates[0] = address(affiliate);
        mock721Partner.mint{value: dealAmount}(value, affiliates, "click123");
        vm.stopPrank();
        uint256 startingBalance = deployer.balance;
        uint256 expectedWithdrawal = address(mock721Partner).balance - mock721Partner.getUnclaimedRewards();
        vm.startPrank(deployer);
        mock721Partner.withdraw();
        uint256 endingBalance = address(deployer).balance;
        assertEq(endingBalance, startingBalance + expectedWithdrawal);
    }
}
