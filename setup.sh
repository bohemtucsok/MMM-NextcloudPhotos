#!/bin/bash
# ============================================================
#  MMM-NextcloudPhotos - Interactive Token Setup
#  This script guides you through the Nextcloud OAuth2 login.
# ============================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SETUP_SCRIPT="$SCRIPT_DIR/setup_oauth.js"

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

echo ""
echo -e "${CYAN}============================================================${NC}"
echo -e "${CYAN}  MMM-NextcloudPhotos - Token Setup${NC}"
echo -e "${CYAN}============================================================${NC}"
echo ""
echo -e "This script connects your MagicMirror to your Nextcloud account."
echo -e "You only need to do this ${BOLD}once${NC}, after that it works automatically."
echo ""

# Checks
if [ ! -f "$SETUP_SCRIPT" ]; then
    echo -e "${RED}ERROR: Cannot find setup_oauth.js!${NC}"
    echo "Expected location: $SETUP_SCRIPT"
    exit 1
fi

if ! command -v node &> /dev/null; then
    echo -e "${RED}ERROR: Node.js is not installed!${NC}"
    echo "Install it: sudo apt install nodejs"
    exit 1
fi

# Install dependencies if missing
if [ ! -d "$SCRIPT_DIR/node_modules" ]; then
    echo -e "${YELLOW}Installing dependencies (npm install)...${NC}"
    (cd "$SCRIPT_DIR" && npm install)
    echo -e "${GREEN}Dependencies installed.${NC}"
    echo ""
fi

# Auto-detect IP address
AUTO_IP=$(hostname -I 2>/dev/null | awk '{print $1}')

# ─── Collect information ─────────────────────────────────

echo -e "${YELLOW}── 1. Nextcloud Server URL ──${NC}"
echo "Your Nextcloud server address (e.g. https://cloud.example.com)"
echo ""
read -p "Nextcloud URL: " NC_URL
echo ""

if [ -z "$NC_URL" ]; then
    echo -e "${RED}ERROR: Nextcloud URL is required!${NC}"
    exit 1
fi

echo -e "${YELLOW}── 2. OAuth2 Client ID ──${NC}"
echo "The OAuth2 client ID created in Nextcloud admin."
echo "(Nextcloud → Administration Settings → Security → OAuth 2.0 clients)"
echo ""
read -p "Client ID: " CLIENT_ID
echo ""

if [ -z "$CLIENT_ID" ]; then
    echo -e "${RED}ERROR: Client ID is required!${NC}"
    exit 1
fi

echo -e "${YELLOW}── 3. OAuth2 Client Secret ──${NC}"
echo "The secret key of the OAuth2 client created in Nextcloud admin."
echo ""
read -p "Client Secret: " CLIENT_SECRET
echo ""

if [ -z "$CLIENT_SECRET" ]; then
    echo -e "${RED}ERROR: Client Secret is required!${NC}"
    exit 1
fi

echo -e "${YELLOW}── 4. Nextcloud Username ──${NC}"
echo "Your Nextcloud username. If you log in via OIDC (e.g. Authentik),"
echo "it may differ from your display name (e.g. oidc-abc123...)."
echo "Find it: Nextcloud → Settings → click your name → visible in the URL."
echo ""
read -p "Username: " NC_USER
echo ""

echo -e "${YELLOW}── 5. Raspberry Pi IP Address ──${NC}"
echo "Your Pi's IP address on the local network. Nextcloud will redirect"
echo "your browser here after login."

if [ -n "$AUTO_IP" ]; then
    echo ""
    echo -e "Auto-detected IP: ${GREEN}${AUTO_IP}${NC}"
    echo "Press ENTER to use this, or type a different one."
    echo ""
    read -p "Pi IP address [${AUTO_IP}]: " PI_HOST
    PI_HOST="${PI_HOST:-$AUTO_IP}"
else
    echo ""
    read -p "Pi IP address: " PI_HOST
fi

if [ -z "$PI_HOST" ]; then
    echo -e "${RED}ERROR: IP address is required!${NC}"
    exit 1
fi

# ─── Summary ─────────────────────────────────────────────

