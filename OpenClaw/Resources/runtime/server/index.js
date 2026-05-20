const fs = require("fs");
const http = require("http");
const path = require("path");
const crypto = require("crypto");

const args = Object.fromEntries(
  process.argv.slice(2).map((arg) => {
    const [key, ...rest] = arg.replace(/^--/, "").split("=");
    return [key, rest.join("=")];
  })
);

const host = args.host || process.env.OPENCLAW_HOST || "127.0.0.1";
const port = Number(args.port || process.env.OPENCLAW_PORT || 7842);
const dataDir = args["data-dir"] || process.env.OPENCLAW_DATA_DIR || path.join(process.env.HOME || ".", "Library", "Application Support", "OpenClaw");
const tokenFile = args["auth-token-file"] || process.env.OPENCLAW_AUTH_TOKEN_FILE || path.join(dataDir, "auth_token");
const corsOrigin = process.env.OPENCLAW_CORS_ORIGIN || `http://localhost:${port}`;

function readToken() {
  if (process.env.OPENCLAW_AUTH_TOKEN) return process.env.OPENCLAW_AUTH_TOKEN.trim();
  try {
    return fs.readFileSync(tokenFile, "utf8").trim();
  } catch (_) {
    return "";
  }
}

const token = readToken();

function send(response, status, body, headers = {}) {
  response.writeHead(status, {
    "content-type": headers["content-type"] || "application/json; charset=utf-8",
    "cache-control": "no-store",
    "x-content-type-options": "nosniff",
    "referrer-policy": "no-referrer",
    ...headers,
  });
  response.end(body);
}

function parseCookies(header) {
  return Object.fromEntries(
    String(header || "")
      .split(";")
      .map((part) => part.trim().split("="))
      .filter(([key, value]) => key && value)
      .map(([key, value]) => [key, decodeURIComponent(value)])
  );
}

function constantTimeEquals(a, b) {
  const left = Buffer.from(String(a || ""));
  const right = Buffer.from(String(b || ""));
  if (left.length !== right.length) return false;
  return crypto.timingSafeEqual(left, right);
}

function providedToken(request, url) {
  const authHeader = request.headers.authorization || "";
  const bearer = authHeader.replace(/^Bearer\s+/i, "");
  const cookies = parseCookies(request.headers.cookie);
  return url.searchParams.get("token") || bearer || cookies.openclaw_token || "";
}

function isAuthorized(request, url) {
  if (!token) return false;
  return constantTimeEquals(providedToken(request, url), token);
}

function withCors(request, response) {
  const origin = request.headers.origin;
  if (origin === corsOrigin || origin === `http://127.0.0.1:${port}` || origin === `http://localhost:${port}`) {
    response.setHeader("access-control-allow-origin", origin);
    response.setHeader("vary", "Origin");
    response.setHeader("access-control-allow-headers", "authorization,content-type");
    response.setHeader("access-control-allow-methods", "GET,POST,OPTIONS");
  }
}

function html() {
  return `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>OpenClaw</title>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; margin: 40px; color: #111827; background: #f8fafc; }
    main { max-width: 760px; margin: auto; background: white; border: 1px solid #e5e7eb; border-radius: 18px; padding: 28px; box-shadow: 0 20px 60px rgba(15,23,42,.08); }
    h1 { margin: 0 0 8px; }
    code { background: #f1f5f9; padding: 2px 6px; border-radius: 6px; }
    .ok { color: #047857; font-weight: 700; }
    .warn { color: #92400e; }
  </style>
</head>
<body>
  <main>
    <h1>OpenClaw local runtime</h1>
    <p class="ok">Launcher connection is working.</p>
    <p>This is only a launcher smoke-test runtime. It is not the real OpenClaw server UI.</p>
    <p class="warn">Open the macOS setup assistant and install the real OpenClaw runtime before testing the product workflow.</p>
    <p>Data directory: <code>${dataDir.replace(/</g, "&lt;")}</code></p>
  </main>
</body>
</html>`;
}

const server = http.createServer((request, response) => {
  const url = new URL(request.url, `http://${host}:${port}`);
  withCors(request, response);

  if (request.method === "OPTIONS") {
    response.writeHead(204);
    response.end();
    return;
  }

  if (url.pathname === "/health") {
    if (!isAuthorized(request, url)) {
      send(response, 401, JSON.stringify({ ok: false, error: "Unauthorized" }));
      return;
    }
    send(response, 200, JSON.stringify({ ok: true, host, port, runtime: "fallback" }));
    return;
  }

  if (!isAuthorized(request, url)) {
    send(response, 401, JSON.stringify({ error: "Unauthorized" }));
    return;
  }

  if (url.searchParams.has("token")) {
    response.writeHead(302, {
      "set-cookie": `openclaw_token=${encodeURIComponent(token)}; Path=/; HttpOnly; SameSite=Strict`,
      location: "/",
      "cache-control": "no-store",
      "referrer-policy": "no-referrer",
    });
    response.end();
    return;
  }

  send(response, 200, html(), { "content-type": "text/html; charset=utf-8" });
});

server.on("error", (error) => {
  console.error(`OPENCLAW_SERVER_ERROR:${error.message}`);
  process.exitCode = 1;
});

server.listen(port, host, () => {
  console.log(`LISTENING_ON:${port}`);
});

function shutdown(signal) {
  console.log(`OPENCLAW_SHUTDOWN:${signal}`);
  server.close(() => process.exit(0));
  setTimeout(() => process.exit(0), 5000).unref();
}

process.on("SIGTERM", () => shutdown("SIGTERM"));
process.on("SIGINT", () => shutdown("SIGINT"));
process.on("SIGHUP", () => shutdown("SIGHUP"));

process.on("uncaughtException", (error) => {
  console.error(`OPENCLAW_UNCAUGHT:${error.stack || error.message}`);
  process.exit(1);
});
process.on("unhandledRejection", (reason) => {
  console.error(`OPENCLAW_UNHANDLED_REJECTION:${reason && reason.stack ? reason.stack : String(reason)}`);
});

// Detect parent crash: when the macOS launcher dies without calling SIGTERM,
// the kernel reparents this process to launchd (pid 1). Watching ppid catches that case.
const originalParentPid = process.ppid;
const parentWatcher = setInterval(() => {
  if (process.ppid !== originalParentPid) {
    console.log(`OPENCLAW_PARENT_LOST:${originalParentPid}->${process.ppid}`);
    shutdown("PARENT_LOST");
  }
}, 2000);
parentWatcher.unref();
