FROM ghcr.io/parkervcp/yolks:wine_latest AS builder

# Stage 1: Build the .NET 6 Wine prefix (ENV required for winetricks)
ENV WINEPREFIX=/home/.wine-dotnet6
ENV WINEARCH=win64
ENV DISPLAY=:99

RUN Xvfb :99 -screen 0 1024x768x24 -ac +extension GLX +render -noreset & \
    sleep 2 && \
    winetricks -q dotnetdesktop6

RUN find /home/.wine-dotnet6 -name hostfxr.dll -print -quit | grep -q . && \
    echo ">>> .NET 6 Desktop Runtime installed" && \
    chmod -R 755 /home/.wine-dotnet6 || \
    (echo "ERROR: .NET 6 install failed" && exit 1)

# Stage 2: Clean image with no persistent WINEPREFIX
FROM ghcr.io/parkervcp/yolks:wine_latest

COPY --from=builder /home/.wine-dotnet6 /home/.wine-dotnet6

# EVLBOX branding
RUN echo '  _____  _    __ ____   _     ___   ___  __  __'  > /home/evlbox-banner.txt && \
    echo ' | ____|| |  / /|  _ \ | |   / _ \ / _ \|  \/  |' >> /home/evlbox-banner.txt && \
    echo ' |  _|  | | / / | |_) || |  | | | | | | | |\/| |' >> /home/evlbox-banner.txt && \
    echo ' | |___ | |/ /  |  _ < | |__| |_| | |_| | |  | |' >> /home/evlbox-banner.txt && \
    echo ' |_____||___/   |_| \_\|_____\___/ \___/|_|  |_|' >> /home/evlbox-banner.txt && \
    echo "" >> /home/evlbox-banner.txt && \
    echo "  🥚 EVLBOX Wine + .NET 6 Runtime" >> /home/evlbox-banner.txt && \
    echo "  Wine 11.0 | .NET 6.0 Desktop | Pterodactyl Compatible" >> /home/evlbox-banner.txt
