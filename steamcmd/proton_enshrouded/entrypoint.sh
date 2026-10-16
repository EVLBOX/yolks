#!/bin/bash

#
# EVLBOX Enshrouded Proton entrypoint
#
# Follows the parkervcp/ptero-eggs steamcmd:proton entrypoint conventions so
# Pterodactyl eggs written for that image work unchanged, with the Enshrouded 1.0
# fixes applied (STEAM_SDK gating, native Steam SDK refresh, virtual display so
# the binary does not stall, headless Proton env).
#

# Wait for the container to fully initialize
sleep 1

# Default the TZ environment variable to UTC.
TZ=${TZ:-UTC}
export TZ

# Set environment variable that holds the Internal Docker IP
INTERNAL_IP=$(ip route get 1 2>/dev/null | awk '{print $(NF-2);exit}')
export INTERNAL_IP

# Resolve steamcmd: explicit STEAMCMD_PATH > egg-provided volume copy > bundled image copy
if [ -z "${STEAMCMD_PATH}" ]; then
    if [ -x /home/container/steamcmd/steamcmd.sh ]; then
        STEAMCMD_PATH=/home/container/steamcmd/steamcmd.sh
    else
        STEAMCMD_PATH=/usr/local/steamcmd/steamcmd.sh
    fi
fi
STEAMCMD_DIR=$(dirname "${STEAMCMD_PATH}")
export STEAMCMD_PATH STEAMCMD_DIR

# Set environment for Steam Proton
if [ -f "/usr/local/bin/proton" ]; then
    if [ ! -z ${SRCDS_APPID} ]; then
        mkdir -p /home/container/.steam/steam/steamapps/compatdata/${SRCDS_APPID}
        export STEAM_COMPAT_CLIENT_INSTALL_PATH="/home/container/.steam/steam"
        export STEAM_COMPAT_DATA_PATH="/home/container/.steam/steam/steamapps/compatdata/${SRCDS_APPID}"
        export SteamAppId="${SRCDS_APPID}"
        export SteamGameId="${SRCDS_APPID}"
    else
        echo -e "----------------------------------------------------------------------------------"
        echo -e "WARNING!!! Proton needs variable SRCDS_APPID, else it will not work. Please add it"
        echo -e "Server stops now"
        echo -e "----------------------------------------------------------------------------------"
        exit 1
    fi
fi

# Headless Proton defaults. Do NOT disable fsync/esync.
export PROTON_USE_XALIA="${PROTON_USE_XALIA:-0}"
export PROTON_LOG_DIR="${PROTON_LOG_DIR:-/home/container}"

# The server binary needs a display to attach to. Without one it silently stalls
# before writing its first log line (0% CPU, no output after fsync). Provide a
# container-local virtual display; the host still needs no X/Wayland.
start_virtual_display() {
    export DISPLAY="${DISPLAY:-:99}"
    local display_num="${DISPLAY#:}"
    display_num="${display_num%%.*}"
    if [ -e "/tmp/.X11-unix/X${display_num}" ]; then
        echo -e "Using existing X display ${DISPLAY}."
        return 0
    fi
    echo -e "Starting virtual X display on ${DISPLAY}..."
    Xvfb "${DISPLAY}" -screen 0 1280x720x24 -nolisten tcp >/tmp/xvfb.log 2>&1 &
    local i
    for i in $(seq 1 100); do
        [ -e "/tmp/.X11-unix/X${display_num}" ] && return 0
        sleep 0.1
    done
    echo -e "WARNING: virtual display ${DISPLAY} did not come up; see /tmp/xvfb.log"
    return 1
}
start_virtual_display

# Switch to the container's working directory
cd /home/container || exit 1

# Refresh the native Steam SDK libs from the (freshly updated) steamcmd install.
copy_sdk_libs() {
    mkdir -p /home/container/.steam/sdk32 /home/container/.steam/sdk64
    local arch src dst
    for arch in 32 64; do
        src="${STEAMCMD_DIR}/linux${arch}/steamclient.so"
        dst="/home/container/.steam/sdk${arch}/steamclient.so"
        if [ -f "${src}" ]; then
            cp -f "${src}" "${dst}" && echo -e "Refreshed ${dst} from ${src}"
        else
            echo -e "WARNING: ${src} not found; leaving ${dst} as-is"
        fi
    done
}

## Update server via SteamCMD if AUTO_UPDATE is 1 or not set
if [ -z ${AUTO_UPDATE} ] || [ "${AUTO_UPDATE}" == "1" ]; then
    echo -e "Checking for game server updates..."
    # Check for set App ID
    if [ ! -z ${SRCDS_APPID} ]; then
        # Set default credentials if they are missing
        if [ "${STEAM_USER}" == "" ]; then
            echo -e "Steam user is not set. Defaulting to anonymous user."
            STEAM_USER=anonymous
            STEAM_PASS=""
            STEAM_AUTH=""
        fi
        # Run SteamCMD
        ${STEAMCMD_PATH} \
            +force_install_dir /home/container \
            +login ${STEAM_USER} ${STEAM_PASS} ${STEAM_AUTH} \
            $( [[ "${WINDOWS_INSTALL}" == "1" ]] && printf %s '+@sSteamCmdForcePlatformType windows' ) \
            $( [[ "${STEAM_SDK}" == "1" ]] && printf %s '+app_update 1007' ) \
            +app_update ${SRCDS_APPID} \
            $( [[ -z ${SRCDS_BETAID} ]] || printf %s "-beta ${SRCDS_BETAID}" ) \
            $( [[ -z ${SRCDS_BETAPASS} ]] || printf %s "-betapassword ${SRCDS_BETAPASS}" ) \
            $( [[ "${VALIDATE}" == "1" ]] && printf %s 'validate' ) \
            +quit

        # Refresh native Steam SDK libs from the steamcmd install used above.
        copy_sdk_libs
    else
        echo -e "No App ID set! Skipping check."
    fi
else
    echo -e "Skipping game server update check; Auto Update is set to 0."
fi

# Replace Startup Variables
MODIFIED_STARTUP=$(echo ${STARTUP} | sed -e 's/{{/${/g' -e 's/}}/}/g')

# Run the Server
echo -e "Starting server..."
echo -e ":/home/container$ ${MODIFIED_STARTUP}"
eval ${MODIFIED_STARTUP}
