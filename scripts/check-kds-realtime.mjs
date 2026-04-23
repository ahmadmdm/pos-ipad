#!/usr/bin/env node

const baseURL = process.env.AMPOS_BASE_URL || "https://ampos-api.clo0.net";
const username = process.env.AMPOS_USERNAME || process.env.AMPOS_EMAIL;
const password = process.env.AMPOS_PASSWORD;
const providedBranchId = process.env.AMPOS_BRANCH_ID;
const timeoutMs = Number(process.env.AMPOS_WS_TIMEOUT_MS || 12000);

function fail(message) {
  console.error(`ERROR=${message}`);
  process.exit(1);
}

function logStep(key, value) {
  console.log(`${key}=${value}`);
}

async function parseJSONResponse(response) {
  const text = await response.text();
  try {
    return { text, json: JSON.parse(text) };
  } catch {
    return { text, json: null };
  }
}

async function login() {
  if (!username || !password) {
    fail("Set AMPOS_USERNAME or AMPOS_EMAIL and AMPOS_PASSWORD before running the script.");
  }

  const form = new URLSearchParams({
    username,
    password,
    grant_type: "password"
  });

  const response = await fetch(`${baseURL}/api/v1/auth/login`, {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body: form.toString()
  });
  const payload = await parseJSONResponse(response);

  logStep("LOGIN_STATUS", response.status);
  if (!response.ok || !payload.json?.access_token) {
    logStep("LOGIN_BODY", payload.text.slice(0, 500));
    fail("Login failed.");
  }

  return payload.json.access_token;
}

async function fetchCurrentUser(token) {
  const response = await fetch(`${baseURL}/api/v1/auth/me`, {
    headers: { authorization: `Bearer ${token}` }
  });
  const payload = await parseJSONResponse(response);

  logStep("ME_STATUS", response.status);
  if (!response.ok || !payload.json) {
    logStep("ME_BODY", payload.text.slice(0, 500));
    fail("Fetching auth/me failed.");
  }

  logStep("ROLE", payload.json.role || "");
  logStep("TENANT", payload.json.tenant_slug || "");
}

async function resolveBranchId(token) {
  if (providedBranchId) {
    logStep("BRANCH_ID", providedBranchId);
    return providedBranchId;
  }

  const response = await fetch(`${baseURL}/api/v1/branches`, {
    headers: { authorization: `Bearer ${token}` }
  });
  const payload = await parseJSONResponse(response);

  logStep("BRANCHES_STATUS", response.status);
  if (!response.ok || !Array.isArray(payload.json)) {
    logStep("BRANCHES_BODY", payload.text.slice(0, 500));
    fail("Fetching branches failed.");
  }

  const branch = payload.json.find((item) => item?.id);
  if (!branch?.id) {
    fail("No branch id was returned. Set AMPOS_BRANCH_ID explicitly.");
  }

  logStep("BRANCH_ID", branch.id);
  return branch.id;
}

async function checkKDSHTTP(token, branchId) {
  const response = await fetch(`${baseURL}/api/v1/kds/orders?branch_id=${encodeURIComponent(branchId)}`, {
    headers: { authorization: `Bearer ${token}` }
  });
  const payload = await parseJSONResponse(response);

  logStep("KDS_HTTP_STATUS", response.status);
  logStep("KDS_HTTP_BODY", payload.text.slice(0, 300));
  if (!response.ok) {
    fail("KDS HTTP endpoint failed.");
  }
}

function websocketURL(branchId, token) {
  const url = new URL(baseURL);
  url.protocol = url.protocol === "https:" ? "wss:" : "ws:";
  url.pathname = `${url.pathname.replace(/\/$/, "")}/ws/kds/${branchId}`;
  url.search = new URLSearchParams({ token }).toString();
  return url.toString();
}

async function probeFallbackStatus(branchId, token) {
  const probeURL = new URL(baseURL);
  probeURL.pathname = `${probeURL.pathname.replace(/\/$/, "")}/ws/kds/${branchId}`;
  probeURL.search = new URLSearchParams({ token }).toString();

  try {
    const response = await fetch(probeURL, { method: "GET" });
    const body = await response.text();
    logStep("WS_HTTP_PROBE_STATUS", response.status);
    logStep("WS_HTTP_PROBE_BODY", body.slice(0, 300));
  } catch (error) {
    logStep("WS_HTTP_PROBE_ERROR", error?.message || String(error));
  }
}

async function openWebSocket(branchId, token) {
  const url = websocketURL(branchId, token);
  logStep("WS_URL", url.replace(token, "<token>"));

  await new Promise((resolve, reject) => {
    const socket = new WebSocket(url);
    let settled = false;

    const finish = (callback) => (value) => {
      if (settled) {
        return;
      }
      settled = true;
      try {
        socket.close();
      } catch {
        // Ignore close failures during smoke testing.
      }
      callback(value);
    };

    const resolveOnce = finish(resolve);
    const rejectOnce = finish(reject);

    const timer = setTimeout(() => {
      rejectOnce(new Error("timeout waiting for websocket open/message"));
    }, timeoutMs);

    socket.addEventListener("open", () => {
      clearTimeout(timer);
      logStep("WS_OPEN", 1);
      resolveOnce();
    });

    socket.addEventListener("message", (event) => {
      clearTimeout(timer);
      const data = typeof event.data === "string" ? event.data : "[binary]";
      logStep("WS_MESSAGE", data.slice(0, 300));
      resolveOnce();
    });

    socket.addEventListener("error", (event) => {
      clearTimeout(timer);
      const message = event?.message || event?.error?.message || "websocket error";
      logStep("WS_ERROR", message);
      rejectOnce(new Error(message));
    });

    socket.addEventListener("close", (event) => {
      if (settled) {
        return;
      }
      clearTimeout(timer);
      logStep("WS_CLOSE_CODE", event.code);
      logStep("WS_CLOSE_REASON", event.reason || "");
      rejectOnce(new Error(`closed before open: ${event.code} ${event.reason || ""}`));
    });
  });

  logStep("WS_RESULT", "SUCCESS");
}

async function main() {
  logStep("BASE_URL", baseURL);
  const token = await login();
  await fetchCurrentUser(token);
  const branchId = await resolveBranchId(token);
  await checkKDSHTTP(token, branchId);

  try {
    await openWebSocket(branchId, token);
  } catch (error) {
    logStep("WS_RESULT", "FAIL");
    logStep("WS_FAILURE", error?.message || String(error));
    await probeFallbackStatus(branchId, token);
    process.exit(1);
  }
}

main().catch((error) => {
  console.error(error?.stack || String(error));
  process.exit(1);
});