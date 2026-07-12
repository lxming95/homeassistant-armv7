# syntax=docker/dockerfile:1
# Home Assistant Core 2026.x on ARMv7 (unsupported upstream)
#
# This build starts from the small Home Assistant base image instead of an old
# full Home Assistant image. The builder stage carries compilers and Rust; the
# runtime stage receives only Python, Home Assistant, pinned integration deps,
# runtime libraries, and the S6 service wiring.

ARG BASE_IMAGE=ghcr.io/home-assistant/armv7-base:3.22

FROM ${BASE_IMAGE} AS builder

SHELL ["/bin/sh", "-lc"]

ARG PYTHON_VERSION=3.14.2
ARG PYTHON_BUILD_JOBS=1
ARG HA_VERSION=2026.7.1

ENV CARGO_BUILD_JOBS=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1 \
    PYTHONDONTWRITEBYTECODE=1

RUN apk add --no-cache --virtual .build-deps \
      build-base \
      linux-headers \
      pkgconf \
      wget \
      bzip2-dev \
      expat-dev \
      gdbm-dev \
      libffi-dev \
      ncurses-dev \
      openssl-dev \
      readline-dev \
      sqlite-dev \
      util-linux-dev \
      xz-dev \
      zlib-dev \
      bluez-dev \
      cargo \
      rust \
      cmake \
      samurai \
      jpeg-dev \
      libpng-dev \
      freetype-dev \
      lcms2-dev \
      openjpeg-dev \
      tiff-dev \
      libwebp-dev \
      gfortran \
      patchelf \
      openblas-dev \
      lapack-dev \
      ffmpeg-dev \
      libjpeg-turbo-dev \
      postgresql-dev

RUN wget -O /tmp/Python-${PYTHON_VERSION}.tgz \
      "https://www.python.org/ftp/python/${PYTHON_VERSION}/Python-${PYTHON_VERSION}.tgz" && \
    mkdir -p /usr/src/python && \
    tar -xzf /tmp/Python-${PYTHON_VERSION}.tgz -C /usr/src/python --strip-components=1 && \
    cd /usr/src/python && \
    ./configure \
      --prefix=/usr/local \
      --enable-shared \
      --with-ensurepip=install \
      --disable-test-modules && \
    make -j "${PYTHON_BUILD_JOBS}" && \
    make install && \
    cd / && \
    ln -sf /usr/local/bin/python3.14 /usr/local/bin/python3 && \
    ln -sf /usr/local/bin/python3.14 /usr/local/bin/python && \
    ln -sf /usr/local/bin/pip3.14 /usr/local/bin/pip3 && \
    ln -sf /usr/local/bin/pip3.14 /usr/local/bin/pip && \
    rm -rf /tmp/Python-${PYTHON_VERSION}.tgz /usr/src/python && \
    python3 --version && \
    python3 -m pip --version

RUN python3 -m pip install --no-cache-dir --no-compile -U pip wheel setuptools

# Home Assistant core and native packages that are known to fail or pick wrong
# versions when installed lazily at runtime on ARMv7/Python 3.14.
RUN python3 -m pip install --no-cache-dir --no-compile \
      "Cython>=3.0.6" \
      "meson-python>=0.15.0" && \
    python3 -m pip install --no-cache-dir --no-compile -U "homeassistant==${HA_VERSION}" && \
    python3 -m pip install --no-cache-dir --no-compile --no-build-isolation \
      "numpy==2.3.2"

# PyAV 17 needs newer FFmpeg than Alpine 3.22 ships.
RUN apk add --no-cache \
      --repository https://dl-cdn.alpinelinux.org/alpine/edge/main \
      --repository https://dl-cdn.alpinelinux.org/alpine/edge/community \
      --upgrade \
      ffmpeg \
      ffmpeg-dev && \
    python3 -m pip install --no-cache-dir --no-compile --no-build-isolation \
      "PyTurboJPEG==1.8.3" \
      "av==17.0.1"

RUN python3 -m pip install --no-cache-dir --no-compile \
      "psycopg2==2.9.11"

# Keep Rust new enough for pydantic-core fallback source builds. Pip should
# prefer the cp314 musllinux armv7l wheel from PyPI when available.
RUN apk add --no-cache \
      --repository https://dl-cdn.alpinelinux.org/alpine/edge/main \
      --repository https://dl-cdn.alpinelinux.org/alpine/edge/community \
      --upgrade \
      rust \
      cargo

RUN python3 -m pip install --no-cache-dir --no-compile \
      "pydantic-core==2.46.4" \
      "pydantic==2.13.4" \
      "ical==13.2.2" \
      "gcal-sync==8.0.0" \
      "oauth2client==4.1.3"

