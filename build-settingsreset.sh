#!/usr/bin/env bash
# Build a settings_reset UF2 for seeeduino_xiao_ble. Flash it to a device, let
# it boot once (clears all settings incl. BLE bonds), then flash the real
# firmware back. Used to clear stale split bonds before re-pairing.
set -euo pipefail

WORKSPACE="${WORKSPACE:-/workspace}"
WORK="${WORK:-/work}"
OUT_DIR="${OUT_DIR:-/workspace/build-output}"
BASE_DIR="${WORK}/zmk-config"

mkdir -p "${BASE_DIR}/config"
cp -Rf "${WORKSPACE}/config/." "${BASE_DIR}/config/"

( cd "${BASE_DIR}" && west zephyr-export )

build_dir="${WORK}/build-settingsreset"
rm -rf "${build_dir}"
echo "::group::west build (settings_reset)"
( cd "${BASE_DIR}" && west build -s zmk/app -d "${build_dir}" -b seeeduino_xiao_ble -- \
  -DZMK_CONFIG="${BASE_DIR}/config" \
  -DSHIELD="settings_reset" \
  -DZMK_EXTRA_MODULES="${WORKSPACE}" )
echo "::endgroup::"

cp "${build_dir}/zephyr/zmk.uf2" "${OUT_DIR}/settings_reset.uf2"
echo "Wrote ${OUT_DIR}/settings_reset.uf2"
