<p align="center">
  <img src="https://img.shields.io/badge/MagicMirror%C2%B2-module-blueviolet" alt="MagicMirror² Module" />
  <img src="https://img.shields.io/badge/platform-Raspberry%20Pi-red" alt="Raspberry Pi" />
  <img src="https://img.shields.io/badge/nextcloud-WebDAV%20%2B%20OAuth2-blue" alt="Nextcloud" />
  <img src="https://img.shields.io/badge/license-MIT-green" alt="MIT License" />
</p>

# MMM-NextcloudPhotos

<p align="center">
  <strong>Display your Nextcloud photos as a fullscreen MagicMirror² background with smooth crossfade transitions.</strong>
</p>

<p align="center">
  <a href="#features">Features</a> •
  <a href="#installation">Installation</a> •
  <a href="#configuration">Configuration</a> •
  <a href="#remote-setup">Remote Setup</a> •
  <a href="#troubleshooting">Troubleshooting</a> •
  <a href="#license">License</a>
</p>

<p align="center">
  <strong><a href="README_HU.md">Magyar nyelvű leírás / Hungarian documentation</a></strong>
</p>

---

## Why this module?

You have a Raspberry Pi running [MagicMirror²](https://magicmirror.builders/) on your wall. You want it to show family photos from your Nextcloud — without USB sticks, manual syncing, or cloud services you don't control.

**MMM-NextcloudPhotos** connects directly to your Nextcloud via OAuth2 + WebDAV, downloads photos, resizes them on the fly (so your Pi doesn't choke on 12MB images), and displays them as a fullscreen background with smooth crossfade transitions.

Upload a photo to Nextcloud from your phone → it appears on your mirror. That's it.

---

## Features

- **Fullscreen background slideshow** with smooth crossfade transitions
- **Nextcloud OAuth2** authentication (built-in, no third-party tokens)
- **Automatic token refresh** — authenticate once, runs forever
- **Smart image resizing** with [sharp](https://sharp.pixelplumbing.com/) — a 12MB photo becomes ~250KB
- **Raspberry Pi 3 optimized** — single-thread processing, memory-safe
- **Configurable** rotation interval, sync frequency, display mode, opacity
- **Interactive setup script** — guided configuration on your Pi
- **Auto config.js editing** — setup script can add the module config for you

---

## Installation

### 1. Clone the module

```bash
cd ~/MagicMirror/modules
git clone https://github.com/bohemtucsok/MMM-NextcloudPhotos.git
cd MMM-NextcloudPhotos
npm install
```

### 2. Create an OAuth2 client in Nextcloud

1. Open your Nextcloud admin panel
2. Go to **Administration Settings → Security → OAuth 2.0 clients**
3. Add a new client:
   - **Name:** `MagicMirror`
   - **Redirect URI:** `http://<YOUR-PI-IP>:9876/callback`
4. Note the **Client ID** and **Client Secret**

### 3. Authenticate (one-time)

The easiest way — run the interactive setup script on your Pi:

```bash
cd ~/MagicMirror/modules/MMM-NextcloudPhotos
bash setup.sh
```

The script will:
- Guide you through each step
- Auto-detect your Pi's IP address
- Save tokens to `tokens.json`
- Optionally add the module to your `config.js`

<details>
<summary><strong>Manual setup (alternative)</strong></summary>

```bash
node setup_oauth.js \
  --nextcloudUrl https://cloud.example.com \
  --clientId YOUR_CLIENT_ID \
  --clientSecret YOUR_CLIENT_SECRET \
  --username YOUR_NEXTCLOUD_USERNAME \
  --host YOUR_PI_IP
```

Open the printed URL in your browser, log in to Nextcloud, and authorize the app.

</details>

### 4. Configure MagicMirror

If the setup script didn't add it automatically, add to your `~/MagicMirror/config/config.js`:

```javascript
{
  module: "MMM-NextcloudPhotos",
  position: "fullscreen_below",
  config: {
    nextcloudUrl: "https://cloud.example.com",
    username: "your_username",
    folder: "mirror",
  }
}
```

### 5. Upload photos

Create a folder named `mirror` (or whatever you set in `folder`) in your Nextcloud and upload images.

Supported formats: **JPG, JPEG, PNG, WebP, GIF, BMP, TIFF**

### 6. Restart MagicMirror

```bash
pm2 restart magicmirror
```

---

## Configuration

| Option | Default | Description |
|--------|---------|-------------|
| `nextcloudUrl` | `""` | Nextcloud server URL |
| `username` | `""` | Nextcloud username |
| `folder` | `"mirror"` | Folder name in Nextcloud |
| `tokenFile` | `"tokens.json"` | Token file path |
| `updateInterval` | `30000` (30s) | Image rotation interval (ms) |
| `syncInterval` | `600000` (10min) | Nextcloud sync interval (ms) |
| `transitionDuration` | `2000` (2s) | Crossfade duration (ms) |
| `backgroundSize` | `"cover"` | `cover` = fill screen, `contain` = fit entire image |
| `order` | `"random"` | `random` or `sequential` |
| `opacity` | `1.0` | Background opacity (0.0 - 1.0) |
| `maxWidth` | `1920` | Max image width for resize (px) |
| `maxHeight` | `1080` | Max image height for resize (px) |
| `imageQuality` | `80` | JPEG quality after resize (1-100) |

---

## Remote Setup

If your Pi is not on the same network as your browser:

<details>
<summary><strong>Option A: Run setup locally, then copy the token</strong></summary>

```bash
# On your local machine:
node setup_oauth.js \
  --nextcloudUrl https://cloud.example.com \
  --clientId YOUR_CLIENT_ID \
  --clientSecret YOUR_CLIENT_SECRET \
  --username YOUR_USERNAME \
  --host localhost

# Then copy tokens.json to the Pi:
scp tokens.json user@pi-ip:~/MagicMirror/modules/MMM-NextcloudPhotos/
```

> **Note:** Temporarily change the OAuth2 redirect URI to `http://localhost:9876/callback` in Nextcloud admin.

</details>

<details>
<summary><strong>Option B: SSH tunnel</strong></summary>

```bash
# From your local machine:
ssh -L 9876:localhost:9876 user@pi-ip

# In the SSH session (on the Pi):
cd ~/MagicMirror/modules/MMM-NextcloudPhotos
node setup_oauth.js \
  --nextcloudUrl https://cloud.example.com \
  --clientId YOUR_CLIENT_ID \
  --clientSecret YOUR_CLIENT_SECRET \
  --username YOUR_USERNAME \
  --host localhost
```

Then open the printed URL in your local browser.

</details>

---

## Performance

On low-memory devices (Raspberry Pi 3 with ~900MB RAM), the module automatically:

| Optimization | Detail |
|-------------|--------|
| **Image resize** | Downloads are resized to 1920x1080 via `sharp` |
| **JPEG compression** | Progressive JPEG at quality 80 |
| **Single-thread** | `sharp.concurrency(1)` to prevent memory spikes |
| **Memory cleanup** | Preloaded images are released after display |

A 12MB photo is typically reduced to ~200-300KB, preventing out-of-memory freezes.

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| "Tokens not found" error | Run `bash setup.sh` or `node setup_oauth.js` again |
| "Token refresh failed" | Re-run the setup script to get a new token |
| Images not showing | Check Nextcloud folder has photos, check `pm2 logs magicmirror` |
| After `git pull` not working | `sudo chown -R $(whoami):$(whoami) ~/MagicMirror/modules/MMM-NextcloudPhotos/` |

<details>
<summary><strong>Finding your Nextcloud username</strong></summary>

If you log in via an OIDC provider (e.g., Authentik, Keycloak), your username may differ from your display name (e.g., `oidc-abc123...`).

To find it:
1. Log in to Nextcloud in your browser
2. Go to **Settings**
3. Your username is visible in the URL: `https://cloud.example.com/settings/user/YOUR_USERNAME`

</details>

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Frontend | MagicMirror² Module API (DOM manipulation, crossfade) |
| Backend | Node.js node_helper (socket notifications) |
| Auth | OAuth2 (Nextcloud built-in) with auto-refresh |
| File Access | WebDAV (PROPFIND + GET with Bearer token) |
| Image Processing | sharp (resize, compress, progressive JPEG) |
| HTTP Client | axios |

---

## License

[MIT](LICENSE) — use it, fork it, self-host it. Contributions welcome.
