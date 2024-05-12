// // SPDX-License-Identifier: MIT

// pragma solidity 0.8.19;

// import {StableWanCoin} from "../../src/StableWanCoin.sol";
// import {Test, console} from "forge-std/Test.sol";
// import {StdCheats} from "forge-std/StdCheats.sol";

// contract DecentralizedStablecoinTest is StdCheats, Test {
//     StableWanCoin sw;

//     function setUp() public {
//         sw = new StableWanCoin();
//     }

//     function testMustMintMoreThanZero() public {
//         vm.prank(sw.owner());
//         vm.expectRevert();
//         sw.mint(address(this), 0);
//     }

//     function testMustBurnMoreThanZero() public {
//         vm.startPrank(sw.owner());
//         sw.mint(address(this), 100);
//         vm.expectRevert();
//         sw.burn(0);
//         vm.stopPrank();
//     }

//     function testCantBurnMoreThanYouHave() public {
//         vm.startPrank(sw.owner());
//         sw.mint(address(this), 100);
//         vm.expectRevert();
//         sw.burn(101);
//         vm.stopPrank();
//     }

//     function testCantMintToZeroAddress() public {
//         vm.startPrank(sw.owner());
//         vm.expectRevert();
//         sw.mint(address(0), 100);
//         vm.stopPrank();
//     }
// }