echo ""
echo -e "${CYAN}── Summary ──${NC}"
echo -e "  Nextcloud URL:    ${BOLD}${NC_URL}${NC}"
echo -e "  Client ID:        ${BOLD}${CLIENT_ID:0:20}...${NC}"
echo -e "  Client Secret:    ${BOLD}****${NC}"
echo -e "  Username:         ${BOLD}${NC_USER}${NC}"
echo -e "  Pi IP:            ${BOLD}${PI_HOST}${NC}"
echo -e "  Callback:         ${BOLD}http://${PI_HOST}:9876/callback${NC}"
echo ""

read -p "Everything correct? Start the login? (y/n) " CONFIRM
if [[ ! "$CONFIRM" =~ ^[yY]$ ]]; then
    echo "Cancelled."
    exit 0
fi

# ─── Run setup ───────────────────────────────────────────

echo ""
echo -e "${GREEN}Starting login server...${NC}"
echo ""
echo -e "${BOLD}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}  IMPORTANT: Open the URL below in your BROWSER!${NC}"
echo -e "${BOLD}  (On your computer, not on the Pi)${NC}"
echo -e "${BOLD}═══════════════════════════════════════════════════════════${NC}"
echo ""

node "$SETUP_SCRIPT" \
    --nextcloudUrl "$NC_URL" \
    --clientId "$CLIENT_ID" \
    --clientSecret "$CLIENT_SECRET" \
    --username "$NC_USER" \
    --host "$PI_HOST"

EXIT_CODE=$?

echo ""
if [ $EXIT_CODE -ne 0 ]; then
    echo -e "${RED}════════════════════════════════════════════════════${NC}"
    echo -e "${RED}  ERROR: Login failed!${NC}"
    echo -e "${RED}  Check your details and try again.${NC}"
    echo -e "${RED}════════════════════════════════════════════════════${NC}"
    exit 1
fi

echo -e "${GREEN}Token setup successful!${NC}"
echo ""

# ─── Config.js modification ──────────────────────────────

CONFIG_FILE="$HOME/MagicMirror/config/config.js"

echo -e "${YELLOW}── 6. MagicMirror config.js Setup ──${NC}"
echo "The module configuration can be added to your MagicMirror config.js file."
echo ""

if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "Looking for config file: ${BOLD}${CONFIG_FILE}${NC}"
    echo ""
    read -p "Cannot find config.js. Enter the path (or ENTER to skip): " CUSTOM_CONFIG
    if [ -z "$CUSTOM_CONFIG" ]; then
        echo ""
        echo -e "${GREEN}════════════════════════════════════════════════════${NC}"
        echo -e "${GREEN}  Token setup complete!${NC}"
        echo -e "${GREEN}  You need to configure config.js manually.${NC}"
        echo -e "${GREEN}  See: README.md (4. Configuration)${NC}"
        echo -e "${GREEN}  Then: pm2 restart magicmirror${NC}"
        echo -e "${GREEN}════════════════════════════════════════════════════${NC}"
        exit 0
    fi
    CONFIG_FILE="$CUSTOM_CONFIG"
fi

# Check if module is already configured
if grep -q "MMM-NextcloudPhotos" "$CONFIG_FILE" 2>/dev/null; then
    echo -e "${GREEN}MMM-NextcloudPhotos is already in config.js.${NC}"
    echo -e "To modify it, edit manually: ${BOLD}${CONFIG_FILE}${NC}"
    echo ""
    echo -e "${GREEN}════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  Setup complete! Restart MagicMirror:${NC}"
    echo -e "${GREEN}    pm2 restart magicmirror${NC}"
    echo -e "${GREEN}════════════════════════════════════════════════════${NC}"
    exit 0
fi

read -p "Add the module to config.js? (y/n) " ADD_CONFIG
if [[ ! "$ADD_CONFIG" =~ ^[yY]$ ]]; then
    echo ""
    echo -e "${GREEN}════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  Token setup complete!${NC}"
    echo -e "${GREEN}  You need to configure config.js manually.${NC}"
    echo -e "${GREEN}  See: README.md (4. Configuration)${NC}"
    echo -e "${GREEN}  Then: pm2 restart magicmirror${NC}"
    echo -e "${GREEN}════════════════════════════════════════════════════${NC}"
    exit 0
