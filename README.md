# MMM-NextcloudPhotos

A [MagicMirror²](https://magicmirror.builders/) module that displays photos from your Nextcloud server as a fullscreen background with smooth crossfade transitions.

**[Magyar nyelvű leírás / Hungarian documentation](README_HU.md)**

## Features

- Fullscreen background photo slideshow from Nextcloud
- Smooth crossfade transitions between images
- OAuth2 authentication (Nextcloud built-in)
- Automatic token refresh (no manual re-authentication needed)
- Image resizing with [sharp](https://sharp.pixelplumbing.com/) for low-memory devices (Raspberry Pi 3)
- Configurable rotation interval, sync frequency, and display options
- Interactive setup script for easy configuration

## Installation

### 1. Clone the module

```bash
cd ~/MagicMirror/modules
git clone <REPO-URL> MMM-NextcloudPhotos
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

### 3. Authenticate (one-time setup)

The easiest way — run the interactive setup script on your Pi:

```bash
cd ~/MagicMirror/modules/MMM-NextcloudPhotos
bash setup.sh
```

The script will guide you through each step, auto-detect your Pi's IP address, and optionally add the module to your MagicMirror `config.js`.

Alternatively, run the setup manually:

```bash
node setup_oauth.js \
  --nextcloudUrl https://cloud.example.com \
  --clientId YOUR_CLIENT_ID \
  --clientSecret YOUR_CLIENT_SECRET \
  --username YOUR_NEXTCLOUD_USERNAME \
  --host YOUR_PI_IP
```

Open the printed URL in your browser, log in to Nextcloud, and authorize the app. Tokens are saved to `tokens.json` and refreshed automatically.

### 4. Configure MagicMirror

Add to your `~/MagicMirror/config/config.js`:

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

## Configuration Options

| Option | Default | Description |
|--------|---------|-------------|
| `nextcloudUrl` | `""` | Nextcloud server URL |
| `username` | `""` | Nextcloud username |
| `folder` | `"mirror"` | Folder name in Nextcloud |
| `tokenFile` | `"tokens.json"` | Token file name |
| `updateInterval` | `30000` (30s) | Image rotation interval (ms) |
| `syncInterval` | `600000` (10min) | Nextcloud sync interval (ms) |
| `transitionDuration` | `2000` (2s) | Crossfade duration (ms) |
| `backgroundSize` | `"cover"` | `cover` = fill screen, `contain` = fit entire image |
| `order` | `"random"` | `random` or `sequential` |
| `opacity` | `1.0` | Background opacity (0.0 - 1.0) |
| `maxWidth` | `1920` | Max image width for resize (px) |
| `maxHeight` | `1080` | Max image height for resize (px) |
| `imageQuality` | `80` | JPEG quality after resize (1-100) |

## Remote Setup

If your Pi is not on the same network as your browser:

**Option A: Run setup locally, then copy the token**

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

**Option B: SSH tunnel**

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

## Troubleshooting

| Problem | Solution |
|---------|----------|
| "Tokens not found" error | Run `bash setup.sh` or `node setup_oauth.js` again |
| "Token refresh failed" | Re-run the setup script to get a new token |
| Images not showing | Check that photos exist in the Nextcloud folder, check logs with `pm2 logs magicmirror` |
| After `git pull` not working | Run `sudo chown -R $(whoami):$(whoami) ~/MagicMirror/modules/MMM-NextcloudPhotos/` |

## Performance Notes

On low-memory devices (Raspberry Pi 3 with ~900MB RAM), the module automatically:
- Resizes downloaded images to 1920x1080 using `sharp`
- Compresses to progressive JPEG (quality 80)
- Limits `sharp` concurrency to 1 thread
- Cleans up preloaded images from memory after display

A 12MB photo is typically reduced to ~200-300KB, preventing out-of-memory freezes.

## Finding Your Nextcloud Username

If you log in via an OIDC provider (e.g., Authentik, Keycloak), your username may differ from your display name (e.g., `oidc-abc123...`).

To find it:
1. Log in to Nextcloud in your browser
2. Go to **Settings**
3. Your username is visible in the URL: `https://cloud.example.com/settings/user/YOUR_USERNAME`

## License

MIT
