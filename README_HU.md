# MMM-NextcloudPhotos

MagicMirror² modul, amely Nextcloud szerverről tölt le képeket és háttérképként jeleníti meg őket, crossfade átmenettel.

---

## Telepítés

### 1. Modul letöltése

```bash
cd ~/MagicMirror/modules
git clone <REPO-URL> MMM-NextcloudPhotos
cd MMM-NextcloudPhotos
npm install
```

### 2. Nextcloud OAuth2 kliens létrehozása

1. Nyisd meg a Nextcloud adminisztrációs felületet a böngészőben
2. Menj ide: **Adminisztrációs beállítások → Biztonság → OAuth 2.0 kliensek**
3. Adj hozzá egy új klienst:
   - **Név:** `MagicMirror`
   - **Átirányítási URL:** `http://<RASPBERRY-PI-IP-CÍME>:9876/callback`
     Ez a Raspberry Pi IP címe a helyi hálózaton (pl. `http://192.168.1.100:9876/callback`).
     A Pi IP-jét megtalálod a Pi-n az `ip addr` vagy `hostname -I` paranccsal.
4. Jegyezd fel a **Client ID** és **Client Secret** értékeket

### 3. Első bejelentkezés (token létrehozás)

Ez a lépés összeköti a MagicMirror-t a Nextcloud fiókoddal. **Egyszer kell megcsinálni**, utána a modul magától frissíti a tokent.

**Legegyszerűbb mód:** futtasd az interaktív setup scriptet a Pi-n:

```bash
cd ~/MagicMirror/modules/MMM-NextcloudPhotos
bash setup.sh
```

A script végigvezet minden lépésen, automatikusan felismeri a Pi IP-jét, és elmagyarázza mit kell beírni.

Vagy ha manuálisan szeretnéd megadni a paramétereket:

#### A) Ha a Pi elérhető a helyi hálózatról (legegyszerűbb)

Ehhez a **Raspberry Pi**-nek és a **böngészőt futtató gépednek** (laptop/PC) **ugyanazon a hálózaton** kell lennie.

**A Pi-n futtasd** (SSH-n keresztül):

```bash
cd ~/MagicMirror/modules/MMM-NextcloudPhotos
node setup_oauth.js \
  --nextcloudUrl https://NEXTCLOUD-CÍMED \
  --clientId IDE-ÍROD-A-CLIENT-ID-T \
  --clientSecret IDE-ÍROD-A-CLIENT-SECRET-ET \
  --username NEXTCLOUD-FELHASZNÁLÓNEVED \
  --host RASPBERRY-PI-IP-CÍME
```

**A paraméterek magyarázata:**

| Paraméter | Mit írj ide | Példa |
|-----------|-------------|-------|
| `--nextcloudUrl` | A Nextcloud szervered webcíme | `https://cloud.pelda.hu` |
| `--clientId` | A 2. lépésben kapott Client ID | `aBcDeFgH12345...` |
| `--clientSecret` | A 2. lépésben kapott Client Secret | `xYzWvU98765...` |
| `--username` | A Nextcloud felhasználóneved (lásd lent) | `janos` |
| `--host` | A **Raspberry Pi** IP címe a hálózaton | `192.168.1.100` |

**Példa valós adatokkal:**

```bash
node setup_oauth.js \
  --nextcloudUrl https://cloud.pelda.hu \
  --clientId aBcDeFgH12345... \
  --clientSecret xYzWvU98765... \
  --username janos \
  --host 192.168.1.100
```

A script kiír egy URL-t a terminálba. **Nyisd meg ezt az URL-t a böngésződben** (a saját laptop/PC gépeden, nem a Pi-n), jelentkezz be a Nextcloud-ba, és engedélyezd a hozzáférést.

Ha sikerült, ezt látod: **"Sikeres bejelentkezés!"** - az ablak bezárható.

#### B) Ha a Pi nem elérhető (távoli hálózaton van)

**1. opció: Futtasd a saját gépeden, majd másold a tokent**

A saját gépeden (ahol böngésző van) is futtathatod a setup-ot:

```bash
# Saját gépen:
node setup_oauth.js \
  --nextcloudUrl https://cloud.pelda.hu \
  --clientId IDE-A-CLIENT-ID \
  --clientSecret IDE-A-CLIENT-SECRET \
  --username FELHASZNÁLÓNÉV \
  --host localhost
```

> **Fontos:** Ehhez a Nextcloud OAuth2 kliensben az átirányítási URL-t átmenetileg
> `http://localhost:9876/callback`-re kell állítani! Utána visszaállíthatod a Pi IP-jére.

Bejelentkezés után másold át a `tokens.json` fájlt a Pi-re:

```bash
scp tokens.json FELHASZNÁLÓ@PI-IP-CÍME:~/MagicMirror/modules/MMM-NextcloudPhotos/
```