fi

echo ""
echo -e "${YELLOW}Name of the folder in Nextcloud where you upload photos.${NC}"
echo ""
read -p "Folder name [mirror]: " NC_FOLDER
NC_FOLDER="${NC_FOLDER:-mirror}"

# Backup
cp "$CONFIG_FILE" "${CONFIG_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
echo -e "${GREEN}Backup created for config.js.${NC}"

# Insert module using Node.js (config.js is JavaScript, not JSON)
node -e "
const fs = require('fs');
const configPath = process.argv[1];
const ncUrl = process.argv[2];
const ncUser = process.argv[3];
const folder = process.argv[4];

let content = fs.readFileSync(configPath, 'utf8');

// Module config block
const moduleBlock = [
  '    {',
  '      module: \"MMM-NextcloudPhotos\",',
  '      position: \"fullscreen_below\",',
  '      config: {',
  '        nextcloudUrl: \"' + ncUrl + '\",',
  '        username: \"' + ncUser + '\",',
  '        folder: \"' + folder + '\",',
  '        updateInterval: 60 * 1000,',
  '        syncInterval: 10 * 60 * 1000,',
  '        backgroundSize: \"cover\",',
  '        order: \"random\",',
  '      }',
  '    },',
].join('\n');

// Find the closing ] of the modules array
const lines = content.split('\n');
let insertIndex = -1;
let bracketDepth = 0;
let inModules = false;

for (let i = 0; i < lines.length; i++) {
  const line = lines[i];
  if (/modules\s*:/.test(line)) {
    inModules = true;
  }
  if (inModules) {
    for (const ch of line) {
      if (ch === '[') bracketDepth++;
      if (ch === ']') {
        bracketDepth--;
        if (bracketDepth === 0) {
          insertIndex = i;
          inModules = false;
          break;
        }
      }
    }
  }
}

if (insertIndex === -1) {
  console.error('ERROR: Cannot find the modules array in config.js!');
  process.exit(1);
}

// Insert before the closing ]
lines.splice(insertIndex, 0, moduleBlock);
fs.writeFileSync(configPath, lines.join('\n'), 'utf8');
console.log('OK');
" "$CONFIG_FILE" "$NC_URL" "$NC_USER" "$NC_FOLDER"

CONFIG_RESULT=$?

echo ""
if [ $CONFIG_RESULT -eq 0 ]; then
    echo -e "${GREEN}════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  Setup complete! Module added to config.js.${NC}"
    echo -e "${GREEN}${NC}"
    echo -e "${GREEN}  Nextcloud folder: ${BOLD}${NC_FOLDER}${NC}"
    echo -e "${GREEN}  Upload photos to this folder in Nextcloud!${NC}"
    echo -e "${GREEN}${NC}"
    echo -e "${GREEN}  Now restart MagicMirror:${NC}"
    echo -e "${GREEN}    pm2 restart magicmirror${NC}"
    echo -e "${GREEN}════════════════════════════════════════════════════${NC}"
else
    echo -e "${RED}════════════════════════════════════════════════════${NC}"
    echo -e "${RED}  ERROR: Failed to modify config.js!${NC}"
    echo -e "${RED}  Add it manually. See: README.md${NC}"
    echo -e "${RED}════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${YELLOW}  Add this to the modules array:${NC}"
    echo ""
    echo "    {"
    echo "      module: \"MMM-NextcloudPhotos\","
    echo "      position: \"fullscreen_below\","
    echo "      config: {"
    echo "        nextcloudUrl: \"${NC_URL}\","
    echo "        username: \"${NC_USER}\","
    echo "        folder: \"${NC_FOLDER}\","
    echo "        updateInterval: 60 * 1000,"
    echo "        syncInterval: 10 * 60 * 1000,"
    echo "        backgroundSize: \"cover\","
    echo "        order: \"random\","
    echo "      }"
    echo "    },"
fi
