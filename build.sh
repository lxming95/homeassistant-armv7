#!/bin/sh
set -eu

IMAGE_NAME="${IMAGE_NAME:-homeassistant-armv7-lean}"
BASE_IMAGE="${BASE_IMAGE:-ghcr.io/home-assistant/armv7-base:3.22}"
HA_VERSION="${HA_VERSION:-2026.7.1}"
PYTHON_VERSION="${PYTHON_VERSION:-3.14.2}"
PYTHON_BUILD_JOBS="${PYTHON_BUILD_JOBS:-1}"
BUILD_TARGET="${BUILD_TARGET:-runtime}"

case "$BUILD_TARGET" in
  runtime)
    IMAGE_TAG="${IMAGE_TAG:-$HA_VERSION}"
    ;;
  full)
    IMAGE_TAG="${IMAGE_TAG:-$HA_VERSION-full}"
    ;;
  *)
    echo "BUILD_TARGET must be 'runtime' or 'full'." >&2
    exit 2
    ;;
esac

validate_ha_version() {
  python3 - "$PYTHON_VERSION" "$HA_VERSION" <<'PYCODE'
import json
import re
import sys
import urllib.request

python_version = tuple(int(part) for part in sys.argv[1].split("."))
ha_version = sys.argv[2]
specifier_re = re.compile(r"(>=|>|<=|<|==|!=)\s*([0-9]+(?:[.][0-9]+){1,2})")


def parse_python_version(value):
    parts = [int(part) for part in value.split(".")]
    while len(parts) < 3:
        parts.append(0)
    return tuple(parts[:3])


def supports_python(specifier):
    if not specifier:
        return True
    for part in specifier.split(","):
        part = part.strip()
        if not part:
            continue
        match = specifier_re.match(part)
        if not match:
            continue
        op, value = match.groups()
        other = parse_python_version(value)
        if op == ">=" and python_version < other:
            return False
        if op == ">" and python_version <= other:
            return False
        if op == "<=" and python_version > other:
            return False
        if op == "<" and python_version >= other:
            return False
        if op == "==" and python_version != other:
            return False
        if op == "!=" and python_version == other:
            return False
    return True


url = f"https://pypi.org/pypi/homeassistant/{ha_version}/json"
try:
    data = json.load(urllib.request.urlopen(url, timeout=20))
except Exception as exc:
    raise SystemExit(f"Unable to read Home Assistant {ha_version} from PyPI: {exc}")

requires_python = data["info"].get("requires_python") or ""
if not supports_python(requires_python):
    raise SystemExit(
        f"Home Assistant {ha_version} requires Python {requires_python}; "
        f"this build is configured for Python {sys.argv[1]}."
    )

print(f"Home Assistant {ha_version} supports Python {sys.argv[1]} ({requires_python})")
PYCODE
}

validate_ha_version

cat <<EOF
Building ${IMAGE_NAME}:${IMAGE_TAG}
  build target:    ${BUILD_TARGET}
  base image:      ${BASE_IMAGE}
  Python source:   ${PYTHON_VERSION}
  Python make -j:  ${PYTHON_BUILD_JOBS}
EOF

docker build \
  --target "${BUILD_TARGET}" \
  --build-arg BASE_IMAGE="${BASE_IMAGE}" \
  --build-arg HA_VERSION="${HA_VERSION}" \
  --build-arg PYTHON_VERSION="${PYTHON_VERSION}" \
  --build-arg PYTHON_BUILD_JOBS="${PYTHON_BUILD_JOBS}" \
  -t "${IMAGE_NAME}:${IMAGE_TAG}" \
  .

echo "Done: ${IMAGE_NAME}:${IMAGE_TAG}"
