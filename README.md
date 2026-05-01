# *arr stack homelab

A containerized media automation stack: torrent downloads go through a VPN (Gluetun), and the *arr apps manage indexers, movies, music, and requests. Jellyfin (or another player) can use the same media folders on the host.

## What runs in this stack

| Service      | Role |
|-------------|------|
| **Gluetun** | VPN (ProtonVPN WireGuard). All torrent traffic from qBittorrent goes through it. |
| **qBittorrent** | Download client. Runs inside Gluetun’s network so only torrent traffic is behind the VPN. |
| **Prowlarr** | Indexer manager. Syncs indexers to Radarr and Lidarr. |
| **Radarr** | Movie library and automation (search, send to qBittorrent, import to Movies). |
| **Lidarr** | Music library and automation (same idea for music). |
| **Seerr** | Request UI: users request content; Seerr talks to Jellyfin and Radarr/Lidarr. |

Media is stored under a single base path on the host (`MEDIA_DIR`). The same path can be used as the library root in Jellyfin (or any player) for playback.

---

## Prerequisites

- **OrbStack** (or another Docker-compatible engine). Install: `brew install orbstack` or from [orbstack.dev](https://orbstack.dev). Start the OrbStack app before running the stack.
- **ProtonVPN** (or another provider supported by Gluetun). You need a WireGuard config: private key and, for ProtonVPN, the client address (e.g. from the ProtonVPN WireGuard config file).
- **Terminal** access to create directories and run `docker compose`.

---

## Directory layout

All app config and media live under one base directory, `MEDIA_DIR`, that you set in `.env`. The stack expects these paths to exist (you can create them before first run):

```
config/
  qbittorrent/
  prowlarr/
  radarr/
  lidarr/
  seerr/
MEDIA_DIR/
  Downloads/     # incomplete + complete torrents
  Movies/       # final movie files (e.g. for Jellyfin)
  Shows/        # TV (if you add Sonarr later)
  Music/        # final music files
```

Example: if your media is on an external drive mounted at `/Volumes/MyDrive`, set `MEDIA_DIR=/Volumes/MyDrive/Media` and create the folders above under it.

---

## Setup

### 1. Copy environment file

```bash
cp .env.example .env
```

Edit `.env` and set at least:

- **MEDIA_DIR** – Base path for media.
- **CONFIG_DIR** – Base path for config.
- **PUID** / **PGID** – Your user and group ID so container-created files are owned by you. Run `id -u` and `id -g` and put the numbers here (e.g. 501 and 20 on macOS).
- **TIMEZONE** – IANA timezone (e.g. `Europe/Berlin`, `America/New_York`).
- **WIREGUARD_PRIVATE_KEY** – From your ProtonVPN WireGuard config.
- **SEERR_BIND_ADDRESS** – `127.0.0.1` to allow only local access to Seerr, or `0.0.0.0` to allow access from other devices on your LAN.

Do not commit `.env`; it is listed in `.gitignore`.

### 2. Create directories

Create the config and media folders so they exist before the first run (avoids root-owned directories):

```bash
MEDIA_DIR="/path/to/your/Media"
CONFIG_DIR="/path/to/your/config"

mkdir -p "${CONFIG_DIR}/qbittorrent" "${CONFIG_DIR}/prowlarr" "${CONFIG_DIR}/radarr" "${CONFIG_DIR}/lidarr" "${CONFIG_DIR}/seerr"

mkdir -p "${MEDIA_DIR}/Downloads" "${MEDIA_DIR}/Movies" "${MEDIA_DIR}/Shows" "${MEDIA_DIR}/Music"
```

### 3. Start the stack

From the project directory:

```bash
docker compose up -d
```

Check that all containers are up:

```bash
docker compose ps
```

If Gluetun or qBittorrent fails, check logs:

```bash
docker compose logs gluetun
docker compose logs qbittorrent
```
---

## Web UIs and ports

| App         | URL                     
|------------|-------------------------|
| qBittorrent | http://localhost:8080   
| Prowlarr   | http://localhost:9696   |
| Radarr     | http://localhost:7878   |
| Lidarr     | http://localhost:8686   |
| Seerr      | http://127.0.0.1:5055   |

---

## Stopping and updating

- Stop everything: `docker compose down`
- Stop but keep data: `docker compose stop`
- Update images and restart: `docker compose pull && docker compose up -d`

Data lives in `MEDIA_DIR`; removing containers with `docker compose down` does not delete your config or media.

## Personal site deploys

`mynkie.com` is served directly by the homelab nginx container from `MYNKIE_SITE_DIR/current`. The `mynkie-site` container is a one-shot publisher: it copies `/usr/share/nginx/html` out of the latest `ghcr.io/therealminhduc/mynkie:latest` image into a timestamped release directory, then points `current` at that release.

Watchtower watches `mynkie-site` with `--include-stopped --revive-stopped`, so pushing a new blog image publishes static files without restarting nginx. For a manual deploy, run:

```bash
./scripts/deploy.sh
```

If `mynkie.com` or `docs.mynkie.com` returns Cloudflare `404` while `jellyfin.mynkie.com` works, make sure the Cloudflare Tunnel has public hostnames for all three names and restart `cloudflared` so it reloads `cloudflared/config.yml`.
