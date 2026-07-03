#!/usr/bin/env bash
# Build the TOUCAN DONGLE firmware for seeeduino_xiao_ble.
#
# The repo's build.yaml pins `dongle_screen` for the dongle, but that module's
# source branch was deleted upstream. `prospector_adapter` (from the available
# prospector-zmk-module) is the correct display shield for the prospector dongle
# hardware — same screen UI you already see (battery bar, layer roller). Combined
# with `toucan_dongle` it gives working Toucan keys + the prospector display.
#
# Matches build.yaml's dongle target (Studio snippet + CONFIG_ZMK_STUDIO=y),
# only substituting prospector_adapter for dongle_screen.
set -euo pipefail

WORKSPACE="${WORKSPACE:-/workspace}"
WORK="${WORK:-/work}"
OUT_DIR="${OUT_DIR:-/workspace/build-output}"
BASE_DIR="${WORK}/zmk-config"

mkdir -p "${BASE_DIR}/config"
cp -Rf "${WORKSPACE}/config/." "${BASE_DIR}/config/"
( cd "${BASE_DIR}" && west zephyr-export )

build_dir="${WORK}/build-dongle"
rm -rf "${build_dir}"
echo "::group::west build (toucan_dongle)"
( cd "${BASE_DIR}" && west build -s zmk/app -d "${build_dir}" -b seeeduino_xiao_ble \
  -S studio-rpc-usb-uart -- \
  -DZMK_CONFIG="${BASE_DIR}/config" \
  -DSHIELD="toucan_dongle rgbled_adapter prospector_adapter" \
  -DZMK_EXTRA_MODULES="${WORKSPACE}" \
  -DCONFIG_ZMK_STUDIO=y )
echo "::endgroup::"

cp "${build_dir}/zephyr/zmk.uf2" "${OUT_DIR}/toucan_dongle.uf2"
echo "Wrote ${OUT_DIR}/toucan_dongle.uf2"
