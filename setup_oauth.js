#!/usr/bin/env node

/**
 * MMM-NextcloudPhotos OAuth2 Setup Script
 *
 * Egyszeri futtatás az OAuth2 Authorization Code flow-hoz.
 * Elindít egy lokális HTTP szervert, megnyitja a böngészőt a Nextcloud login oldalra,
 * fogadja a callback-et, és elmenti a tokeneket.
 *
 * Használat:
 *   node setup_oauth.js \
 *     --nextcloudUrl https://cloud.example.com \
 *     --clientId <client-id> \
 *     --clientSecret <client-secret> \
 *     --username <nextcloud-username>
 */

const http = require("http");
const crypto = require("crypto");
const fs = require("fs");
const path = require("path");
const { exec } = require("child_process");
const axios = require("axios");

// HTML-escape to prevent XSS in callback responses
function escapeHtml(str) {
  if (!str) return "";
  return String(str)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

// Parse command line arguments
function parseArgs() {
  const args = {};
  const argv = process.argv.slice(2);
  for (let i = 0; i < argv.length; i += 2) {
    const key = argv[i].replace(/^--/, "");
    args[key] = argv[i + 1];
  }
  return args;
}

const args = parseArgs();

const NEXTCLOUD_URL = (args.nextcloudUrl || "").replace(/\/+$/, "");
const CLIENT_ID = args.clientId;
const CLIENT_SECRET = args.clientSecret;
const USERNAME = args.username || "";
const CALLBACK_PORT = parseInt(args.port, 10) || 9876;
const CALLBACK_HOST = args.host || "localhost";
const REDIRECT_URI = `http://${CALLBACK_HOST}:${CALLBACK_PORT}/callback`;
const TOKEN_FILE = path.join(__dirname, "tokens.json");

if (!NEXTCLOUD_URL || !CLIENT_ID || !CLIENT_SECRET) {
  console.error("Hiányzó paraméterek!\n");
  console.error("Használat:");
  console.error("  node setup_oauth.js \\");
  console.error("    --nextcloudUrl https://cloud.example.com \\");
  console.error("    --clientId <client-id> \\");
  console.error("    --clientSecret <client-secret> \\");
  console.error("    --username <nextcloud-username>  (opcionális, de ajánlott)");
  console.error("    --host 192.168.1.100  (opcionális, alapértelmezett: localhost)");
  console.error("    --port 9876  (opcionális, alapértelmezett: 9876)");
  process.exit(1);
}

// Generate and store state for CSRF protection
const STATE = crypto.randomBytes(16).toString("hex");

// Build authorization URL (Nextcloud built-in OAuth2)
const authUrl = new URL(`${NEXTCLOUD_URL}/index.php/apps/oauth2/authorize`);
authUrl.searchParams.set("response_type", "code");
authUrl.searchParams.set("client_id", CLIENT_ID);
authUrl.searchParams.set("redirect_uri", REDIRECT_URI);
authUrl.searchParams.set("state", STATE);

// Open browser cross-platform
function openBrowser(targetUrl) {
  const platform = process.platform;
  let cmd;
  if (platform === "win32") {
    cmd = `start "" "${targetUrl}"`;
  } else if (platform === "darwin") {
    cmd = `open "${targetUrl}"`;
  } else {
    cmd = `xdg-open "${targetUrl}"`;
  }
  exec(cmd, (err) => {
    if (err) {
      console.log("\nNem sikerült automatikusan megnyitni a böngészőt.");
      console.log("Nyisd meg manuálisan ezt az URL-t:\n");
      console.log(targetUrl);
    }
  });
}

// Exchange authorization code for tokens (Nextcloud OAuth2 token endpoint)
async function exchangeCodeForTokens(code) {
  const tokenUrl = `${NEXTCLOUD_URL}/index.php/apps/oauth2/api/v1/token`;

  const params = new URLSearchParams();
  params.append("grant_type", "authorization_code");
  params.append("code", code);
  params.append("redirect_uri", REDIRECT_URI);
  params.append("client_id", CLIENT_ID);
  params.append("client_secret", CLIENT_SECRET);

  const response = await axios.post(tokenUrl, params.toString(), {
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    timeout: 30000,
  });

  return response.data;
}

// Save tokens to file
function saveTokens(tokenData) {
  const tokens = {
    access_token: tokenData.access_token,
    refresh_token: tokenData.refresh_token,
    token_type: tokenData.token_type,
    expires_in: tokenData.expires_in || 3600,
    expires_at: Date.now() + (tokenData.expires_in || 3600) * 1000,
    nextcloud_url: NEXTCLOUD_URL,
    username: USERNAME,
    client_id: CLIENT_ID,
    client_secret: CLIENT_SECRET,
  };

  fs.writeFileSync(TOKEN_FILE, JSON.stringify(tokens, null, 2), "utf8");
  // Restrict file permissions (non-Windows)
  if (process.platform !== "win32") {
    fs.chmodSync(TOKEN_FILE, 0o600);
  }
  return tokens;
}

// Start local HTTP server to receive callback
const server = http.createServer(async (req, res) => {
  const parsedUrl = new URL(req.url, `http://localhost:${CALLBACK_PORT}`);

  if (parsedUrl.pathname === "/callback") {
    const code = parsedUrl.searchParams.get("code");
    const error = parsedUrl.searchParams.get("error");
    const returnedState = parsedUrl.searchParams.get("state");

    // Validate OAuth2 state parameter (CSRF protection)
    if (!returnedState || returnedState !== STATE) {
      console.error("\nCSRF state debug:");
      console.error("  Elvárt:  ", STATE);
      console.error("  Kapott:  ", returnedState);
      console.error("  Teljes URL:", req.url);

      // If Nextcloud doesn't return state, warn but allow (setup is localhost-only)
      if (!returnedState) {
        console.warn("\n[FIGYELEM] A Nextcloud nem küldte vissza a state paramétert.");
        console.warn("  Folytatás state validálás nélkül (localhost-only setup).\n");
      } else {
        res.writeHead(403, { "Content-Type": "text/html; charset=utf-8" });
        res.end(`
          <html><body style="font-family:sans-serif;text-align:center;padding:50px;">
            <h1 style="color:red;">CSRF hiba!</h1>
            <p>Az OAuth2 state parameter nem egyezik. A kérés elutasítva.</p>
          </body></html>
        `);
        return;
      }
    }

    if (error) {
      const errorDesc = escapeHtml(parsedUrl.searchParams.get("error_description"));
      res.writeHead(400, { "Content-Type": "text/html; charset=utf-8" });
      res.end(`
        <html><body style="font-family:sans-serif;text-align:center;padding:50px;">
          <h1 style="color:red;">Hiba!</h1>
          <p>Az autentikáció sikertelen: ${escapeHtml(error)}</p>
          <p>${errorDesc}</p>
        </body></html>
      `);
      console.error(`\nHiba: ${error} - ${parsedUrl.searchParams.get("error_description")}`);
      server.close();
      process.exit(1);
    }

    if (!code) {
      res.writeHead(400, { "Content-Type": "text/html; charset=utf-8" });
      res.end(`
        <html><body style="font-family:sans-serif;text-align:center;padding:50px;">
          <h1 style="color:red;">Hiba!</h1>
          <p>Nem érkezett authorization code.</p>
        </body></html>
      `);
      return;
    }

    try {
      console.log("\nAuthorization code megérkezett. Token csere folyamatban...");
      const tokenData = await exchangeCodeForTokens(code);
      const saved = saveTokens(tokenData);

      res.writeHead(200, { "Content-Type": "text/html; charset=utf-8" });
      res.end(`
        <html><body style="font-family:sans-serif;text-align:center;padding:50px;">
          <h1 style="color:green;">Sikeres bejelentkezés!</h1>
          <p>A tokenek elmentve: <code>tokens.json</code></p>
          <p>Ez az ablak bezárható.</p>
          <p>A MagicMirror modul most már használhatja a Nextcloud fiókot.</p>
        </body></html>
      `);

      console.log("\nTokenek sikeresen elmentve!");
      console.log(`  Access token lejárat: ${new Date(saved.expires_at).toLocaleString()}`);
      console.log(`  Token fájl: ${TOKEN_FILE}`);
      console.log("\nA setup kész. Indítsd újra a MagicMirror-t!");

      setTimeout(() => {
        server.close();
        process.exit(0);
      }, 1000);
    } catch (err) {
      res.writeHead(500, { "Content-Type": "text/html; charset=utf-8" });
      res.end(`
        <html><body style="font-family:sans-serif;text-align:center;padding:50px;">
          <h1 style="color:red;">Token csere hiba!</h1>
          <p>${escapeHtml(err.message)}</p>
        </body></html>
      `);
      console.error("\nToken csere hiba:", err.response?.data || err.message);
      server.close();
      process.exit(1);
    }
  } else {
    res.writeHead(404);
    res.end("Not found");
  }
});

server.listen(CALLBACK_PORT, "0.0.0.0", () => {
  console.log("=".repeat(60));
  console.log("  MMM-NextcloudPhotos OAuth2 Setup (Nextcloud)");
  console.log("=".repeat(60));
  console.log(`\nCallback szerver elindult: http://${CALLBACK_HOST}:${CALLBACK_PORT}`);
  console.log(`Redirect URI: ${REDIRECT_URI}`);
  console.log("\n--- Nyisd meg ezt az URL-t a böngésződben: ---\n");
  console.log(authUrl.toString());
  console.log("\n" + "-".repeat(60) + "\n");

  openBrowser(authUrl.toString());
});
