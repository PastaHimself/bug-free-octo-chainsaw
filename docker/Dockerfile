FROM ubuntu:22.04

ARG BLOCKBENCH_DEB_URL=""
ARG MCP_PLUGIN_URL="https://jasonjgardner.github.io/blockbench-mcp-plugin/mcp.js"

ENV DEBIAN_FRONTEND=noninteractive
ENV HOME=/home/container

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        dbus-user-session \
        dbus-x11 \
        fluxbox \
        jq \
        libasound2 \
        libatk-bridge2.0-0 \
        libatk1.0-0 \
        libcups2 \
        libdrm2 \
        libgbm1 \
        libgtk-3-0 \
        libnss-wrapper \
        libnss3 \
        libsecret-1-0 \
        libx11-xcb1 \
        libxcomposite1 \
        libxdamage1 \
        libxfixes3 \
        libxkbcommon0 \
        libxrandr2 \
        libxshmfence1 \
        libxss1 \
        libxtst6 \
        novnc \
        procps \
        python3 \
        python3-numpy \
        websockify \
        wget \
        x11vnc \
        xauth \
        xvfb \
        xz-utils \
    && rm -rf /var/lib/apt/lists/*

RUN set -eux; \
    if [ -n "$BLOCKBENCH_DEB_URL" ]; then \
        deb_url="$BLOCKBENCH_DEB_URL"; \
    else \
        release_json="$(mktemp)"; \
        curl -fsSL https://api.github.com/repos/JannisX11/blockbench/releases/latest -o "$release_json"; \
        deb_url="$(python3 -c 'import json,sys; assets=json.load(open(sys.argv[1])).get("assets", []); bad=("arm64","aarch64","armv7","armhf","i386","i686","ia32","win","windows","mac","darwin"); debs=[(str(a.get("name", "")).lower(), a.get("browser_download_url")) for a in assets if a.get("browser_download_url") and str(a.get("name", "")).lower().endswith(".deb")]; preferred=[item for item in debs if any(token in item[0] for token in ("amd64","x86_64","x64"))]; generic=[item for item in debs if not any(token in item[0] for token in bad)]; matches=preferred or generic; print(matches[0][1] if matches else "")' "$release_json")"; \
        rm -f "$release_json"; \
    fi; \
    test -n "$deb_url"; \
    wget -O /tmp/blockbench.deb "$deb_url"; \
    apt-get update; \
    apt-get install -y /tmp/blockbench.deb; \
    rm -f /tmp/blockbench.deb; \
    rm -rf /var/lib/apt/lists/*

RUN mkdir -p /opt/blockbench-mcp-plugin \
    && curl -fsSL "$MCP_PLUGIN_URL" -o /opt/blockbench-mcp-plugin/mcp.js

RUN useradd -m -d /home/container -s /bin/bash container \
    && mkdir -p /home/container/mcp-plugin /home/container/.config/Blockbench /home/container/logs \
    && chown -R container:container /home/container /opt/blockbench-mcp-plugin

COPY docker/start-blockbench-mcp.sh /usr/local/bin/start-blockbench-mcp.sh
RUN chmod +x /usr/local/bin/start-blockbench-mcp.sh

USER container
WORKDIR /home/container

CMD ["/usr/local/bin/start-blockbench-mcp.sh"]
