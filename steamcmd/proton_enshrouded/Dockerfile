# ---------------------------------------------
# EVLBOX Enshrouded yolk (Proton GE 11)
# ---------------------------------------------
# Runs the Windows-only Enshrouded dedicated server (Steam app 2278520) under
# Proton on Linux. Fixed for the Enshrouded 1.0 release:
#   * GE-Proton 11-9 (Steamworks SDK / SteamUtils011 support)
#   * libvulkan1 + libfreetype6
#   * refreshed native Steam SDK libs (linux32/linux64 steamclient.so)
#   * PROTON_USE_XALIA=0 (headless: Xalia needs an SDL video driver)
#   * a self-contained virtual X display (Xvfb) -- the server binary needs a
#     display to attach to, otherwise it silently stalls before its first log line

# --- Stage 1: fetch + verify + unpack GE-Proton (cached) --------------------
FROM debian:trixie-slim AS proton

ARG GE_PROTON_VERSION=11-9
ARG GE_PROTON_SHA512=30160946a5e4ffdf1f29d6f83a3d27108f6aa71b6aa59095b2c2260fe3a003b62acf8fdcb02a3dfc602b28473f5679d8a3eaee5a8adb141c1dfa01c42888da2d

RUN apt-get update \
 && apt-get install -y --no-install-recommends curl ca-certificates \
 && rm -rf /var/lib/apt/lists/*

RUN curl -fSL --retry 3 -o /tmp/ge-proton.tar.gz \
      "https://github.com/GloriousEggroll/proton-ge-custom/releases/download/GE-Proton${GE_PROTON_VERSION}/GE-Proton${GE_PROTON_VERSION}-x86_64.tar.gz" \
 && printf '%s  /tmp/ge-proton.tar.gz\n' "${GE_PROTON_SHA512}" | sha512sum -c - \
 && mkdir -p /proton \
 && tar -xzf /tmp/ge-proton.tar.gz -C /proton --strip-components=1 \
 && rm /tmp/ge-proton.tar.gz \
 && test -x /proton/proton \
 && grep -q SteamUtils011 /proton/files/lib/wine/x86_64-unix/lsteamclient.so

# --- Stage 2: bundle + self-update steamcmd ---------------------------------
FROM debian:trixie-slim AS steamcmd

# steamcmd itself is a 32-bit binary, so it needs i386 libs to bootstrap.
RUN dpkg --add-architecture i386 \
 && apt-get update \
 && apt-get install -y --no-install-recommends \
      curl ca-certificates tar gzip \
      lib32gcc-s1 lib32stdc++6 libc6:i386 \
 && rm -rf /var/lib/apt/lists/* \
 && mkdir -p /usr/local/steamcmd \
 && curl -fSL --retry 3 -o /tmp/steamcmd.tar.gz \
      https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz \
 && tar -xzf /tmp/steamcmd.tar.gz -C /usr/local/steamcmd \
 && rm /tmp/steamcmd.tar.gz \
 && /usr/local/steamcmd/steamcmd.sh +quit \
 && test -f /usr/local/steamcmd/linux32/steamclient.so \
 && test -f /usr/local/steamcmd/linux64/steamclient.so

# --- Stage 3: runtime -------------------------------------------------------
FROM debian:trixie-slim

LABEL author="EVLBOX" maintainer="evlbox" \
      org.opencontainers.image.source="https://github.com/EVLBOX/yolks" \
      org.opencontainers.image.licenses=MIT

ENV DEBIAN_FRONTEND=noninteractive

RUN dpkg --add-architecture i386 \
 && apt-get update \
 && apt-get install -y --no-install-recommends \
      wget \
      iproute2 \
      gnupg2 \
      libntlm0 \
      winbind \
      libncurses-dev:i386 \
      libncurses6 \
      dbus \
      libgdiplus \
      lib32gcc-s1 \
      libc6 \
      alsa-tools \
      libpulse0 \
      libpulse-dev \
      libasound2-dev \
      libao-common \
      gnutls-bin \
      gnupg \
      locales \
      cabextract \
      curl \
      ca-certificates \
      python3 \
      python3-pip \
      python3-setuptools \
      tini \
      file \
      pipx \
      tar \
      gzip \
      libvulkan1 \
      libfreetype6 \
      libfreetype6:i386 \
      xvfb \
      xauth \
      x11-utils \
 && rm -rf /var/lib/apt/lists/*

# Proton fix machine-id
RUN rm -f /etc/machine-id \
 && dbus-uuidgen --ensure=/etc/machine-id \
 && rm -f /var/lib/dbus/machine-id \
 && dbus-uuidgen --ensure

# Populate the Proton toolchain (so `proton` resolves as a bare verb)
COPY --from=proton   /proton             /usr/local/bin
# Bundled, freshly-updated steamcmd (self-updates in place at runtime)
COPY --from=steamcmd /usr/local/steamcmd /usr/local/steamcmd

# Headless defaults. fsync/esync stay enabled (do not set PROTON_NO_FSYNC/ESYNC).
# DISPLAY points at the container-local Xvfb started by entrypoint.sh.
ENV STEAMCMD_PATH=/usr/local/steamcmd/steamcmd.sh \
    PROTON_USE_XALIA=0 \
    PROTON_LOG_DIR=/home/container \
    DISPLAY=:99

# uid 999 / gid convention used by Pterodactyl game images
RUN useradd -u 999 -m -d /home/container -s /bin/bash container \
 && chown -R container:container /usr/local/steamcmd

USER        container
ENV         USER=container HOME=/home/container
WORKDIR     /home/container

STOPSIGNAL  SIGINT

COPY        --chown=container:container entrypoint.sh /entrypoint.sh
RUN         chmod +x /entrypoint.sh
ENTRYPOINT  ["/usr/bin/tini", "-g", "--"]
CMD         ["/entrypoint.sh"]
