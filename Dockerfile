#########################################
# HOMESEER (V4) LINUX - DOCKERFILE
#########################################
FROM debian:bookworm-slim

# build arguments
ARG TARGETARCH
ARG BUILDDATE
ARG VERSION=4.2.24.0
ARG DOWNLOAD=https://homeseer.com/updates4/linux_4_2_24_0.tar.gz
ARG DEBIAN_FRONTEND=noninteractive

# custom STOP signal for 'docker stop'
STOPSIGNAL SIGQUIT

# environment variables
ENV LANG="en_US.UTF-8" \
    TZ="America/New_York" \
    HOMESEER_FOLDER="/homeseer" \
    HOMESEER_VERSION="$VERSION"

# docker container image labels
LABEL org.opencontainers.image.title="homeseer" \
      org.opencontainers.image.description="HomeSeer 4 (Linux) Docker Image" \
      org.opencontainers.image.source="https://github.com/daTechGuy/homeseer-docker" \
      org.opencontainers.image.created=$BUILDDATE \
      org.opencontainers.image.version=$VERSION

RUN echo "=========================================================" && \
    echo "  BUILDING DOCKER HOMESEER ($VERSION) IMAGE FOR: $TARGETARCH" && \
    echo "========================================================="

# add the Mono Project APT repository (Mono 6.12; recommended by HomeSeer)
RUN apt-get update && \
    apt-get install --yes --no-install-recommends ca-certificates curl gnupg && \
    curl -fsSL "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x3FA7E0328081BFF6A14DA29AA6A19B38D3D831EF" \
      | gpg --dearmor -o /usr/share/keyrings/mono-official-archive-keyring.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/mono-official-archive-keyring.gpg] https://download.mono-project.com/repo/debian stable-buster main" \
      > /etc/apt/sources.list.d/mono-official-stable.list && \
    rm -rf /var/lib/apt/lists/*

# install locale, container tools and HomeSeer dependencies
# (chromium is omitted; HomeSeer only needs it on graphical desktop systems)
RUN apt-get update && \
    apt-get install --yes locales tzdata procps psmisc iproute2 net-tools iputils-ping \
                          tmux wget nano etherwake openssh-client mosquitto-clients dos2unix unzip \
                          aha ffmpeg alsa-utils flite \
                          dbus avahi-daemon avahi-utils avahi-discover libavahi-compat-libdnssd-dev libnss-mdns mdns-scan \
                          mono-complete mono-vbnc mono-xsp4 && \
    sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && \
    dpkg-reconfigure --frontend=noninteractive locales && \
    update-locale LANG=en_US.UTF-8 && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# copy container homeseer override scripts
COPY base/homeseer/*.sh    /scripts/

# copy container runtime scripts
COPY base/usr/local/sbin/* /scripts/

# ensure scripts are unix line-encoded and executable
RUN dos2unix /scripts/* && chmod a+x /scripts/*

# replace "reboot" and "shutdown" binaries with symlinks to scripts
RUN rm -f /sbin/reboot /sbin/shutdown /sbin/poweroff && \
    ln -sf /scripts/homeseer /usr/local/sbin/homeseer && \
    ln -sf /scripts/reboot   /usr/local/sbin/reboot   && \
    ln -sf /scripts/shutdown /usr/local/sbin/shutdown && \
    ln -sf /scripts/poweroff /usr/local/sbin/poweroff

# copy default configuration files
COPY base/etc/avahi/avahi-daemon.conf /etc/avahi/avahi-daemon.conf

# make folders for DBUS & AVAHI; apply folder permissions
RUN mkdir -p /var/run/dbus /var/run/avahi-daemon && \
    chown messagebus:messagebus /var/run/dbus && \
    chown avahi:avahi /var/run/avahi-daemon

# install Z-Wave JS UI (standalone binary) for the HomeSeer "Z-Wave Plus" plugin
# (only started when ZWAVE_JS_UI=true; the plugin connects to it in "External" mode)
ARG ZWAVE_JS_UI_VERSION=11.21.1
RUN case "$TARGETARCH" in \
      arm64) ZJS_ZIP="zwave-js-ui-v${ZWAVE_JS_UI_VERSION}-linux-arm64.zip" ;; \
      *)     ZJS_ZIP="zwave-js-ui-v${ZWAVE_JS_UI_VERSION}-linux.zip" ;; \
    esac && \
    mkdir -p /opt/zwave-js-ui && \
    wget -q --tries=5 --timeout=60 --retry-connrefused -O /tmp/zwave-js-ui.zip "https://github.com/zwave-js/zwave-js-ui/releases/download/v${ZWAVE_JS_UI_VERSION}/${ZJS_ZIP}" && \
    unzip -q /tmp/zwave-js-ui.zip -d /tmp/zwave-js-ui && \
    find /tmp/zwave-js-ui -maxdepth 1 -type f -name 'zwave-js-ui*' -exec mv {} /opt/zwave-js-ui/zwave-js-ui \; && \
    chmod a+x /opt/zwave-js-ui/zwave-js-ui && \
    rm -rf /tmp/zwave-js-ui /tmp/zwave-js-ui.zip
ENV ZWAVE_JS_UI_VERSION="$ZWAVE_JS_UI_VERSION"

# add the HomeSeer Linux application archive
# (extracted into the /homeseer volume at container startup)
# uses 'downloads/homeseer.tar.gz' from the build context when present (pre-downloaded by
# the CI workflow / build.sh); otherwise downloads it here
COPY downloads/ /tmp/downloads/
RUN if [ -f /tmp/downloads/homeseer.tar.gz ]; then \
      mv /tmp/downloads/homeseer.tar.gz /homeseer.tar.gz; \
    else \
      wget -q --tries=5 --timeout=60 --retry-connrefused -O /homeseer.tar.gz "$DOWNLOAD"; \
    fi && \
    rm -rf /tmp/downloads

# define IP ports to be exposed by this container
# 80    : HTTP/WEB
# 10200 : HS-TOUCH
# 10300 : myHS
# 10401 : SPEAKER CLIENTS
# 11000 : ASCII/JSON REMOTE API
EXPOSE 80 10200 10300 10401 11000

# define required volume
VOLUME ["/homeseer"]

# set the working path
WORKDIR "/homeseer"

# report healthy once the HomeSeer web server answers
HEALTHCHECK --interval=60s --timeout=10s --start-period=180s --retries=3 \
  CMD /scripts/healthcheck

# launch homeseer script in container on startup
CMD ["/usr/local/sbin/homeseer"]
