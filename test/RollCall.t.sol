// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {RollCall} from "../src/RollCall.sol";
import {MockAgentID} from "./mocks/MockAgentID.sol";

contract RollCallTest is Test {
    address internal constant REGISTRY = 0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F;

    RollCall internal roll;
    MockAgentID internal registry;

    address internal alice = makeAddr("alice"); // holds "alice.ai"
    address internal bob = makeAddr("bob"); //     holds "bob.ai"
    address internal carol = makeAddr("carol"); // holds "carol.ai"
    address internal stranger = makeAddr("stranger"); // no Agent ID

    // A fixed Wednesday, 2026-11-18 12:00:00 UTC.
    uint256 internal constant T0 = 1795003200;

    function setUp() public {
        // Put the mock's code at the real registry address so RollCall's
        // hardcoded gate points at it, exactly as on mainnet.
        MockAgentID impl = new MockAgentID();
        vm.etch(REGISTRY, address(impl).code);
        registry = MockAgentID(REGISTRY);

        registry.mint(alice, "alice");
        registry.mint(bob, "bob");
        registry.mint(carol, "carol");

        roll = new RollCall();
        vm.warp(T0);
    }

    // ------------------------------------------------------------ gate tests

    function test_NonHolderCannotCheckIn() public {
        vm.prank(stranger);
        vm.expectRevert(RollCall.NotAgent.selector);
        roll.checkIn();
    }

    function test_NonHolderCannotSignWall() public {
        vm.prank(stranger);
        vm.expectRevert(RollCall.NotAgent.selector);
        roll.signWall("hello");
    }

    function test_IsAgentView() public {
        assertTrue(roll.isAgent(alice));
        assertFalse(roll.isAgent(stranger));
    }

    // --------------------------------------------------------- check-in flow

    function test_HolderCheckInWorks() public {
        vm.expectEmit(true, false, false, true);
        emit RollCall.CheckedIn(alice, T0 / 1 days, 1, 1);
        vm.prank(alice);
        roll.checkIn();

        (uint32 current, uint32 longest, uint64 total, uint64 lastDay) = roll.streakOf(alice);
        assertEq(current, 1);
        assertEq(longest, 1);
        assertEq(total, 1);
        assertEq(lastDay, T0 / 1 days);

        assertEq(roll.totalAgents(), 1);
        assertEq(roll.totalCheckInsAll(), 1);
        assertEq(roll.checkInsToday(), 1);
        assertEq(roll.checkInsOnDay(T0 / 1 days), 1);
        assertEq(roll.agentsCount(), 1);
    }

    function test_SecondCheckInSameDayReverts() public {
        vm.prank(alice);
        roll.checkIn();

        // Later the same UTC day still reverts.
        vm.warp(T0 + 6 hours);
        vm.prank(alice);
        vm.expectRevert(RollCall.AlreadyCheckedIn.selector);
        roll.checkIn();
    }

    function test_StreakIncrementsOnConsecutiveDays() public {
        vm.prank(alice);
        roll.checkIn();

        vm.warp(T0 + 1 days);
        vm.prank(alice);
        roll.checkIn();

        vm.warp(T0 + 2 days);
        vm.prank(alice);
        roll.checkIn();

        (uint32 current, uint32 longest, uint64 total,) = roll.streakOf(alice);
        assertEq(current, 3);
        assertEq(longest, 3);
        assertEq(total, 3);
        assertEq(roll.checkInsToday(), 1);
    }

    function test_StreakResetsAfterGapButLongestIsKept() public {
        vm.prank(alice);
        roll.checkIn();
        vm.warp(T0 + 1 days);
        vm.prank(alice);
        roll.checkIn();

        // Skip two days, then check in again.
        vm.warp(T0 + 4 days);
        vm.prank(alice);
        roll.checkIn();

        (uint32 current, uint32 longest, uint64 total,) = roll.streakOf(alice);
        assertEq(current, 1, "current streak restarts at 1 after a gap");
        assertEq(longest, 2, "longest streak is preserved");
        assertEq(total, 3);
    }

    function test_MidnightBoundaryCountsAsNewDay() public {
        uint256 dayStart = (T0 / 1 days) * 1 days;
        vm.warp(dayStart + 23 hours + 59 minutes);
        vm.prank(alice);
        roll.checkIn();

        vm.warp(dayStart + 1 days + 1 minutes);
        vm.prank(alice);
        roll.checkIn(); // must not revert: it is a new UTC day

        (uint32 current,, uint64 total,) = roll.streakOf(alice);
        assertEq(current, 2);
        assertEq(total, 2);
    }

    // --------------------------------------------------------------- the wall

    function test_WallSignAndReplace() public {
        vm.prank(alice);
        roll.signWall("first message");

        (string memory msg1, uint64 signedAt1, bool exists1) = roll.wallOf(alice);
        assertEq(msg1, "first message");
        assertEq(signedAt1, T0);
        assertTrue(exists1);
        assertEq(roll.wallSignersCount(), 1);
        assertEq(roll.totalAgents(), 1, "signing the wall also registers the agent");

        vm.warp(T0 + 2 hours);
        vm.expectEmit(true, false, false, true);
        emit RollCall.WallSigned(alice, "second message");
        vm.prank(alice);
        roll.signWall("second message");

        (string memory msg2, uint64 signedAt2,) = roll.wallOf(alice);
        assertEq(msg2, "second message");
        assertEq(signedAt2, T0 + 2 hours);
        assertEq(roll.wallSignersCount(), 1, "re-signing must not duplicate the signer");
        assertEq(roll.totalAgents(), 1);
    }

    function test_WallRejectsEmptyAndOverlong() public {
        vm.prank(alice);
        vm.expectRevert(RollCall.EmptyMessage.selector);
        roll.signWall("");

        string memory tooLong = new string(561);
        vm.prank(alice);
        vm.expectRevert(RollCall.MessageTooLong.selector);
        roll.signWall(tooLong);

        // Exactly at the cap is fine.
        string memory atCap = new string(560);
        vm.prank(alice);
        roll.signWall(atCap);
        (, , bool exists) = roll.wallOf(alice);
        assertTrue(exists);
    }

    function test_WallPageIsNewestSignerFirst() public {
        vm.prank(alice);
        roll.signWall("from alice");
        vm.prank(bob);
        roll.signWall("from bob");
        vm.prank(carol);
        roll.signWall("from carol");

        (address[] memory signers, string[] memory messages,) = roll.wallPage(0, 2);
        assertEq(signers.length, 2);
        assertEq(signers[0], carol);
        assertEq(messages[0], "from carol");
        assertEq(signers[1], bob);

        (address[] memory page2,,) = roll.wallPage(2, 2);
        assertEq(page2.length, 1);
        assertEq(page2[0], alice);

        (address[] memory empty,,) = roll.wallPage(99, 5);
        assertEq(empty.length, 0);
    }

    // ---------------------------------------------- counters and leaderboard

    function test_CountersAcrossAgents() public {
        vm.prank(alice);
        roll.checkIn();
        vm.prank(bob);
        roll.checkIn();
        vm.prank(carol);
        roll.signWall("carol was here"); // registers without a check-in

        assertEq(roll.totalAgents(), 3);
        assertEq(roll.totalCheckInsAll(), 2);
        assertEq(roll.checkInsToday(), 2);
        assertEq(roll.agentsCount(), 3);

        address[] memory page = roll.agentsPage(1, 1);
        assertEq(page.length, 1);
        assertEq(page[0], bob);

        address[] memory empty = roll.agentsPage(3, 10);
        assertEq(empty.length, 0);
    }

    function test_TopStreaksLeaderboard() public {
        // alice: 3-day streak. bob: 2-day streak. carol: 1 check-in.
        for (uint256 i = 0; i < 3; i++) {
            vm.warp(T0 + i * 1 days);
            vm.prank(alice);
            roll.checkIn();
            if (i < 2) {
                vm.prank(bob);
                roll.checkIn();
            }
            if (i == 0) {
                vm.prank(carol);
                roll.checkIn();
            }
        }

        (address[] memory addrs, uint32[] memory streaks, uint64[] memory totals) = roll.topStreaks(3);
        assertEq(addrs.length, 3);
        assertEq(addrs[0], alice);
        assertEq(streaks[0], 3);
        assertEq(totals[0], 3);
        assertEq(addrs[1], bob);
        assertEq(streaks[1], 2);
        assertEq(addrs[2], carol);
        assertEq(streaks[2], 1);

        (address[] memory top1,,) = roll.topStreaks(1);
        assertEq(top1.length, 1);
        assertEq(top1[0], alice);

        (address[] memory none,,) = roll.topStreaks(0);
        assertEq(none.length, 0);
    }

    function test_RegistryAddressIsTheRealOne() public {
        assertEq(address(roll.AGENT_ID_REGISTRY()), REGISTRY);
    }
}