**2. opció: SSH tunnel**

```bash
# Saját gépről nyiss egy SSH tunnel-t:
ssh -L 9876:localhost:9876 FELHASZNÁLÓ@PI-IP-CÍME

# Az SSH session-ben (a Pi-n) futtasd:
cd ~/MagicMirror/modules/MMM-NextcloudPhotos
node setup_oauth.js \
  --nextcloudUrl https://cloud.pelda.hu \
  --clientId IDE-A-CLIENT-ID \
  --clientSecret IDE-A-CLIENT-SECRET \
  --username FELHASZNÁLÓNÉV \
  --host localhost
```

Nyisd meg a kiírt URL-t a saját gépeden (a tunnel átirányítja a Pi-re).

### 4. MagicMirror konfiguráció

Szerkeszd a `~/MagicMirror/config/config.js` fájlt és add hozzá a modult:

```javascript
{
  module: "MMM-NextcloudPhotos",
  position: "fullscreen_below",
  config: {
    nextcloudUrl: "https://cloud.pelda.hu",
    username: "felhasznalonev",
    folder: "mirror",                    // Nextcloud mappa neve
    updateInterval: 60 * 1000,           // Képváltás: 60 másodperc
    syncInterval: 10 * 60 * 1000,        // Szinkronizálás: 10 perc
    transitionDuration: 2000,            // Átmenet: 2 másodperc
    backgroundSize: "cover",             // cover = kitölti a képernyőt
    order: "random",                     // random vagy sequential
    opacity: 1.0,                        // Átlátszóság (0.0 - 1.0)
  }
}
```

### 5. Képek feltöltése

Hozz létre egy `mirror` nevű mappát a Nextcloud-ban (vagy amit a `folder` beállításnál megadtál), és tölts fel képeket.

Támogatott formátumok: **JPG, JPEG, PNG, WebP, GIF, BMP, TIFF**

### 6. MagicMirror újraindítása

```bash
pm2 restart magicmirror
```

A képek automatikusan letöltődnek és megjelennek háttérként.

---

## Konfigurációs opciók

| Beállítás | Alapértelmezett | Leírás |
|-----------|----------------|--------|
| `nextcloudUrl` | `""` | Nextcloud szerver URL |
| `username` | `""` | Nextcloud felhasználónév |
| `folder` | `"mirror"` | Mappa neve a Nextcloud-ban |
| `tokenFile` | `"tokens.json"` | Token fájl neve |
| `updateInterval` | `30000` (30 mp) | Képváltás gyakorisága (ms) |
| `syncInterval` | `600000` (10 perc) | Nextcloud szinkronizálás gyakorisága (ms) |
| `transitionDuration` | `2000` (2 mp) | Átmenet időtartama (ms) |
| `backgroundSize` | `"cover"` | `cover` = kitölti a képernyőt, `contain` = teljes kép látszik |
| `order` | `"random"` | `random` = véletlenszerű, `sequential` = sorrendben |
| `opacity` | `1.0` | Háttérkép átlátszóság (0.0 - 1.0) |

---

## Hibaelhárítás

### "Tokenek nem találhatók" hiba
Futtasd újra a setup_oauth.js scriptet (lásd 3. lépés).

### "Token frissítés sikertelen" hiba
A refresh token lejárt. Futtasd újra a setup_oauth.js scriptet.

### Képek nem jelennek meg
1. Ellenőrizd, hogy van-e kép a Nextcloud `mirror` mappájában
2. Ellenőrizd a logot: `pm2 logs magicmirror`
3. Ellenőrizd a jogosultságokat:
   ```bash
   sudo chown -R $(whoami):$(whoami) ~/MagicMirror/modules/MMM-NextcloudPhotos/
   ```

### Git pull után nem működik
A git pull visszaállíthatja a fájljogosultságokat:
```bash
sudo chown -R $(whoami):$(whoami) ~/MagicMirror/modules/MMM-NextcloudPhotos/
mkdir -p ~/MagicMirror/modules/MMM-NextcloudPhotos/cache
pm2 restart magicmirror
```

---

## Nextcloud felhasználónév megkeresése

Ha OIDC provider-en (pl. Authentik, Keycloak) keresztül jelentkezel be a Nextcloud-ba, a felhasználóneved eltérhet a szokásostól (pl. `oidc-abc123...`).

Megkeresése:
1. Jelentkezz be a Nextcloud-ba a böngészőben
2. Menj a **Beállítások** oldalra
3. A bal oldali menüben kattints a nevedre
4. A felhasználóneved az URL-ben látható: `https://cloud.pelda.hu/settings/user/FELHASZNÁLÓNÉV`

Vagy a Nextcloud admin felületen: **Felhasználók** menüpont → a felhasználó neve az első oszlopban.
