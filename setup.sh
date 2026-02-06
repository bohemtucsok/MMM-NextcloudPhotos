#!/bin/bash
# ============================================================
#  MMM-NextcloudPhotos - Interaktív Token Beállítás
#  Ez a script végigvezet a Nextcloud OAuth2 bejelentkezésen.
# ============================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SETUP_SCRIPT="$SCRIPT_DIR/setup_oauth.js"

# Szín kódok
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

echo ""
echo -e "${CYAN}============================================================${NC}"
echo -e "${CYAN}  MMM-NextcloudPhotos - Token Beállítás${NC}"
echo -e "${CYAN}============================================================${NC}"
echo ""
echo -e "Ez a script összeköti a MagicMirror-t a Nextcloud fiókodddal."
echo -e "A beállítást ${BOLD}egyszer kell megcsinálni${NC}, utána automatikusan működik."
echo ""

# Ellenőrzések
if [ ! -f "$SETUP_SCRIPT" ]; then
    echo -e "${RED}HIBA: Nem találom a setup_oauth.js fájlt!${NC}"
    echo "Elvárt hely: $SETUP_SCRIPT"
    exit 1
fi

if ! command -v node &> /dev/null; then
    echo -e "${RED}HIBA: A Node.js nincs telepítve!${NC}"
    echo "Telepítsd: sudo apt install nodejs"
    exit 1
fi

# Függőségek telepítése ha hiányoznak
if [ ! -d "$SCRIPT_DIR/node_modules" ]; then
    echo -e "${YELLOW}Függőségek telepítése (npm install)...${NC}"
    (cd "$SCRIPT_DIR" && npm install)
    echo -e "${GREEN}Függőségek telepítve.${NC}"
    echo ""
fi

# Automatikus IP felderítés
AUTO_IP=$(hostname -I 2>/dev/null | awk '{print $1}')

# ─── Adatok bekérése ───────────────────────────────────────

echo -e "${YELLOW}── 1. Nextcloud szerver URL ──${NC}"
echo "A Nextcloud szervered webcíme (pl. https://cloud.pelda.hu)"
echo ""
read -p "Nextcloud URL: " NC_URL
echo ""

if [ -z "$NC_URL" ]; then
    echo -e "${RED}HIBA: A Nextcloud URL megadása kötelező!${NC}"
    exit 1
fi

echo -e "${YELLOW}── 2. OAuth2 Client ID ──${NC}"
echo "A Nextcloud adminban létrehozott OAuth2 kliens azonosítója."
echo "(Nextcloud → Adminisztrációs beállítások → Biztonság → OAuth 2.0 kliensek)"
echo ""
read -p "Client ID: " CLIENT_ID
echo ""

if [ -z "$CLIENT_ID" ]; then
    echo -e "${RED}HIBA: A Client ID megadása kötelező!${NC}"
    exit 1
fi

echo -e "${YELLOW}── 3. OAuth2 Client Secret ──${NC}"
echo "A Nextcloud adminban létrehozott OAuth2 kliens titkos kulcsa."
echo ""
read -p "Client Secret: " CLIENT_SECRET
echo ""

if [ -z "$CLIENT_SECRET" ]; then
    echo -e "${RED}HIBA: A Client Secret megadása kötelező!${NC}"
    exit 1
fi

echo -e "${YELLOW}── 4. Nextcloud felhasználónév ──${NC}"
echo "A Nextcloud felhasználóneved. Ha OIDC-vel (pl. Authentik) jelentkezel be,"
echo "akkor ez eltérhet (pl. oidc-abc123...)."
echo "Megtalálod: Nextcloud → Beállítások → a nevedre kattintva → URL-ben látható."
echo ""
read -p "Felhasználónév: " NC_USER
echo ""

echo -e "${YELLOW}── 5. Raspberry Pi IP címe ──${NC}"
echo "A Pi IP címe a helyi hálózaton. Erre irányítja vissza a Nextcloud"
echo "a böngészőt a bejelentkezés után."

if [ -n "$AUTO_IP" ]; then
    echo ""
    echo -e "Automatikusan felismert IP: ${GREEN}${AUTO_IP}${NC}"
    echo "Nyomj ENTER-t ennek használatához, vagy írj be másikat."
    echo ""
    read -p "Pi IP címe [${AUTO_IP}]: " PI_HOST
    PI_HOST="${PI_HOST:-$AUTO_IP}"
else
    echo ""
    read -p "Pi IP címe: " PI_HOST
fi

if [ -z "$PI_HOST" ]; then
    echo -e "${RED}HIBA: Az IP cím megadása kötelező!${NC}"
    exit 1
fi

# ─── Összefoglaló ──────────────────────────────────────────

echo ""
echo -e "${CYAN}── Összefoglaló ──${NC}"
echo -e "  Nextcloud URL:    ${BOLD}${NC_URL}${NC}"
echo -e "  Client ID:        ${BOLD}${CLIENT_ID:0:20}...${NC}"
echo -e "  Client Secret:    ${BOLD}****${NC}"
echo -e "  Felhasználónév:   ${BOLD}${NC_USER}${NC}"
echo -e "  Pi IP:            ${BOLD}${PI_HOST}${NC}"
echo -e "  Callback:         ${BOLD}http://${PI_HOST}:9876/callback${NC}"
echo ""

read -p "Minden rendben? Indítsuk a bejelentkezést? (i/n) " CONFIRM
if [[ ! "$CONFIRM" =~ ^[iIyY]$ ]]; then
    echo "Megszakítva."
    exit 0
fi

# ─── Setup futtatása ───────────────────────────────────────

