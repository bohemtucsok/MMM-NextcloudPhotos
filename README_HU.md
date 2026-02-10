<p align="center">
  <img src="https://img.shields.io/badge/MagicMirror%C2%B2-modul-blueviolet" alt="MagicMirror² Modul" />
  <img src="https://img.shields.io/badge/platform-Raspberry%20Pi-red" alt="Raspberry Pi" />
  <img src="https://img.shields.io/badge/nextcloud-WebDAV%20%2B%20OAuth2-blue" alt="Nextcloud" />
  <img src="https://img.shields.io/badge/license-MIT-green" alt="MIT Licenc" />
</p>

# MMM-NextcloudPhotos

<p align="center">
  <strong>Nextcloud fotók megjelenítése teljes képernyős háttérként a MagicMirror²-ben, crossfade átmenettel.</strong>
</p>

<p align="center">
  <a href="#funkciók">Funkciók</a> •
  <a href="#telepítés">Telepítés</a> •
  <a href="#konfiguráció">Konfiguráció</a> •
  <a href="#távoli-beállítás">Távoli beállítás</a> •
  <a href="#hibaelhárítás">Hibaelhárítás</a> •
  <a href="#licenc">Licenc</a>
</p>

<p align="center">
  <strong><a href="README.md">English documentation</a></strong>
</p>

---

## Miért ez a modul?

