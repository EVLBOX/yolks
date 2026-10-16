# EVLBOX Yolks 🥚

Pre-configured Docker images for EVLBOX Pterodactyl game server eggs.

## What are Yolks?

In Pterodactyl, an **egg** imports a **yolk** — the Docker image that provides the runtime environment for the game server. These images come pre-installed with all dependencies needed to run Windows games on Linux via Wine.

## Images

| Image | Base | Extras | Pull |
|-------|------|--------|------|
| `evlbox/wine-dotnet6` | `wine_latest` (Wine 11.0) | .NET 6 Desktop Runtime | `docker pull ghcr.io/evlbox/wine-dotnet6:latest` |
| `evlbox/steamcmd` | `debian:trixie-slim` | GE-Proton 11-9 + steamcmd, Enshrouded 1.0 fix | `docker pull ghcr.io/evlbox/steamcmd:proton_ge11` |

## Usage

```json
{
  "docker_images": {
    "Wine + .NET 6": "ghcr.io/evlbox/wine-dotnet6:latest"
  }
}
```

## Building

Each folder contains a `Dockerfile`. Build from the folder:

```bash
docker build -t ghcr.io/evlbox/wine-dotnet6:latest wine-dotnet6/
docker push ghcr.io/evlbox/wine-dotnet6:latest
```

## License

MIT — use freely with EVLBOX Pterodactyl eggs.
