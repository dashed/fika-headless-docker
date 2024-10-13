FROM debian:bookworm

# Set environment variables
ARG DEBIAN_FRONTEND=noninteractive

# NVIDIA environment variables (if you're using NVIDIA GPUs)
ENV NVIDIA_DRIVER_CAPABILITIES=all
ENV NVIDIA_VISIBLE_DEVICES=all

# Set the timezone
RUN ln -fs /usr/share/zoneinfo/Etc/UTC /etc/localtime && \
    apt-get update && \
    apt-get install -y tzdata && \
    dpkg-reconfigure --frontend noninteractive tzdata

# Install required packages
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    vim \
    locales \
    gnupg \
    gosu \
    gpg-agent \
    curl \
    unzip \
    ca-certificates \
    cabextract \
    git \
    wget \
    pkg-config \
    libxext6 \
    libvulkan1 \
    libvulkan-dev \
    vulkan-tools \
    sudo \
    iproute2 \
    procps \
    kmod \
    libc6-dev \
    libpci3 \
    libelf-dev \
    dbus-x11 \
    xauth \
    xcvt \
    xserver-xorg-core \
    xvfb \
    cron \
    xz-utils

# Install Wine
ARG WINE_BRANCH="devel"

# Add WineHQ repository and install Wine
RUN dpkg --add-architecture i386 && \
    wget -nv -O- https://dl.winehq.org/wine-builds/winehq.key | apt-key add - && \
    echo "deb https://dl.winehq.org/wine-builds/debian/ $(grep VERSION_CODENAME= /etc/os-release | cut -d= -f2) main" > /etc/apt/sources.list.d/winehq.list && \
    apt-get update && \
    DEBIAN_FRONTEND="noninteractive" apt-get install -y --install-recommends winehq-${WINE_BRANCH} && \
    rm -rf /var/lib/apt/lists/*

# Install the latest winetricks
RUN curl -SL 'https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks' -o /usr/local/bin/winetricks && \
    chmod +x /usr/local/bin/winetricks

# Set locale
RUN locale-gen en_US.UTF-8
ENV LANG en_US.UTF-8

# Create a non-root user to run Wine
RUN useradd -m wineuser

# Set environment variables for Wine and HOME directory
ENV HOME=/home/wineuser
ENV WINEPREFIX=/home/wineuser/.wine
ENV WINEARCH=win64

# Ensure wineuser owns their home directory
RUN chown -R wineuser:wineuser /home/wineuser

# Set the working directory to wineuser's home
WORKDIR /home/wineuser

# Switch to wineuser
USER wineuser

# Pre-initialize Wine prefix
RUN xvfb-run -a wineboot --init

# Set Windows version
RUN xvfb-run -a winecfg -v win10

# Install necessary Windows fonts and components
RUN winetricks -q corefonts arial times

# Cache vcredist installers to avoid download issues
RUN mkdir -p /home/wineuser/.cache/winetricks/vcrun2019 && \
    curl -SL 'https://aka.ms/vs/16/release/vc_redist.x86.exe' \
        -o /home/wineuser/.cache/winetricks/vcrun2019/VC_redist.x86.exe && \
    curl -SL 'https://aka.ms/vs/16/release/vc_redist.x64.exe' \
        -o /home/wineuser/.cache/winetricks/vcrun2019/VC_redist.x64.exe

# Install Visual C++ Redistributable and .NET Desktop Runtime
RUN xvfb-run -a winetricks -q vcrun2019 dotnetdesktop8

# Copy registry files to wineuser's WINEPREFIX
COPY --chown=wineuser:wineuser ./data/reg/user.reg /home/wineuser/.wine/
COPY --chown=wineuser:wineuser ./data/reg/system.reg /home/wineuser/.wine/

# Switch back to root user
USER root

# Adjust permissions for custom Wine binary (wine-ge)
RUN mkdir /wine-ge && \
    curl -sL "https://github.com/GloriousEggroll/wine-ge-custom/releases/download/GE-Proton8-26/wine-lutris-GE-Proton8-26-x86_64.tar.xz" | \
    tar xvJ -C /wine-ge && \
    chown -R wineuser:wineuser /wine-ge

# Set the custom Wine executable path
ENV WINE=/wine-ge/lutris-GE-Proton8-26-x86_64/bin/wine

# Set environment variables for your application
ENV PROFILE_ID=test
ENV SERVER_URL=127.0.0.1
ENV SERVER_PORT=6969

# Nvidia container toolkit configurations
ENV DISPLAY_SIZEW=1024
ENV DISPLAY_SIZEH=768
ENV DISPLAY_REFRESH=60
ENV DISPLAY_DPI=96
ENV DISPLAY_CDEPTH=24
ENV VIDEO_PORT=DFP

# Force TERM to xterm
ENV TERM=xterm

# Copy scripts and entrypoint
COPY ./scripts/install_nvidia_deps.sh /opt/scripts/
COPY ./scripts/purge_logs.sh /usr/bin/purge_logs
COPY ./data/cron/cron_purge_logs /opt/cron/cron_purge_logs
COPY entrypoint.sh /usr/bin/entrypoint
RUN chmod +x /usr/bin/entrypoint

# Set the entrypoint
ENTRYPOINT ["/usr/bin/entrypoint"]