Van egy Raspberry Pi-d a falon, rajta fut a [MagicMirror²](https://magicmirror.builders/). Szeretnéd, ha a Nextcloud-ból mutatná a családi fotókat — USB stick, manuális másolgatás vagy idegen felhőszolgáltatás nélkül.

Az **MMM-NextcloudPhotos** közvetlenül csatlakozik a Nextcloud-odhoz OAuth2 + WebDAV-on keresztül, letölti a fotókat, menet közben átméretezi őket (hogy a Pi ne fagyjon le egy 12MB-os képtől), és teljes képernyős háttérként jeleníti meg crossfade átmenettel.

Feltöltesz egy fotót a telefonodról a Nextcloud-ba → megjelenik a tükrön. Ennyi.

---

## Funkciók

- **Teljes képernyős háttér diavetítés** crossfade átmenettel
- **Nextcloud OAuth2** hitelesítés (beépített, nem kell harmadik fél tokenje)
- **Automatikus token frissítés** — egyszer hitelesítesz, utána örökre fut
- **Okos képátméretezés** [sharp](https://sharp.pixelplumbing.com/)-pal — egy 12MB-os fotóból ~250KB lesz
- **Raspberry Pi 3 optimalizált** — egyszálas feldolgozás, memória-biztos
- **Testreszabható** képváltási idő, szinkronizálási gyakoriság, megjelenítési mód, átlátszóság
- **Interaktív setup script** — végigvezet a beállításon a Pi-n
- **Automatikus config.js szerkesztés** — a setup script hozzáadhatja a modul konfigurációt

---

## Telepítés

### 1. Modul letöltése

```bash
cd ~/MagicMirror/modules
git clone https://github.com/bohemtucsok/MMM-NextcloudPhotos.git
cd MMM-NextcloudPhotos
npm install
```

### 2. Nextcloud OAuth2 kliens létrehozása

1. Nyisd meg a Nextcloud adminisztrációs felületet
2. Menj ide: **Adminisztrációs beállítások → Biztonság → OAuth 2.0 kliensek**
3. Adj hozzá egy új klienst:
   - **Név:** `MagicMirror`
   - **Átirányítási URL:** `http://<RASPBERRY-PI-IP-CÍME>:9876/callback`
4. Jegyezd fel a **Client ID** és **Client Secret** értékeket

### 3. Első bejelentkezés (egyszeri)

A legegyszerűbb mód — futtasd az interaktív setup scriptet a Pi-n:

```bash
cd ~/MagicMirror/modules/MMM-NextcloudPhotos
bash setup.sh
```

A script:
- Végigvezet minden lépésen
- Automatikusan felismeri a Pi IP-jét
- Elmenti a tokeneket a `tokens.json` fájlba
- Opcionálisan hozzáadja a modult a `config.js`-hez

<details>
<summary><strong>Manuális beállítás (alternatíva)</strong></summary>

```bash
node setup_oauth.js \
  --nextcloudUrl https://cloud.pelda.hu \
  --clientId CLIENT_ID \
  --clientSecret CLIENT_SECRET \
  --username NEXTCLOUD_FELHASZNÁLÓNÉV \
  --host RASPBERRY_PI_IP
```

**A paraméterek:**

| Paraméter | Mit írj ide | Példa |
|-----------|-------------|-------|
| `--nextcloudUrl` | A Nextcloud szervered webcíme | `https://cloud.pelda.hu` |
| `--clientId` | A 2. lépésben kapott Client ID | `aBcDeFgH12345...` |
| `--clientSecret` | A 2. lépésben kapott Client Secret | `xYzWvU98765...` |
| `--username` | A Nextcloud felhasználóneved | `janos` |
| `--host` | A Raspberry Pi IP címe | `192.168.1.100` |

Nyisd meg a kiírt URL-t a böngésződben, jelentkezz be, és engedélyezd a hozzáférést.

</details>

### 4. MagicMirror konfiguráció

Ha a setup script nem adta hozzá automatikusan, szerkeszd a `~/MagicMirror/config/config.js` fájlt:

```javascript
{
  module: "MMM-NextcloudPhotos",
  position: "fullscreen_below",
  config: {
    nextcloudUrl: "https://cloud.pelda.hu",
    username: "felhasznalonev",
    folder: "mirror",
  }
}
```

### 5. Képek feltöltése

Hozz létre egy `mirror` nevű mappát a Nextcloud-ban (vagy amit a `folder` beállításnál megadtál) és tölts fel képeket.

Támogatott formátumok: **JPG, JPEG, PNG, WebP, GIF, BMP, TIFF**

### 6. MagicMirror újraindítása

```bash
pm2 restart magicmirror
```

---

## Konfiguráció

| Beállítás | Alapértelmezett | Leírás |
|-----------|----------------|--------|
| `nextcloudUrl` | `""` | Nextcloud szerver URL |
| `username` | `""` | Nextcloud felhasználónév |
| `folder` | `"mirror"` | Mappa neve a Nextcloud-ban |
| `tokenFile` | `"tokens.json"` | Token fájl útvonala |
| `updateInterval` | `30000` (30 mp) | Képváltás gyakorisága (ms) |
| `syncInterval` | `600000` (10 perc) | Nextcloud szinkronizálás gyakorisága (ms) |
| `transitionDuration` | `2000` (2 mp) | Átmenet időtartama (ms) |
| `backgroundSize` | `"cover"` | `cover` = kitölti a képernyőt, `contain` = teljes kép látszik |
| `order` | `"random"` | `random` = véletlenszerű, `sequential` = sorrendben |
| `opacity` | `1.0` | Háttérkép átlátszóság (0.0 - 1.0) |
| `maxWidth` | `1920` | Max képszélesség átméretezéshez (px) |
| `maxHeight` | `1080` | Max képmagasság átméretezéshez (px) |
| `imageQuality` | `80` | JPEG minőség átméretezés után (1-100) |

---

## Távoli beállítás

Ha a Pi nem érhető el a böngésződből közvetlenül:

<details>
<summary><strong>A opció: Helyi setup, majd token másolás</strong></summary>

```bash
# Saját gépen:
node setup_oauth.js \
  --nextcloudUrl https://cloud.pelda.hu \
  --clientId CLIENT_ID \
  --clientSecret CLIENT_SECRET \
  --username FELHASZNÁLÓNÉV \
  --host localhost

# Majd másold a tokens.json-t a Pi-re:
scp tokens.json user@pi-ip:~/MagicMirror/modules/MMM-NextcloudPhotos/
```

> **Fontos:** Az OAuth2 kliensben az átirányítási URL-t átmenetileg `http://localhost:9876/callback`-re kell állítani!

</details>

<details>
<summary><strong>B opció: SSH tunnel</strong></summary>

```bash
# Saját gépről SSH tunnel:
ssh -L 9876:localhost:9876 user@pi-ip

# Az SSH session-ben (Pi-n):
cd ~/MagicMirror/modules/MMM-NextcloudPhotos
node setup_oauth.js \
  --nextcloudUrl https://cloud.pelda.hu \
  --clientId CLIENT_ID \
  --clientSecret CLIENT_SECRET \
  --username FELHASZNÁLÓNÉV \
  --host localhost
```

Nyisd meg a kiírt URL-t a saját gépeden.

</details>

---

## Teljesítmény

Alacsony memóriás eszközökön (Raspberry Pi 3, ~900MB RAM) a modul automatikusan:

| Optimalizáció | Részletek |
|--------------|-----------|
| **Képátméretezés** | Letöltött képek átméretezése 1920x1080-ra `sharp`-pal |
| **JPEG tömörítés** | Progresszív JPEG, minőség 80 |
| **Egyszálas** | `sharp.concurrency(1)` a memória-csúcsok megelőzésére |
| **Memória cleanup** | Megjelenítés után a képek felszabadulnak a memóriából |

Egy 12MB-os fotó tipikusan ~200-300KB-ra csökken, megelőzve a memória-kifogyást.

---

## Hibaelhárítás

| Probléma | Megoldás |
|----------|----------|
| "Tokenek nem találhatók" hiba | Futtasd a `bash setup.sh` vagy `node setup_oauth.js` parancsot újra |
| "Token frissítés sikertelen" | Futtasd újra a setup scriptet új token létrehozásához |
| Képek nem jelennek meg | Ellenőrizd a Nextcloud mappát és a `pm2 logs magicmirror` logot |
| `git pull` után nem működik | `sudo chown -R $(whoami):$(whoami) ~/MagicMirror/modules/MMM-NextcloudPhotos/` |

<details>
<summary><strong>Nextcloud felhasználónév megkeresése</strong></summary>

Ha OIDC provider-en (pl. Authentik, Keycloak) keresztül jelentkezel be, a felhasználóneved eltérhet a szokásostól (pl. `oidc-abc123...`).

Megkeresése:
1. Jelentkezz be a Nextcloud-ba a böngészőben
2. Menj a **Beállítások** oldalra
3. A felhasználóneved az URL-ben látható: `https://cloud.pelda.hu/settings/user/FELHASZNÁLÓNÉV`

Vagy a Nextcloud admin felületen: **Felhasználók** → a felhasználó neve az első oszlopban.

</details>

---

## Tech Stack

| Réteg | Technológia |
|-------|------------|
| Frontend | MagicMirror² Module API (DOM manipuláció, crossfade) |
| Backend | Node.js node_helper (socket notifications) |
| Hitelesítés | OAuth2 (Nextcloud beépített) automatikus frissítéssel |
| Fájl hozzáférés | WebDAV (PROPFIND + GET Bearer tokennel) |
| Képfeldolgozás | sharp (átméretezés, tömörítés, progresszív JPEG) |
| HTTP kliens | axios |

---

## Licenc

[MIT](LICENSE) — használd, forkold, hosztold magadnál. Hozzájárulásokat szívesen fogadunk.
