# proton_enshrouded (Proton GE 11)

Pterodactyl yolk for the **Enshrouded dedicated server** (Steam app `2278520`,
Windows-only binary) running under Proton on Linux.

Image: `ghcr.io/evlbox/steamcmd:proton_ge11` (also tagged `latest`).

## What's included

- **GE-Proton 11-9** — provides the Steamworks SDK interfaces (`SteamUtils011`)
  required by the Enshrouded 1.0 server build.
- **steamcmd** — bundled at `/usr/local/steamcmd`, self-updated at build and
  refreshed on boot; its `linux32`/`linux64` `steamclient.so` are copied into
  `/home/container/.steam/sdk32` and `.steam/sdk64` every boot.
- **`libvulkan1` + `libfreetype6`** — Vulkan loader and FreeType (silences the
  Wine FreeType warning).
- **Self-contained virtual display**: the server binary needs a display to
  attach to (SDL/X11). Without one it silently stalls before its first log line.
  `entrypoint.sh` starts a container-local `Xvfb` on `${DISPLAY}` (default `:99`),
  so the host needs no X/Wayland. `PROTON_USE_XALIA=0` additionally stops the
  Xalia gamepad helper from crashing/hanging.
- fsync/esync are **enabled** (not disabled).

## Why this image exists

`ghcr.io/parkervcp/steamcmd:proton` (GE-Proton11-7) fails on Enshrouded 1.0 with:

1. An intermittent silent stall (0% CPU, no log file) after `fsync: up and
   running.` — the binary needs a display to attach to and hangs before writing
   its first log line when there is none. A container-local `Xvfb` (plus
   `PROTON_USE_XALIA=0` for the Xalia helper) removes the stall entirely.
2. `[steam] Failed to initialize Steamworks system... Version Mismatch / No SteamUtils011`
   — the Steamworks SDK was bumped in 1.0; Proton's shim and the bundled native
   `steamclient.so` were too old.

Both are addressed here (`GE-Proton 11-9` + refreshed native Steam SDK + Xvfb).

After boot the server also opens an online session (`[Session] 'HostOnline' (up)!`),
which needs outbound access to Steam's connection-manager ports (27015-27050). If
those are blocked, the server still runs but logs
`[online] Server failed to connected to Steam`. Open the Steam CM port range on
the node/firewall for the server to appear online.

## Environment variables

| Variable | Default | Description |
|----------|---------|-------------|
| `SRCDS_APPID` | — | **Required.** Steam app id (`2278520` for Enshrouded). |
| `SRCDS_BETAID` | — | Optional Steam beta branch (`-beta`). |
| `SRCDS_BETAPASS` | — | Optional beta branch password (`-betapassword`). |
| `WINDOWS_INSTALL` | — | `1` to force the Windows platform (`+@sSteamCmdForcePlatformType windows`). |
| `STEAM_SDK` | — | `1` to also install Steamworks SDK redist (`+app_update 1007`). |
| `AUTO_UPDATE` | unset | Unset or `1` runs the steamcmd update before starting. `0` skips it. |
| `VALIDATE` | — | `1` to validate the app files. |
| `STEAM_USER` | `anonymous` | Steam login user. |
| `STEAM_PASS` | — | Steam password. |
| `STEAM_AUTH` | — | Steam 2FA code. |
| `TZ` | `UTC` | Container timezone. |
| `STARTUP` | — | Startup command (with `{{VAR}}` placeholders). |
| `STEAMCMD_PATH` | auto | Override the steamcmd script path. Auto-resolves to `/home/container/steamcmd/steamcmd.sh` if present, else `/usr/local/steamcmd/steamcmd.sh`. |
| `PROTON_USE_XALIA` | `0` | Disables Xalia (required headless). |
| `PROTON_LOG_DIR` | `/home/container` | Where Proton writes its log. |
| `DISPLAY` | `:99` | X display the entrypoint starts (Xvfb) for the server to attach to. |

## Pterodactyl egg usage

```json
{
  "docker_images": {
    "EVLBOX Proton GE 11": "ghcr.io/evlbox/steamcmd:proton_ge11"
  }
}
```

Startup line:

```bash
rm -f ./logs/enshrouded_server.log; proton run ./enshrouded_server.exe & ENS_PID=$! ; tail -c0 -F ./logs/enshrouded_server.log --pid=$ENS_PID
```

> Note: because the log is removed first, `tail -F` returns a non-zero status
> when the server stops, so the container exits non-zero on a normal shutdown.
> This is expected and does not indicate a crash.

## Building

```bash
docker build -t ghcr.io/evlbox/steamcmd:proton_ge11 steamcmd/proton_enshrouded
docker push ghcr.io/evlbox/steamcmd:proton_ge11
```

The GE-Proton tarball is downloaded and sha512-verified in a dedicated build
stage, so it is cached until `GE_PROTON_VERSION`/`GE_PROTON_SHA512` change.

CI publishes to GHCR on every push to `main` that touches this folder. The
package is private by default — make `ghcr.io/evlbox/steamcmd` public, or grant
the Pterodactyl node access, before the egg can pull it.

## Acceptance test

