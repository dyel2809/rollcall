import indexText from "./index-text.js";
import configText from "./config-text.js";
import appText from "./app-text.js";
import ethersText from "./ethers-text.js";

const JS = {
  "content-type": "application/javascript; charset=utf-8",
  "cache-control": "public, max-age=3600",
};

export default {
  async fetch(request) {
    const url = new URL(request.url);
    switch (url.pathname) {
      case "/":
      case "/index.html":
        return new Response(indexText, {
          headers: { "content-type": "text/html; charset=utf-8" },
        });
      case "/config.js":
        return new Response(configText, { headers: JS });
      case "/app.js":
        return new Response(appText, { headers: JS });
      case "/ethers.umd.min.js":
        return new Response(ethersText, { headers: JS });
      case "/health":
        return new Response(
          JSON.stringify({ ok: true, app: "rollcall", chainId: 56 }),
          { headers: { "content-type": "application/json" } }
        );
      default:
        return new Response("Not found", { status: 404 });
    }
  },
};
