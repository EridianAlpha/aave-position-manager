// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {AavePMTestSetup} from "test/unit/AavePMTestSetupTest.t.sol";

import {AavePM} from "src/AavePM.sol";
import {ERC1967Utils} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";
import {InvalidUpgrade} from "test/testHelperContracts/InvalidUpgrade.sol";
import {AavePMUpgradeExample} from "test/testHelperContracts/AavePMUpgradeExample.sol";

// ================================================================
// │                    CONTRACT UPGRADE TESTS                    │
// ================================================================
contract AavePMContractUpgradeTests is AavePMTestSetup {
    function test_UpgradeV1ToV2() public {
        // Deploy new contract
        AavePMUpgradeExample aavePMUpgradeExample = new AavePMUpgradeExample();

        // Check version before upgrade
        assertEq(keccak256(abi.encodePacked(aavePM.getVersion())), keccak256(abi.encodePacked(INITIAL_VERSION)));

        // Upgrade
        vm.prank(owner1);
        aavePM.upgradeToAndCall(address(aavePMUpgradeExample), "");
        assertEq(keccak256(abi.encodePacked(aavePM.getVersion())), keccak256(abi.encodePacked(UPGRADE_EXAMPLE_VERSION)));
    }

    function test_DowngradeV2ToV1() public {
        // Deploy V1 and V2 implementation contract
        AavePM aavePMImplementationV1 = new AavePM();
        AavePMUpgradeExample aavePMUpgradeExample = new AavePMUpgradeExample();

        // Upgrade
        vm.prank(owner1);
        aavePM.upgradeToAndCall(address(aavePMUpgradeExample), "");

        // Check version before downgrade
        assertEq(keccak256(abi.encodePacked(aavePM.getVersion())), keccak256(abi.encodePacked(UPGRADE_EXAMPLE_VERSION)));

        // Downgrade
        vm.prank(owner1);
        aavePM.upgradeToAndCall(address(aavePMImplementationV1), "");
        assertEq(keccak256(abi.encodePacked(aavePM.getVersion())), keccak256(abi.encodePacked(INITIAL_VERSION)));
    }

    function test_InvalidUpgrade() public {
        // Deploy InvalidUpgrade contract
        InvalidUpgrade invalidUpgrade = new InvalidUpgrade();

        // Check version of the invalid contract before upgrade
        assertEq(invalidUpgrade.getVersion(), "INVALID_UPGRADE_VERSION");

        bytes memory encodedRevert_ERC1967InvalidImplementation =
            abi.encodeWithSelector(ERC1967Utils.ERC1967InvalidImplementation.selector, address(invalidUpgrade));

        // Check revert on upgrade
        vm.expectRevert(encodedRevert_ERC1967InvalidImplementation);
        vm.prank(owner1);
        aavePM.upgradeToAndCall(address(invalidUpgrade), "");
    }
}
