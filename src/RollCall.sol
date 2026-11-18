// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @dev Minimal interface for the SPACE ID Agent ID registry on BNB Smart Chain.
///      The registry is a soulbound ERC-721: holding a balance greater than zero
///      means the address owns an Agent ID (a `name.ai` identity).
interface IAgentIDRegistry {
    function balanceOf(address owner) external view returns (uint256);
    function ownerOf(uint256 tokenId) external view returns (address);
}

/// @title RollCall
/// @notice A daily check-in and public wall for Agent ID holders on BNB Smart Chain.
///
///         Roll Call is a small ritual layer for the agent era: if your wallet holds
///         an Agent ID, you can check in once per UTC day to build a streak, and you
///         can sign the public wall with one short message. Your Agent ID is your
///         account — there is no separate registration, no token, and nothing to buy.
///
/// @dev    PERMISSIONS: this contract is deliberately ownerless. It has no owner,
///         no admin role, no pause switch, no mint, no withdraw function, and no
///         upgrade path. The Agent ID registry address is a hardcoded constant and
///         can never be changed. Once deployed, nobody — including the deployer —
///         can alter its behaviour or touch anything through it. The contract never
///         holds funds; both entry points are non-payable.
///
///         Roll Call is an independent community project. It is not affiliated with,
///         endorsed by, or connected to Binance, BNB Chain, or SPACE ID. It only
///         reads the public Agent ID registry as its entry gate, the same registry
///         any project can read.
contract RollCall {
    // ---------------------------------------------------------------- errors

    error NotAgent();
    error AlreadyCheckedIn();
    error EmptyMessage();
    error MessageTooLong();

    // ------------------------------------------------------------- constants

    /// @notice The SPACE ID Agent ID registry on BNB Smart Chain (chain id 56).
    ///         Hardcoded by design: the gate can never be repointed.
    IAgentIDRegistry public constant AGENT_ID_REGISTRY =
        IAgentIDRegistry(0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F);

    /// @notice Wall messages are capped at 560 bytes, which holds roughly
    ///         140 characters even for multi-byte scripts.
    uint256 public constant MAX_MESSAGE_BYTES = 560;

    // ---------------------------------------------------------------- events

    event Registered(address indexed agent);
    event CheckedIn(address indexed agent, uint256 day, uint32 currentStreak, uint64 totalCheckIns);
    event WallSigned(address indexed agent, string message);

    // ----------------------------------------------------------------- state

    struct AgentStats {
        uint32 currentStreak;
        uint32 longestStreak;
        uint64 totalCheckIns;
        uint64 lastCheckInDay; // unix day number (timestamp / 86400), UTC
        bool registered;
    }

    struct WallEntry {
        string message;
        uint64 signedAt; // unix timestamp of the latest signing
        bool exists;
    }

    mapping(address => AgentStats) private _stats;
    mapping(address => WallEntry) private _wall;

    /// @dev Every address that has ever checked in or signed the wall, in
    ///      first-interaction order. Backs the paged getters and leaderboard.
    address[] private _agents;

    /// @dev Every address that has signed the wall, in first-sign order.
    address[] private _wallSigners;

    /// @notice Number of unique Agent ID addresses that have ever interacted.
    uint256 public totalAgents;

    /// @notice All-time number of check-ins across every agent.
    uint256 public totalCheckInsAll;

    /// @notice Check-ins per UTC day: day number => count.
    mapping(uint256 => uint256) public checkInsOnDay;

    // -------------------------------------------------------------- internal

    modifier onlyAgent() {
        if (AGENT_ID_REGISTRY.balanceOf(msg.sender) == 0) revert NotAgent();
        _;
    }

    function _currentDay() internal view returns (uint256) {
        return block.timestamp / 1 days;
    }

    function _register(address agent) internal {
        AgentStats storage s = _stats[agent];
        if (!s.registered) {
            s.registered = true;
            _agents.push(agent);
            totalAgents += 1;
            emit Registered(agent);
        }
    }

    // ------------------------------------------------------------ entry points

    /// @notice Check in for today. One check-in per Agent ID address per UTC day.
    ///         Checking in on consecutive days grows your streak; missing a day
    ///         restarts the current streak at 1 (your longest streak is kept).
    function checkIn() external onlyAgent {
        uint256 today = _currentDay();
        AgentStats storage s = _stats[msg.sender];

        if (s.totalCheckIns != 0 && s.lastCheckInDay == today) {
            revert AlreadyCheckedIn();
        }

        _register(msg.sender);

        if (s.totalCheckIns != 0 && s.lastCheckInDay == today - 1) {
            s.currentStreak += 1;
        } else {
            s.currentStreak = 1;
        }
        if (s.currentStreak > s.longestStreak) {
            s.longestStreak = s.currentStreak;
        }
        s.totalCheckIns += 1;
        s.lastCheckInDay = uint64(today);

        totalCheckInsAll += 1;
        checkInsOnDay[today] += 1;

        emit CheckedIn(msg.sender, today, s.currentStreak, s.totalCheckIns);
    }

    /// @notice Sign the public wall with one short message. Signing again
    ///         replaces your previous message. One active message per address.
    /// @param message 1 to 560 bytes of UTF-8 text.
    function signWall(string calldata message) external onlyAgent {
        uint256 len = bytes(message).length;
        if (len == 0) revert EmptyMessage();
        if (len > MAX_MESSAGE_BYTES) revert MessageTooLong();

        _register(msg.sender);

        WallEntry storage w = _wall[msg.sender];
        if (!w.exists) {
            w.exists = true;
            _wallSigners.push(msg.sender);
        }
        w.message = message;
        w.signedAt = uint64(block.timestamp);

        emit WallSigned(msg.sender, message);
    }

    // ------------------------------------------------------------------ views

    /// @notice True if the address currently holds an Agent ID.
    function isAgent(address account) external view returns (bool) {
        return AGENT_ID_REGISTRY.balanceOf(account) > 0;
    }

    /// @notice The current UTC day number used by the check-in logic.
    function currentDay() external view returns (uint256) {
        return _currentDay();
    }

    /// @notice Number of check-ins recorded so far today (UTC).
    function checkInsToday() external view returns (uint256) {
        return checkInsOnDay[_currentDay()];
    }

    /// @notice Streak stats for an agent:
    ///         (current streak, longest streak, total check-ins, last check-in day).
    /// @dev    The stored current streak is the streak as of the last check-in.
    ///         If the last check-in was before yesterday, the streak has lapsed
    ///         and the next check-in restarts it at 1 — read `lastDay` alongside.
    function streakOf(address agent)
        external
        view
        returns (uint32 current, uint32 longest, uint64 total, uint64 lastDay)
    {
        AgentStats storage s = _stats[agent];
        return (s.currentStreak, s.longestStreak, s.totalCheckIns, s.lastCheckInDay);
    }

    /// @notice The agent's active wall message, when it was last signed, and
    ///         whether the agent has ever signed the wall.
    function wallOf(address agent) external view returns (string memory message, uint64 signedAt, bool exists) {
        WallEntry storage w = _wall[agent];
        return (w.message, w.signedAt, w.exists);
    }

    /// @notice Number of registered agents (unique interacting addresses).
    function agentsCount() external view returns (uint256) {
        return _agents.length;
    }

    /// @notice Number of addresses that have signed the wall.
    function wallSignersCount() external view returns (uint256) {
        return _wallSigners.length;
    }

    /// @notice A page of registered agent addresses, in first-interaction order.
    ///         `limit` is clamped to the remaining entries; an out-of-range
    ///         offset returns an empty array.
    function agentsPage(uint256 offset, uint256 limit) external view returns (address[] memory page) {
        uint256 len = _agents.length;
        if (offset >= len) return new address[](0);
        uint256 end = offset + limit;
        if (end > len) end = len;
        page = new address[](end - offset);
        for (uint256 i = offset; i < end; i++) {
            page[i - offset] = _agents[i];
        }
    }

    /// @notice A page of wall entries, most recently signed first.
    /// @dev Returned arrays are parallel: signers[i] wrote messages[i] at times[i].
    function wallPage(uint256 offset, uint256 limit)
        external
        view
        returns (address[] memory signers, string[] memory messages, uint64[] memory times)
    {
        uint256 len = _wallSigners.length;
        if (offset >= len) return (new address[](0), new string[](0), new uint64[](0));
        uint256 count = limit;
        if (offset + count > len) count = len - offset;
        signers = new address[](count);
        messages = new string[](count);
        times = new uint64[](count);
        for (uint256 i = 0; i < count; i++) {
            // Walk the signer list backwards so the page starts at the newest signer.
            address signer = _wallSigners[len - 1 - (offset + i)];
            WallEntry storage w = _wall[signer];
            signers[i] = signer;
            messages[i] = w.message;
            times[i] = w.signedAt;
        }
    }

    /// @notice The top agents by longest streak (ties broken by total check-ins,
    ///         then by earlier registration). Computed over the registered-agent
    ///         list; intended for read calls, fine at community scale.
    function topStreaks(uint256 limit)
        external
        view
        returns (address[] memory addrs, uint32[] memory streaks, uint64[] memory totals)
    {
        uint256 n = _agents.length;
        if (limit > n) limit = n;
        addrs = new address[](limit);
        streaks = new uint32[](limit);
        totals = new uint64[](limit);
        if (limit == 0) return (addrs, streaks, totals);

        // Selection: repeatedly pick the best remaining agent. O(n * limit),
        // acceptable for a view function at the expected scale.
        bool[] memory picked = new bool[](n);
        for (uint256 slot = 0; slot < limit; slot++) {
            uint256 best = type(uint256).max;
            for (uint256 i = 0; i < n; i++) {
                if (picked[i]) continue;
                if (best == type(uint256).max || _ranksBefore(_agents[i], _agents[best])) {
                    best = i;
                }
            }
            picked[best] = true;
            AgentStats storage s = _stats[_agents[best]];
            addrs[slot] = _agents[best];
            streaks[slot] = s.longestStreak;
            totals[slot] = s.totalCheckIns;
        }
    }

    /// @dev True if agent `a` should rank ahead of agent `b` on the leaderboard.
    function _ranksBefore(address a, address b) internal view returns (bool) {
        AgentStats storage sa = _stats[a];
        AgentStats storage sb = _stats[b];
        if (sa.longestStreak != sb.longestStreak) return sa.longestStreak > sb.longestStreak;
        if (sa.totalCheckIns != sb.totalCheckIns) return sa.totalCheckIns > sb.totalCheckIns;
        return false; // equal: keep the earlier-registered agent ahead (stable)
    }
}
