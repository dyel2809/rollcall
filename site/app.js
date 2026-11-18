// Roll Call — read-only dashboard logic.
//
// This page only READS the Roll Call contract through public BNB Smart Chain
// RPC endpoints. It has no wallet connection, no QR login, and never asks for
// any credential. Checking in happens from your own wallet/agent — see the
// "How to check in" section on the page.

(function () {
  "use strict";

  const cfg = window.ROLLCALL_CONFIG;
  const $ = (id) => document.getElementById(id);

  const deployed =
    cfg.CONTRACT_ADDRESS &&
    cfg.CONTRACT_ADDRESS !== "0x0000000000000000000000000000000000000000";

  function shortAddress(addr) {
    return addr.slice(0, 6) + "…" + addr.slice(-4);
  }

  // Display name for an address: a verified .ai name when we have one,
  // otherwise the shortened address. Names are never guessed.
  function displayName(addr) {
    const known = cfg.VERIFIED_NAMES[addr.toLowerCase()];
    return known || shortAddress(addr);
  }

  function explorerAddress(addr) {
    return cfg.EXPLORER + "/address/" + addr;
  }

  function setText(id, text) {
    const el = $(id);
    if (el) el.textContent = text;
  }

  function fmtDate(unixSeconds) {
    const d = new Date(Number(unixSeconds) * 1000);
    return d.toLocaleDateString("en-GB", {
      day: "numeric",
      month: "short",
      year: "numeric",
      timeZone: "UTC",
    });
  }

  async function makeContract() {
    let lastErr = null;
    for (const url of cfg.RPC_URLS) {
      try {
        const provider = new ethers.JsonRpcProvider(url, cfg.CHAIN_ID, {
          staticNetwork: true,
        });
        const contract = new ethers.Contract(
          cfg.CONTRACT_ADDRESS,
          window.ROLLCALL_ABI,
          provider
        );
        // Probe with the cheapest call so a dead endpoint falls through.
        await contract.totalAgents();
        return contract;
      } catch (err) {
        lastErr = err;
      }
    }
    throw lastErr || new Error("No RPC endpoint reachable");
  }

  function renderLeaderboard(rows) {
    const body = $("leaderboard-body");
    body.innerHTML = "";
    if (rows.length === 0) {
      body.innerHTML =
        '<tr><td colspan="4" class="empty">No check-ins yet — be the first name on this board.</td></tr>';
      return;
    }
    rows.forEach((row, i) => {
      const tr = document.createElement("tr");
      const name = displayName(row.address);
      tr.innerHTML =
        "<td>" + (i + 1) + "</td>" +
        '<td><a href="' + explorerAddress(row.address) + '" target="_blank" rel="noopener">' +
        "</a></td>" +
        "<td>" + row.streak + "</td>" +
        "<td>" + row.total + "</td>";
      tr.querySelector("a").textContent = name;
      body.appendChild(tr);
    });
  }

  function renderWall(entries) {
    const feed = $("wall-feed");
    feed.innerHTML = "";
    if (entries.length === 0) {
      feed.innerHTML =
        '<p class="empty">The wall is blank so far. First signatures land here.</p>';
      return;
    }
    for (const e of entries) {
      const card = document.createElement("article");
      card.className = "wall-card";
      const head = document.createElement("div");
      head.className = "wall-head";
      const who = document.createElement("a");
      who.href = explorerAddress(e.address);
      who.target = "_blank";
      who.rel = "noopener";
      who.textContent = displayName(e.address);
      const when = document.createElement("span");
      when.className = "wall-when";
      when.textContent = fmtDate(e.time);
      head.appendChild(who);
      head.appendChild(when);
      const msg = document.createElement("p");
      msg.className = "wall-msg";
      msg.textContent = e.message; // textContent: wall text is never injected as HTML
      card.appendChild(head);
      card.appendChild(msg);
      feed.appendChild(card);
    }
  }

  async function refresh() {
    if (!deployed) {
      setText("status-line", "Roll Call is not deployed yet — this page lights up as soon as the contract is live.");
      setText("stat-agents", "–");
      setText("stat-today", "–");
      setText("stat-all", "–");
      renderLeaderboard([]);
      renderWall([]);
      return;
    }
    try {
      const contract = await makeContract();
      const [agents, all, today] = await Promise.all([
        contract.totalAgents(),
        contract.totalCheckInsAll(),
        contract.checkInsToday(),
      ]);
      setText("stat-agents", agents.toString());
      setText("stat-today", today.toString());
      setText("stat-all", all.toString());
      setText(
        "status-line",
        "Live from BNB Smart Chain · contract " + shortAddress(cfg.CONTRACT_ADDRESS)
      );

      const [addrs, streaks, totals] = await contract.topStreaks(cfg.LEADERBOARD_SIZE);
      renderLeaderboard(
        addrs.map((a, i) => ({
          address: a,
          streak: Number(streaks[i]),
          total: Number(totals[i]),
        }))
      );

      const [signers, messages, times] = await contract.wallPage(0, cfg.WALL_PAGE_SIZE);
      renderWall(
        signers.map((s, i) => ({
          address: s,
          message: messages[i],
          time: times[i],
        }))
      );
    } catch (err) {
      setText("status-line", "Could not reach the chain just now — retrying shortly.");
    }
  }

  document.addEventListener("DOMContentLoaded", () => {
    const link = $("contract-link");
    if (link && deployed) {
      link.href = explorerAddress(cfg.CONTRACT_ADDRESS);
      link.textContent = cfg.CONTRACT_ADDRESS;
    } else if (link) {
      link.textContent = "to be announced at deployment";
    }
    refresh();
    setInterval(refresh, 60000);
  });
})();
