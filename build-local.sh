#!/usr/bin/env bash
# Local replication of zmkfirmware's build-user-config.yml (v0.3) for the
# Toucan prospector-dongle config repo, building the LEFT and RIGHT halves.
# Runs INSIDE the zmkfirmware/zmk-build-arm:3.5-branch container.
#
# Build-time adjustments (kept local to this checkout):
#  * config/west.yml: zmk-dongle-screen project removed (its pinned branch
#    claude/enhance-wpm-meter-y9Hrb was deleted upstream; that module only
#    serves the dongle build, not the keyboard halves).
#  * config/toucan.conf: DONGLE_SCREEN_* symbols commented out (they were
#    defined only by that deleted module branch and only affect the dongle's
#    screen; irrelevant to the left/right halves).
set -euo pipefail

WORKSPACE="${WORKSPACE:-/workspace}"
WORK="${WORK:-/work}"            # persistent west workspace (host-mounted)
OUT_DIR="${OUT_DIR:-/workspace/build-output}"
BASE_DIR="${WORK}/zmk-config"
mkdir -p "${OUT_DIR}"

# Always sync config fresh from the repo (so edits to config/* take effect).
mkdir -p "${BASE_DIR}/config"
cp -Rf "${WORKSPACE}/config/." "${BASE_DIR}/config/"

# --- one-time west init/update (idempotent across re-runs) ---
if [ ! -d "${BASE_DIR}/.west" ]; then
  echo "::group::west init"
  ( cd "${BASE_DIR}" && west init -l "${BASE_DIR}/config" )
  echo "::endgroup::"
  echo "::group::west update"
  ( cd "${BASE_DIR}" && west update --fetch-opt=--filter=tree:0 )
  echo "::endgroup::"
else
  echo "west workspace already initialized at ${BASE_DIR}; skipping init/update."
fi

# Always export: registers the Zephyr CMake package in this container's home.
echo "::group::west zephyr-export"
( cd "${BASE_DIR}" && west zephyr-export )
echo "::endgroup::"

build_half () {
  local name="$1"; shift
  local shields="$1"; shift
  local build_dir="${WORK}/build-${name}"
  rm -rf "${build_dir}"

  echo "::group::west build (${name})"
  ( cd "${BASE_DIR}" && west build -s zmk/app -d "${build_dir}" -b seeeduino_xiao_ble -- \
    -DZMK_CONFIG="${BASE_DIR}/config" \
    -DSHIELD="${shields}" \
    -DZMK_EXTRA_MODULES="${WORKSPACE}" \
    -DCONFIG_ZMK_SLEEP=y \
    -DCONFIG_ZMK_PM_SOFT_OFF=y )
  echo "::endgroup::"

  cp "${build_dir}/zephyr/zmk.uf2" "${OUT_DIR}/toucan_${name}.uf2"
  echo "Wrote ${OUT_DIR}/toucan_${name}.uf2"
}

build_half left  "toucan_left rgbled_adapter toucan_pet"
build_half right "toucan_right rgbled_adapter"

echo "DONE"
ls -la "${OUT_DIR}"
