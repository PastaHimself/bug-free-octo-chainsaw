# Blockbench MCP Pterodactyl package

This package gives you a Pterodactyl egg and a Docker build context for running Blockbench desktop on a VPS through noVNC, then loading the Blockbench MCP plugin inside that desktop session.

## What this runs

- Ubuntu 22.04
- Xvfb virtual display
- Fluxbox window manager
- x11vnc with an auth file
- noVNC/websockify
- Blockbench desktop
- The Blockbench MCP plugin file saved at `/home/container/mcp-plugin/mcp.js`

The MCP endpoint only exists after the plugin is loaded inside Blockbench. Pterodactyl readiness means **noVNC is ready and the noVNC port is listening**, not that the MCP server is already active.

## Files

- `pterodactyl/egg-blockbench-mcp-novnc.json`
- `docker/Dockerfile`
- `docker/start-blockbench-mcp.sh`
- `.github/workflows/publish-ghcr.yml`
- `client-configs/vscode-mcp.json`
- `client-configs/claude_desktop_config.json`

## GitHub setup

Run the included GitHub Actions workflow:

```text
Actions > Build and publish Blockbench MCP Pterodactyl image > Run workflow
```

It publishes this image:

```text
ghcr.io/pastahimself/blockbench-mcp-pterodactyl:latest
```

The workflow lowercases the GitHub owner name before publishing so the image name matches the egg JSON.

## Optional Docker build pinning

By default, the Dockerfile downloads the latest Linux `.deb` from the official GitHub releases and the hosted MCP plugin file. It prefers amd64/x64 `.deb` assets and falls back to a generic `.deb` only when no amd64/x64 asset is present.

For reproducible builds, pass these build args in your own Docker build workflow:

```text
BLOCKBENCH_DEB_URL=https://github.com/JannisX11/blockbench/releases/download/<version>/<blockbench-linux-amd64.deb>
MCP_PLUGIN_URL=https://jasonjgardner.github.io/blockbench-mcp-plugin/mcp.js
```

`BLOCKBENCH_DEB_URL` must point directly to a Linux amd64 `.deb` asset.

## Pterodactyl setup

1. Open Pterodactyl Admin Panel.
2. Go to `Nests`.
3. Create or select a Nest, for example `Desktop Apps`.
4. Import `pterodactyl/egg-blockbench-mcp-novnc.json`.
5. Create a server with that egg.
6. Give it at least:
   - 2 GB RAM
   - 2 CPU threads if available
   - 4 GB disk
7. Allocate one primary port for noVNC. The egg listens on `{{SERVER_PORT}}`.
8. Add another allocation for MCP only if your MCP client is outside the container/VPS network and you can protect that allocation with private networking, VPN, SSH tunnel, or an authenticated proxy.

## First boot

Open noVNC in your browser from the Pterodactyl allocation.

Inside Blockbench:

```text
File > Plugins > Load Plugin from File
```

Select:

```text
/home/container/mcp-plugin/mcp.js
```

Then check:

```text
Settings > General > MCP Server Port = 3000
Settings > General > MCP Server Endpoint = /bb-mcp
```

The egg variables named `Expected MCP Port` and `Expected MCP Endpoint` only change the printed first-run instructions. They do **not** automatically rewrite Blockbench settings. Set the same values manually inside Blockbench.

The MCP URL from inside the same container/VPS network is:

```text
http://localhost:3000/bb-mcp
```

## MCP access modes

Use one of these modes:

```text
1. Same container/VPS network
   Run the MCP client on the same VPS or in a network path where localhost/container networking resolves correctly.

2. Private tunnel
   Use SSH tunnel, Tailscale, ZeroTier, or a VPN to reach the MCP port safely.

3. Secondary Pterodactyl allocation
   Map the MCP port only when you can restrict access with private networking or authentication.
```

Do not treat `localhost:3000` on your phone or laptop as the VPS container. On your phone/laptop, `localhost` means your phone/laptop, not the VPS.

## Security

Do not expose the MCP endpoint directly to the public internet.

Use one of these:

```text
SSH tunnel
Tailscale
ZeroTier
VPN
authenticated reverse proxy
```

The noVNC password variable defaults to:

```text
McpVnc26
```

Change it before exposing noVNC beyond a private network. Standard VNC authentication uses exactly 8 characters, so the egg enforces an 8-character password to avoid silent truncation or startup failure. At runtime, the startup script writes the password to `$HOME/.vnc/passwd`, starts x11vnc with `-rfbauth`, and removes the password from the environment before starting x11vnc so the password is not passed in the long-running x11vnc process arguments.

## Client configs

VS Code config is in:

```text
client-configs/vscode-mcp.json
```

Claude Desktop config is in:

```text
client-configs/claude_desktop_config.json
```

### Black noVNC desktop / Blockbench restarts

If noVNC opens to a black Fluxbox desktop but Blockbench does not appear, check `logs/blockbench.log` from the Pterodactyl Files tab. The startup script launches Blockbench with Electron container flags (`--no-sandbox`, `--disable-gpu`, `--disable-dev-shm-usage`, `--disable-software-rasterizer`, and `--disable-features=UseOzonePlatform`) and appends each crash/restart to that log.

The Xvfb readiness check uses `/tmp/.X11-unix/X1`; this is intentional because Xvfb commonly exposes a Unix socket instead of opening TCP port `127.0.0.1:6001` inside containers.
