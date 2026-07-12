# Home Assistant Core on ARMv7 (Orange Pi Plus 2)

Upstream stopped supporting ARMv7 after Home Assistant `2025.11`. Home Assistant `2026.7.1` requires Python `>=3.14.2`, but the official ARMv7 Home Assistant/Python images stop at Python `3.13`.

This build creates a lean, independent image named `homeassistant-armv7-lean`. It starts from `ghcr.io/home-assistant/armv7-base:3.22`, compiles CPython `3.14.2` in a builder stage, preinstalls Home Assistant and known ARMv7 native dependencies, then copies only the runtime artifacts into the final image.

## Files

- `Dockerfile` - multi-stage lean/runtime/full image build
- `build.sh` - build locally on the Orange Pi
- `push.sh` - tag and push the lean image to GHCR as `homeassistant-armv7`
- `docker-compose.yml` - optional run config with host networking

## Build

```sh
./build.sh
```

Defaults:

- `IMAGE_NAME=homeassistant-armv7-lean`
- `HA_VERSION=2026.7.1`
- `PYTHON_VERSION=3.14.2`
- `PYTHON_BUILD_JOBS=1`
- `BUILD_TARGET=runtime`
- `BASE_IMAGE=ghcr.io/home-assistant/armv7-base:3.22`

The default output is:

```sh
homeassistant-armv7-lean:2026.7.1
```

To build the larger debug image with compilers, Rust, and headers kept in the runtime:

```sh
BUILD_TARGET=full ./build.sh
```

The full output is:

```sh
homeassistant-armv7-lean:2026.7.1-full
```

`build.sh` validates the Home Assistant Python requirement against the configured Python version before Docker starts. It does not select older local Home Assistant images as a base.

## Push to GHCR

Authenticate with a GitHub classic PAT that has `write:packages`, then run:

```sh
docker login ghcr.io -u imkebe
./push.sh
```

By default this publishes `ghcr.io/imkebe/homeassistant-armv7:2026.7.1`.
The source image remains `homeassistant-armv7-lean:2026.7.1`; only the public
GHCR name is shortened.

To push the full/debug target:

```sh
IMAGE_TAG=2026.7.1-full ./push.sh
```

## Run

```sh
docker run -d --name homeassistant --restart unless-stopped \
  --net=host \
  --privileged \
  -e TZ=Europe/Warsaw \
  -v /dev/bus/usb:/dev/bus/usb \
  -v /run/dbus:/run/dbus:ro \
  -v /sys:/sys \
  -v /home/kebe/ha/config:/config \
  homeassistant-armv7-lean:2026.7.1
```

Or update `docker-compose.yml` to use `homeassistant-armv7-lean:2026.7.1` and run:

```sh
docker compose up -d
```

## Notes

- The CPython compile is expected to be slow. Keep `PYTHON_BUILD_JOBS=1` unless the board has enough RAM/swap.
- The lean runtime intentionally does not keep compilers, Rust, Cargo, or most `-dev` headers. Use the `full` target when a one-off runtime compile fallback is needed.
- The `stream` integration imports `numpy` during module import, before Home Assistant runtime requirement installation can recover. The image prebuilds `numpy==2.3.2`, `PyTurboJPEG==1.8.3`, and `av==17.0.1`.
- `av==17.0.1` needs newer FFmpeg headers than Alpine 3.22 `ffmpeg-dev` provides, so the Dockerfile upgrades the FFmpeg stack from Alpine edge in both builder and runtime.
- PostgreSQL recorder URLs require `psycopg2`; the image prebuilds `psycopg2==2.9.11` and keeps `libpq` for runtime.
- Google Calendar requires `pydantic-core` through `ical`; the image builds `pydantic-core==2.46.4` from source and preinstalls `pydantic==2.13.4`, `ical==13.2.2`, `gcal-sync==8.0.0`, and `oauth2client==4.1.3` because no ARMv7 wheel is available.
- Assist requires native voice packages, so the image prebuilds `pymicro-vad==1.0.1`, `pyspeex-noise==1.0.2`, `hassil==3.8.0`, and `home-assistant-intents==2026.6.24`.
- Bluetooth is pinned to the Home Assistant 2026.7.1 requirements: `habluetooth==6.26.2`, `bluetooth-adapters==2.4.0`, `bleak==3.0.2`, and `dbus-fast==5.0.22`.
- This build is best-effort because Home Assistant no longer supports ARMv7.
