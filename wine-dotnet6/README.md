# wine-dotnet6

Wine 11.0 with .NET 6 Desktop Runtime pre-installed in a template Wine prefix.

## What's Included

- **Wine 11.0** — Windows API compatibility layer
- **.NET 6 Desktop Runtime** — v6.0.36, required by MelonLoader mods and Unity games
- **Pre-built Winetricks cache** — no network download on first boot

## How It Works

The .NET 6 runtime is installed into `/home/.wine-dotnet6` during image build. At runtime, Pterodactyl eggs copy this template prefix to the server's data volume on first startup. Subsequent starts skip the copy.

## Usage in Eggs

```json
{
  "docker_images": {
    "Wine + .NET 6": "ghcr.io/evlbox/wine-dotnet6:latest"
  }
}
```

Startup command should check for and copy the prefix:

```bash
if ! find /home/container/.wine/drive_c -name hostfxr.dll ...; then
    cp -r /home/.wine-dotnet6 /home/container/.wine
fi
```

## Versioning

| Tag | Description |
|-----|-------------|
| `latest` | Current build |

To force Pterodactyl to pull a new version, increment the tag:

```bash
docker build -t ghcr.io/evlbox/wine-dotnet6:v2 .
docker push ghcr.io/evlbox/wine-dotnet6:v2
```