RUN python3 -m pip install --no-cache-dir --no-compile \
      "pymicro-vad==1.0.1" \
      "pyspeex-noise==1.0.2" \
      "hassil==3.8.0" \
      "home-assistant-intents==2026.6.24" \
      "habluetooth==6.26.2" \
      "bluetooth-adapters==2.4.0" \
      "bleak==3.0.2" \
      "dbus-fast==5.0.22"

# Additional integration requirements observed in runtime logs. Keeping them in
# the builder avoids lazy installs that would otherwise need compilers.
RUN apk add --no-cache \
      --repository https://dl-cdn.alpinelinux.org/alpine/edge/main \
      --repository https://dl-cdn.alpinelinux.org/alpine/edge/community \
      --upgrade \
      rust \
      cargo && \
    python3 -m pip install --no-cache-dir --no-compile \
      "python-miio==0.5.12" \
      "mutagen==1.47.0" \
      "HATasmota==0.10.1" \
      "openai==2.21.0"

RUN python3 -m pip install --no-cache-dir --no-compile \
      "ha-ffmpeg==3.2.2"

RUN python3 -m pip install --no-cache-dir --no-compile \
      "aiousbwatcher==1.1.2" \
      "pyserial==3.5" \
      "serialx==1.8.2"

RUN python3 -m pip install --no-cache-dir --no-compile \
      "colorlog==6.10.1"

RUN python3 -m pip install --no-cache-dir --no-compile \
      "home-assistant-frontend==20260624.4" \
      "infrared-protocols==6.3.0" \
      "rf-protocols==4.3.0" \
      "jsonpath-python==1.1.6" \
      "aionut==4.3.4" \
      "py-cpuinfo==9.0.0" \
      "icmplib==3.0" \
      "pyipp==0.17.2" \
      "speedtest-cli==2.1.3" \
      "paho-mqtt==2.1.0" \
      "pyopenuv==2023.02.0" \
      "aiohasupervisor==0.5.0" \
      "construct==2.10.68" \
      "micloud==0.5" \
      "colorthief==0.2.1" \
      "gTTS==2.5.4" \
      "moonraker-api==2.0.6" \
      "openwrt-luci-rpc==1.1.17" \
      "pyhaversion==22.8.0" \
      "RestrictedPython==8.1" \
      "wakeonlan==3.1.0"

RUN python3 -m pip install --no-cache-dir --no-compile --no-binary=aioesphomeapi,bleak-esphome \
      "aioesphomeapi==45.3.1" \
      "bleak-esphome==3.9.4" \
      "esphome-dashboard-api==1.3.0"

RUN python3 -m pip install --no-cache-dir --no-compile --no-binary=cached-ipaddress \
      "aiodiscover==3.3.2" \
      "cached-ipaddress==1.1.2"

RUN python3 -m pip install --no-cache-dir --no-compile \
      "matter-python-client==0.7.1" \
      "matter-ble-proxy==0.7.1" \
      "aiodhcpwatcher==1.2.7"

RUN python3 -m pip install --no-cache-dir --no-compile \
      "aioruuvigateway==0.1.0" \
      "aioshelly==13.26.2" \
      "ibeacon-ble==1.2.0" \
      "aiofiles==25.1.0"

# Versions observed during Home Assistant 2026.7.1 startup on this config.
RUN python3 -m pip install --no-cache-dir --no-compile \
      "icmplib==3.0.4" \
      "wakeonlan==3.3.0" \
      "ical==13.2.5"

