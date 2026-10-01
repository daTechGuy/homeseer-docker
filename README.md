[![Build & Publish Images](https://github.com/daTechGuy/homeseer-docker/actions/workflows/build.yml/badge.svg)](https://github.com/daTechGuy/homeseer-docker/actions/workflows/build.yml)

# Docker Container for HomeSeer 4 (Linux)

(Originally developed with ♥ by SavageSoftware, LLC.)

## Disclaimers

 -  This repository is not supported, sponsored or directly affiliated with Homeseer ([https://homeseer.com/](https://homeseer.com/)).
 -  We are not responsible for any data lost or systems corrupted! 

---

## Overview

This project provides Docker container images for HomeSeer 4 on Linux, built on Debian 12 (bookworm)
with Mono 6.12.

Images are published to the GitHub Container Registry:

| Tag | HomeSeer version |
|-----|------------------|
| `ghcr.io/datechguy/homeseer:latest` | latest release (see [`versions.env`](versions.env)) |
| `ghcr.io/datechguy/homeseer:beta`   | latest beta |
| `ghcr.io/datechguy/homeseer:<version>` | a specific HomeSeer version, e.g. `4.2.24.0` |

---

## TL;DR

Command to launch Docker container:
```
docker run -d --name homeseer --stop-timeout 90 \
       -p 80:80 -p 10200:10200 -p 10300:10300 -p 10401:10401 -p 11000:11000 \
       -v /etc/homeseer:/homeseer \
       ghcr.io/datechguy/homeseer:latest
```

---

## Supported Architectures

- ARM 64-bit ( `arm64` )
- Intel/AMD 64-bit ( `amd64` / `x86_64` )

---

## How installs & upgrades work

On first start the container extracts the bundled HomeSeer application into the `/homeseer` volume.
On every later start it compares the HomeSeer version installed in the volume with the version
bundled in the image:

| Situation | What happens |
|-----------|--------------|
| `/homeseer` is empty | HomeSeer is installed |
| image bundles a **newer** version | HomeSeer is upgraded in place |
| installed version is the same or **newer** (e.g. updated from the HomeSeer UI) | nothing; it is never downgraded |
| `HOMESEER_FORCE_INSTALL=true` | the bundled version is re-extracted |
| a `/homeseer/no-install` file exists | installation is always skipped |

The HomeSeer archive does not contain your settings, devices, events or plugins, so installs/upgrades
keep your configuration. It is still a good idea to back up the `/homeseer` volume before upgrading.

When the container is stopped, HomeSeer is asked to shut down cleanly (the same as
*Tools > System > Shutdown*) before the container exits.

### Environment variables

| Variable | Default | Description |
|----------|---------|-------------|
| `TZ` | `America/New_York` | Time zone |
| `LANG` | `en_US.UTF-8` | Locale |
| `HOMESEER_CREDENTIALS` | | `user:password`; only needed if HomeSeer requires a login for local (localhost) connections, so the container can request a clean shutdown |
| `HOMESEER_FORCE_INSTALL` | `false` | Re-extract the bundled HomeSeer version on start |
| `HOMESEER_SHUTDOWN_TIMEOUT` | `60` | Seconds to wait for HomeSeer to shut down before it is killed |
| `ZWAVE_JS_UI` | `false` | `true` runs the bundled Z-Wave JS UI for the Z-Wave Plus plugin (see below) |
| `ZWAVE_JS_UI_PORT` | `8091` | Z-Wave JS UI web port |
| `ZWAVE_JS_UI_STORE` | `/homeseer/zwave-js-ui` | Z-Wave JS UI data (settings, network keys, logs) |

### Z-Wave Plus plugin (Z-Wave JS)

HomeSeer's **Z-Wave Plus** plugin needs Z-Wave JS UI. On Linux the plugin tries to install it by running
`sudo docker` itself, which can't work inside this container. Instead, the image bundles Z-Wave JS UI
(the same version the plugin pins) and runs it next to HomeSeer when `ZWAVE_JS_UI=true`:

1. Start the container with `ZWAVE_JS_UI=true`.
2. Open Z-Wave JS UI at `http://<container-ip>:8091/` → *Settings → Z-Wave*, set the **Serial Port** to your
   controller (a Z-NET is `tcp://<z-net-ip>:2001`; a USB stick is the mapped device, e.g. `/dev/ttyUSB0`),
   enter your security keys, and save.
3. In HomeSeer, *Plugins → Z-Wave Plus → Manage Networks*, add the network as **External** with IP
   `127.0.0.1`, UI port `8091` and WebSocket port `3000`.

### Ports

| Port | Use |
|------|-----|
| 80    | HTTP / web UI |
| 10200 | HS-Touch |
| 10300 | myHS |
| 10401 | Speaker clients |
| 11000 | ASCII / JSON remote API |

---

## Unraid

1. Open the Unraid terminal (the `>_` icon at the top right of the web UI) and download the template:
   ```shell
   wget -O /boot/config/plugins/dockerMan/templates-user/my-HomeSeer.xml \
        https://raw.githubusercontent.com/daTechGuy/homeseer-docker/main/unraid/homeseer.xml
   ```
2. Go to **Docker**, click **Add Container**, and pick **HomeSeer** from the **Template** dropdown.
3. Review the settings and click **Apply**. Open the web UI from the container's icon menu (**WebUI**).

Notes:

 - **Network:** the template uses the custom `br0` network so HomeSeer gets its own LAN IP. Fill in
   **Fixed IP address** with an unused address outside your router's DHCP range. HomeSeer then answers on
   port 80 of that IP and LAN discovery (mDNS, Z-NET, HS-Touch) works. Port mappings don't apply on `br0`.
   If you'd rather use `bridge`, change the web UI port to e.g. 8080 (Unraid's own UI uses port 80).
 - **Unraid host ↔ HomeSeer:** by default, Unraid itself can't reach containers on `br0` (other LAN devices
   can). If you need that, enable *Settings > Docker > Host access to custom networks* (Docker must be stopped
   to change it).
 - **Appdata:** HomeSeer uses SQLite databases. Keep the `appdata` share on a pool/cache
   (*Primary storage: Cache, Secondary: none*), or point the path at `/mnt/cache/appdata/homeseer`.
 - **Z-Wave/Zigbee stick:** set the *Z-Wave / Serial Device* field using a stable path, e.g.
   `/dev/serial/by-id/usb-XXXX:/dev/ttyUSB0`, then select `/dev/ttyUSB0` in the HomeSeer plugin.
 - **Updating:** HomeSeer can update itself from its own UI, and that update is kept when Unraid updates or
   recreates the container. Updating the container image only upgrades HomeSeer when the image is newer.

### Migrating an existing HomeSeer install

1. On the old system, make a backup (*Tools > Backup*) and note the HomeSeer version and plugins.
2. Shut down the old HomeSeer, then copy its whole HomeSeer folder into the appdata path
   (e.g. `/mnt/user/appdata/homeseer`), so that `HSConsole.exe`, `Config/`, `Data/`, plugins, scripts and
   `html/` customizations sit at the top level of that folder.
3. Start the container. If the copied HomeSeer is older than the image's version it is upgraded in place;
   otherwise it is left as is.

**Testing alongside a live system:** run the test container on a *copy* of the data, and in the test copy
disable the Z-Wave interfaces (or the Z-Wave plugin) **before** starting it. A Z-NET only accepts one
controlling connection, so a test instance can knock the live HomeSeer off it, and both instances would run
the same events (lights, notifications). When you're ready, cut over: stop the old HomeSeer, copy its data
again (fresh), re-enable Z-Wave and start the container. To fall back, stop the container and start the
old system.

---

## Docker Compose

See [`docker-compose.yml`](docker-compose.yml), then run `docker compose up -d` in the same directory.

---

## Building

The HomeSeer versions are defined in [`versions.env`](versions.env). Pushing a change to `main` makes
GitHub Actions build multi-arch (`amd64`/`arm64`) images and push them to GHCR. Images are also rebuilt
weekly to pick up Debian security updates.

To build locally:
```shell
./build.sh            # build release + beta for the local platform
./build.sh --push     # build multi-arch and push (requires 'docker login ghcr.io')
```

---

## Acknowledgments

Forked from [HomeSeerLinux/homeseer-docker](https://github.com/HomeSeerLinux/homeseer-docker).
Credit must be attributed to the following existing repositories and their respective authors.  Much of 
the logic used in this project was based on these prior works. 

 - https://github.com/marthoc/docker-homeseer
 - https://github.com/scyto/docker-homeseer
 - https://github.com/E1iTeDa357/docker-homeseer4
