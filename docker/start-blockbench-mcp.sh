#!/usr/bin/env bash
set -euo pipefail

export HOME="${HOME:-/home/container}"
export DISPLAY_NUMBER="${DISPLAY_NUMBER:-1}"
export DISPLAY=":${DISPLAY_NUMBER}"
export DISPLAY_WIDTH="${DISPLAY_WIDTH:-1280}"
export DISPLAY_HEIGHT="${DISPLAY_HEIGHT:-720}"
export NOVNC_PORT="${NOVNC_PORT:-${SERVER_PORT:-8080}}"
export MCP_PORT="${MCP_PORT:-3000}"
export MCP_ENDPOINT="${MCP_ENDPOINT:-/bb-mcp}"
VNC_PASSWORD_VALUE="${VNC_PASSWORD:-McpVnc26}"
unset VNC_PASSWORD

if [ "${#VNC_PASSWORD_VALUE}" -ne 8 ]; then
  echo "ERROR: VNC_PASSWORD must be exactly 8 characters because standard VNC authentication only uses 8 characters."
  exit 1
fi

mkdir -p "$HOME/.vnc" "$HOME/mcp-plugin" "$HOME/.config/Blockbench" "$HOME/logs"

if [ -f /opt/blockbench-mcp-plugin/mcp.js ]; then
  cp /opt/blockbench-mcp-plugin/mcp.js "$HOME/mcp-plugin/mcp.js"
fi

cat > "$HOME/README-FIRST-RUN.txt" <<TXT
Blockbench MCP noVNC is running.

Open noVNC on this server's web allocation.

Important readiness note:
- Pterodactyl marks this server ready when noVNC is available.
- The MCP endpoint does not exist until the MCP plugin is loaded inside Blockbench.

Inside Blockbench:
1. File > Plugins > Load Plugin from File.
2. Select: $HOME/mcp-plugin/mcp.js
3. Allow network access if prompted.
4. Settings > General:
   MCP Server Port: $MCP_PORT
   MCP Server Endpoint: $MCP_ENDPOINT

Pterodactyl MCP_PORT and MCP_ENDPOINT are expected/manual values only.
They do not automatically rewrite Blockbench settings. Set the same values in Blockbench.

MCP URL inside this container/VPS network after the plugin loads:
http://localhost:$MCP_PORT$MCP_ENDPOINT

Safe remote access options:
- Run the MCP client inside the same VPS/container network.
- Use SSH tunnel, Tailscale, ZeroTier, or a VPN.
- Use a secondary Pterodactyl allocation for MCP only if protected by private networking or authentication.

Do not expose the MCP endpoint publicly without VPN, SSH tunnel, Tailscale, ZeroTier, or an authenticated reverse proxy.
TXT

VNC_PASSWORD_FILE="$HOME/.vnc/passwd"
rm -f "$VNC_PASSWORD_FILE"
printf '%s\n%s\ny\n' "$VNC_PASSWORD_VALUE" "$VNC_PASSWORD_VALUE" | x11vnc -storepasswd "$VNC_PASSWORD_FILE" >/dev/null 2>&1
unset VNC_PASSWORD_VALUE
chmod 600 "$VNC_PASSWORD_FILE"

cleanup() {
  jobs -p | xargs -r kill 2>/dev/null || true
}
trap cleanup EXIT INT TERM

wait_for_tcp() {
  local host="$1"
  local port="$2"
  local label="$3"
  local timeout_seconds="${4:-30}"

  for _ in $(seq 1 "$timeout_seconds"); do
    if python3 - "$host" "$port" <<'PY' >/dev/null 2>&1
import socket
import sys
host = sys.argv[1]
port = int(sys.argv[2])
with socket.create_connection((host, port), timeout=1):
    pass
PY
    then
      return 0
    fi
    sleep 1
  done

  echo "ERROR: ${label} did not open ${host}:${port} within ${timeout_seconds} seconds."
  return 1
}

wait_for_file() {
  local path="$1"
  local label="$2"
  local timeout_seconds="${3:-30}"

  for _ in $(seq 1 "$timeout_seconds"); do
    if [ -S "$path" ] || [ -e "$path" ]; then
      return 0
    fi
    sleep 1
  done

  echo "ERROR: ${label} did not create ${path} within ${timeout_seconds} seconds."
  return 1
}

Xvfb "$DISPLAY" -screen 0 "${DISPLAY_WIDTH}x${DISPLAY_HEIGHT}x24" -ac +extension GLX +render -noreset >"$HOME/logs/xvfb.log" 2>&1 &
wait_for_file "/tmp/.X11-unix/X${DISPLAY_NUMBER}" "Xvfb X11 Unix socket" 20

fluxbox >"$HOME/logs/fluxbox.log" 2>&1 &
sleep 1

x11vnc \
  -display "$DISPLAY" \
  -forever \
  -shared \
  -rfbport 5900 \
  -rfbauth "$VNC_PASSWORD_FILE" \
  -o "$HOME/logs/x11vnc.log" \
  -bg

wait_for_tcp "127.0.0.1" "5900" "x11vnc" 20

websockify \
  --web=/usr/share/novnc/ \
  "$NOVNC_PORT" \
  localhost:5900 \
  >"$HOME/logs/novnc.log" 2>&1 &

wait_for_tcp "127.0.0.1" "$NOVNC_PORT" "noVNC/websockify" 30

echo "noVNC ready"
echo "noVNC: http://0.0.0.0:${NOVNC_PORT}/vnc.html"
echo "MCP after manual plugin load: http://localhost:${MCP_PORT}${MCP_ENDPOINT}"
echo "Plugin file: ${HOME}/mcp-plugin/mcp.js"

BLOCKBENCH_FLAGS=(
  --no-sandbox
  --disable-gpu
  --disable-dev-shm-usage
  --disable-software-rasterizer
  --disable-features=UseOzonePlatform
)

while true; do
  echo "Starting Blockbench at $(date -Iseconds)" >>"$HOME/logs/blockbench.log"
  if command -v dbus-run-session >/dev/null 2>&1; then
    dbus-run-session -- blockbench "${BLOCKBENCH_FLAGS[@]}" >>"$HOME/logs/blockbench.log" 2>&1 || true
  else
    blockbench "${BLOCKBENCH_FLAGS[@]}" >>"$HOME/logs/blockbench.log" 2>&1 || true
  fi
  echo "Blockbench exited at $(date -Iseconds); restarting in 5 seconds." | tee -a "$HOME/logs/blockbench.log"
  sleep 5
done