RUN find /usr/local -depth \
      \( -type d \( -name test -o -name tests -o -name __pycache__ \) -o \
         -type f \( -name '*.pyc' -o -name '*.pyo' -o -name '*.a' -o -name '*.la' \) \) \
      -exec rm -rf '{}' + && \
    rm -rf /root/.cache /root/.cargo /tmp/* /var/cache/apk/*

FROM ${BASE_IMAGE} AS runtime

SHELL ["/bin/sh", "-lc"]

ARG HA_VERSION=2026.7.1

ENV PATH=/usr/local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    LANG=C.UTF-8 \
    S6_BEHAVIOUR_IF_STAGE2_FAILS=2 \
    S6_CMD_WAIT_FOR_SERVICES=1 \
    S6_CMD_WAIT_FOR_SERVICES_MAXTIME=0 \
    S6_SERVICES_READYTIME=50 \
    S6_SERVICES_GRACETIME=240000 \
    UV_EXTRA_INDEX_URL=https://wheels.home-assistant.io/musllinux-index/ \
    UV_SYSTEM_PYTHON=true \
    UV_NO_CACHE=true \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1 \
    PYTHONDONTWRITEBYTECODE=1

RUN apk add --no-cache \
      bluez-libs \
      bzip2 \
      ca-certificates \
      dbus-libs \
      eudev-libs \
      expat \
      freetype \
      gdbm \
      jpeg \
      lcms2 \
      libffi \
      libjpeg-turbo \
      libpng \
      libpq \
      libstdc++ \
      libuuid \
      libwebp \
      ncurses-libs \
      openblas \
      openjpeg \
      openssl \
      readline \
      sqlite-libs \
      tiff \
      tzdata \
      xz-libs \
      zlib && \
    apk add --no-cache \
      --repository https://dl-cdn.alpinelinux.org/alpine/edge/main \
      --repository https://dl-cdn.alpinelinux.org/alpine/edge/community \
      --upgrade \
      ffmpeg

COPY --from=builder /usr/local /usr/local

RUN ln -sf /usr/local/bin/python3.14 /usr/local/bin/python3 && \
    ln -sf /usr/local/bin/python3.14 /usr/local/bin/python && \
    ln -sf /usr/local/bin/pip3.14 /usr/local/bin/pip3 && \
    ln -sf /usr/local/bin/pip3.14 /usr/local/bin/pip && \
    rm -rf /root/.cache /tmp/* /var/cache/apk/*

RUN <<'EOF'
set -eu
mkdir -p /etc/services.d/home-assistant

cat > /etc/services.d/home-assistant/run <<'SCRIPT'
#!/usr/bin/with-contenv bashio
# ==============================================================================
# Start Home Assistant service
# ==============================================================================

cd /config || bashio::exit.nok "Can't find config folder!"

if [[ -z "${DISABLE_JEMALLOC+x}" ]]; then
  export LD_PRELOAD="/usr/local/lib/libjemalloc.so.2"
  export MALLOC_CONF="background_thread:true,metadata_thp:auto,dirty_decay_ms:20000,muzzy_decay_ms:20000"
fi

exec python3 -m homeassistant --config /config
SCRIPT

cat > /etc/services.d/home-assistant/finish <<'SCRIPT'
#!/usr/bin/env bashio
# ==============================================================================
# Take down the S6 supervision tree when Home Assistant fails
# ==============================================================================
declare RESTART_EXIT_CODE=100
declare SIGNAL_EXIT_CODE=256
declare APP_EXIT_CODE=${1}
declare SIGNAL_NO=${2}
declare NEW_EXIT_CODE=

bashio::log.info "Home Assistant Core finish process exit code ${APP_EXIT_CODE}"

if [[ ${APP_EXIT_CODE} -eq ${RESTART_EXIT_CODE} ]]; then
  exit 0
elif [[ ${APP_EXIT_CODE} -eq ${SIGNAL_EXIT_CODE} ]]; then
  bashio::log.info "Home Assistant Core finish process received signal ${SIGNAL_NO}"
  NEW_EXIT_CODE=$((128 + SIGNAL_NO))
  echo ${NEW_EXIT_CODE} > /run/s6-linux-init-container-results/exitcode
else
  bashio::log.info "Home Assistant Core service shutdown"
  echo ${APP_EXIT_CODE} > /run/s6-linux-init-container-results/exitcode
fi

/run/s6/basedir/bin/halt
SCRIPT

chmod a+x /etc/services.d/home-assistant/run /etc/services.d/home-assistant/finish
EOF

LABEL io.hass.version="${HA_VERSION}" \
      org.opencontainers.image.title="Home Assistant ARMv7" \
      org.opencontainers.image.source="https://github.com/imkebe/homeassistant-armv7" \
      org.opencontainers.image.version="${HA_VERSION}"

WORKDIR /config
VOLUME ["/config"]
EXPOSE 8123
ENTRYPOINT ["/init"]

FROM runtime AS full

ARG HA_VERSION=2026.7.1

ENV CARGO_BUILD_JOBS=1

RUN apk add --no-cache --virtual .build-deps \
      build-base \
      linux-headers \
      pkgconf \
      wget \
      bzip2-dev \
      expat-dev \
      gdbm-dev \
      libffi-dev \
      ncurses-dev \
      openssl-dev \
      readline-dev \
      sqlite-dev \
      util-linux-dev \
      xz-dev \
      zlib-dev \
      bluez-dev \
      cargo \
      rust \
      cmake \
      samurai \
      jpeg-dev \
      libpng-dev \
      freetype-dev \
      lcms2-dev \
      openjpeg-dev \
      tiff-dev \
      libwebp-dev \
      gfortran \
      patchelf \
      openblas-dev \
      lapack-dev \
      libjpeg-turbo-dev \
      postgresql-dev && \
    apk add --no-cache \
      --repository https://dl-cdn.alpinelinux.org/alpine/edge/main \
      --repository https://dl-cdn.alpinelinux.org/alpine/edge/community \
      --upgrade \
      ffmpeg \
      ffmpeg-dev && \
    rm -rf /root/.cache /tmp/* /var/cache/apk/*

LABEL io.hass.version="${HA_VERSION}-full" \
      org.opencontainers.image.version="${HA_VERSION}-full"
