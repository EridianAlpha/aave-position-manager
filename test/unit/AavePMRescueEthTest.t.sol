// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {AavePMTestSetup} from "test/unit/AavePMTestSetupTest.t.sol";

import {IAavePM} from "src/interfaces/IAavePM.sol";
import {InvalidOwner} from "test/testHelperContracts/InvalidOwner.sol";

// ================================================================
// │                        RESCUE ETH TESTS                      │
// ================================================================
contract AavePMRescueEthTest is AavePMTestSetup {
    uint256 balanceBefore;

    function rescueEth_SetUp() public {
        vm.prank(manager1);
        (bool callSuccess,) = address(aavePM).call{value: SEND_VALUE}("");
        require(callSuccess, "Failed to send ETH to AavePM contract");
        balanceBefore = address(aavePM).balance;
        require(balanceBefore > 0, "Balance before rescueEth is 0");
    }

    function test_RescueEth() public {
        rescueEth_SetUp();

        // Check non-managers can't call rescueEth
        vm.expectRevert(encodedRevert_AccessControlUnauthorizedAccount_Manager);
        vm.prank(attacker1);
        aavePM.rescueEth(attacker1);

        // Check rescueAddress is an owner
        vm.expectRevert(IAavePM.AavePM__AddressNotAnOwner.selector);
        vm.prank(manager1);
        aavePM.rescueEth(manager1);

        // Rescue ETH
        vm.expectEmit();
        uint256 expectedBalance = address(aavePM).balance;
        emit IAavePM.EthRescued(owner1, expectedBalance);

        vm.prank(manager1);
        aavePM.rescueEth(owner1);

        uint256 expectedRemaining = 0;
        assertEq(address(aavePM).balance, expectedRemaining);
    }

    function test_RescueEthCallFailureThrowsError() public {
        // This covers the edge case where the .call fails because the
        // receiving contract doesn't have a receive() or fallback() function.
        rescueEth_SetUp();
        vm.startPrank(owner1);

        // Deploy InvalidOwner contract.
        InvalidOwner invalidOwner = new InvalidOwner();

        // Add invalidOwner to the owner role.
        aavePM.grantRole(keccak256("OWNER_ROLE"), address(invalidOwner));

        // Attempt to rescue ETH to the invalidOwner contract, which will fail.
        vm.expectRevert(IAavePM.AavePM__RescueEthFailed.selector);
        aavePM.rescueEth(address(invalidOwner));
        vm.stopPrank();
    }
}