echo ""
echo -e "${GREEN}Bejelentkezési szerver indítása...${NC}"
echo ""
echo -e "${BOLD}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}  FONTOS: Nyisd meg a megjelenő URL-t a BÖNGÉSZŐDBEN!${NC}"
echo -e "${BOLD}  (A saját gépeden, nem a Pi-n)${NC}"
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
    echo -e "${RED}  HIBA történt a bejelentkezés során!${NC}"
    echo -e "${RED}  Ellenőrizd az adatokat és próbáld újra.${NC}"
    echo -e "${RED}════════════════════════════════════════════════════${NC}"
    exit 1
fi

echo -e "${GREEN}Token beállítás sikeres!${NC}"
echo ""

# ─── Config.js módosítás ──────────────────────────────────

CONFIG_FILE="$HOME/MagicMirror/config/config.js"

echo -e "${YELLOW}── 6. MagicMirror config.js beállítása ──${NC}"
echo "A modul konfigurációját hozzáadhatjuk a MagicMirror config.js fájlhoz."
echo ""

if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "Config fájl keresése: ${BOLD}${CONFIG_FILE}${NC}"
    echo ""
    read -p "Nem találom a config.js-t. Add meg az útvonalat (vagy ENTER a kihagyáshoz): " CUSTOM_CONFIG
    if [ -z "$CUSTOM_CONFIG" ]; then
        echo ""
        echo -e "${GREEN}════════════════════════════════════════════════════${NC}"
        echo -e "${GREEN}  Token beállítás kész!${NC}"
        echo -e "${GREEN}  A config.js-t manuálisan kell beállítanod.${NC}"
        echo -e "${GREEN}  Lásd: README.md (4. Konfiguráció)${NC}"
        echo -e "${GREEN}  Utána: pm2 restart magicmirror${NC}"
        echo -e "${GREEN}════════════════════════════════════════════════════${NC}"
        exit 0
    fi
    CONFIG_FILE="$CUSTOM_CONFIG"
fi

# Ellenőrizzük, hogy már benne van-e a modul
if grep -q "MMM-NextcloudPhotos" "$CONFIG_FILE" 2>/dev/null; then
    echo -e "${GREEN}A MMM-NextcloudPhotos már szerepel a config.js-ben.${NC}"
    echo -e "Ha módosítani szeretnéd, szerkeszd kézzel: ${BOLD}${CONFIG_FILE}${NC}"
    echo ""
    echo -e "${GREEN}════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  Beállítás kész! Indítsd újra a MagicMirror-t:${NC}"
    echo -e "${GREEN}    pm2 restart magicmirror${NC}"
    echo -e "${GREEN}════════════════════════════════════════════════════${NC}"
    exit 0
fi

read -p "Hozzáadjam a modult a config.js-hez? (i/n) " ADD_CONFIG
if [[ ! "$ADD_CONFIG" =~ ^[iIyY]$ ]]; then
    echo ""
    echo -e "${GREEN}════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  Token beállítás kész!${NC}"
    echo -e "${GREEN}  A config.js-t manuálisan kell beállítanod.${NC}"
    echo -e "${GREEN}  Lásd: README.md (4. Konfiguráció)${NC}"
    echo -e "${GREEN}  Utána: pm2 restart magicmirror${NC}"
    echo -e "${GREEN}════════════════════════════════════════════════════${NC}"
    exit 0
fi

echo ""
echo -e "${YELLOW}Mappa neve a Nextcloud-ban, ahová a képeket feltöltöd.${NC}"
echo ""
read -p "Mappa neve [mirror]: " NC_FOLDER
NC_FOLDER="${NC_FOLDER:-mirror}"

# Biztonsági mentés
cp "$CONFIG_FILE" "${CONFIG_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
echo -e "${GREEN}Biztonsági mentés készült a config.js-ről.${NC}"

# Node.js-sel szúrjuk be a modult (a config.js JavaScript, nem JSON)
node -e "
const fs = require('fs');
const configPath = process.argv[1];
const ncUrl = process.argv[2];
const ncUser = process.argv[3];
const folder = process.argv[4];

let content = fs.readFileSync(configPath, 'utf8');

// Modul konfiguráció blokk
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

// Keressük a modules tömb záró ]-ját
// Stratégia: az utolsó ] előtt szúrjuk be, ami a modules tömbhöz tartozik
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
  console.error('HIBA: Nem találom a modules tömböt a config.js-ben!');
  process.exit(1);
}

// Beszúrás a záró ] elé
lines.splice(insertIndex, 0, moduleBlock);
fs.writeFileSync(configPath, lines.join('\n'), 'utf8');
console.log('OK');
" "$CONFIG_FILE" "$NC_URL" "$NC_USER" "$NC_FOLDER"

CONFIG_RESULT=$?

echo ""
if [ $CONFIG_RESULT -eq 0 ]; then
    echo -e "${GREEN}════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  Beállítás kész! A modul hozzáadva a config.js-hez.${NC}"
    echo -e "${GREEN}${NC}"
    echo -e "${GREEN}  Nextcloud mappa: ${BOLD}${NC_FOLDER}${NC}"
    echo -e "${GREEN}  Tölts fel képeket ebbe a mappába a Nextcloud-ban!${NC}"
    echo -e "${GREEN}${NC}"
    echo -e "${GREEN}  Most indítsd újra a MagicMirror-t:${NC}"
    echo -e "${GREEN}    pm2 restart magicmirror${NC}"
    echo -e "${GREEN}════════════════════════════════════════════════════${NC}"
else
    echo -e "${RED}════════════════════════════════════════════════════${NC}"
    echo -e "${RED}  HIBA: Nem sikerült módosítani a config.js-t!${NC}"
    echo -e "${RED}  Add hozzá manuálisan. Lásd: README.md${NC}"
    echo -e "${RED}════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${YELLOW}  Ezt kell hozzáadni a modules tömbhöz:${NC}"
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