Requires a Docker host with network access (Steam CDN + GitHub for the
download, and Steam CM ports 27015-27050 for the online session) and ~25 GB free
disk. The server is **downloaded once**; a "cold start" below means starting the
game server process **5 separate times**, reusing the same populated volume (no
re-download).

The startup is self-contained: no host display is needed because `entrypoint.sh`
starts its own Xvfb.

```bash
docker build -t ghcr.io/evlbox/steamcmd:proton_ge11 steamcmd/proton_enshrouded
mkdir -p /tmp/ens-data
# The image runs as uid 999 (Pterodactyl convention). On a real node Wings owns
# the mount; for a local bind mount, hand it to uid 999 so the server can write.
chown -R 999:999 /tmp/ens-data

# 1) Download the Steamworks SDK redist + the Enshrouded dedicated server (once).
docker run --rm -v /tmp/ens-data:/home/container \
  -e SRCDS_APPID=2278520 -e WINDOWS_INSTALL=1 -e STEAM_SDK=1 -e AUTO_UPDATE=1 \
  -e STARTUP='echo download-only' \
  ghcr.io/evlbox/steamcmd:proton_ge11
# -> steamcmd logs must show App '1007' and App '2278520' installed.

# 2) 5 cold starts against the populated volume (AUTO_UPDATE=0 -> no re-download).
for i in 1 2 3 4 5; do
  docker run -d --name ens-test -v /tmp/ens-data:/home/container \
    -e SRCDS_APPID=2278520 -e AUTO_UPDATE=0 \
    -e STARTUP='rm -f ./logs/enshrouded_server.log; proton run ./enshrouded_server.exe & ENS_PID=$! ; tail -c0 -F ./logs/enshrouded_server.log --pid=$ENS_PID' \
    ghcr.io/evlbox/steamcmd:proton_ge11

  # wait up to 60s for the server to write its "HostOnline" log line
  for t in $(seq 1 60); do
    grep -q "HostOnline" /tmp/ens-data/logs/enshrouded_server.log 2>/dev/null && break
    sleep 1
  done

  grep -q "\[Session\] 'HostOnline' (up)!" /tmp/ens-data/logs/enshrouded_server.log \
    && echo "cold start $i: HostOnline OK" \
    || echo "cold start $i: FAILED"

  grep -qi "Version Mismatch" /tmp/ens-data/logs/enshrouded_server.log \
    && echo "cold start $i: Version Mismatch present - FAIL" \
    || echo "cold start $i: no Version Mismatch (ok)"

  docker exec ens-test bash -lc 'ps -ef | grep -i xalia | grep -v grep' \
    && echo "cold start $i: xalia launched - FAIL" \
    || echo "cold start $i: no xalia (ok)"

  docker rm -f ens-test >/dev/null
done

# 3) Kill the very first boot mid-prefix, then restart and confirm recovery.
rm -rf /tmp/ens-data/.steam/steam/steamapps/compatdata/2278520
docker run -d --name ens-k -v /tmp/ens-data:/home/container \
  -e SRCDS_APPID=2278520 -e AUTO_UPDATE=0 \
  -e STARTUP='rm -f ./logs/enshrouded_server.log; proton run ./enshrouded_server.exe & ENS_PID=$! ; tail -c0 -F ./logs/enshrouded_server.log --pid=$ENS_PID' \
  ghcr.io/evlbox/steamcmd:proton_ge11
sleep 20 && docker kill ens-k && docker rm -f ens-k
docker run -d --name ens-r -v /tmp/ens-data:/home/container \
  -e SRCDS_APPID=2278520 -e AUTO_UPDATE=0 \
  -e STARTUP='rm -f ./logs/enshrouded_server.log; proton run ./enshrouded_server.exe & ENS_PID=$! ; tail -c0 -F ./logs/enshrouded_server.log --pid=$ENS_PID' \
  ghcr.io/evlbox/steamcmd:proton_ge11
# must still reach "Game Version (SVN):" within 60s
```

Pass criteria:

- steamcmd reports App `1007` and App `2278520` installed.
- Console prints `fsync: up and running.`
- Within ~60s `/home/container/logs/enshrouded_server.log` contains
  `Game Version (SVN):` and `[Session] 'PrepareGame' (up)!`/`'HostOnline' (up)!`,
  and no `Version Mismatch` line.
- No cold start stalls before the log is written (log created within 60s), and
  the killed-mid-prefix restart recovers.
- No `xalia.exe` process is launched.

> Note: `[Session] 'HostOnline' (up)!` additionally requires the server to reach
> Steam's connection managers (ports 27015-27050). In a network that blocks those
> ports the run still boots and loads the world (`Game Version (SVN): 1267041`,
> `PrepareGame (up)!`) but logs `[online] Server failed to connected to Steam`.

## Versioning

| Tag | Description |
|-----|-------------|
| `proton_ge11` | GE-Proton 11.x runtime (Enshrouded 1.0 fix) |
| `latest` | Same as `proton_ge11` |

To bump Proton, update `GE_PROTON_VERSION` (and `GE_PROTON_SHA512`) in the
`Dockerfile` and push to `main`; CI republishes the tags.
