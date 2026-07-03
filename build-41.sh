#!/usr/bin/env bash
# Build a Zephyr 4.1 / ZMK main target (board xiao_ble//zmk) for the
# prospector-zmk-module feat/new-status-screens migration.
# Usage: bash build-41.sh <left|right|dongle|settings_reset>
set -euo pipefail
TARGET="${1:?usage: build-41.sh <left|right|dongle|settings_reset>}"
WORKSPACE="${WORKSPACE:-/workspace}"
WORK="${WORK:-/work}"
OUT_DIR="${OUT_DIR:-/workspace/build-output}"
BASE_DIR="${WORK}/zmk-config"
BOARD="xiao_ble//zmk"

mkdir -p "${OUT_DIR}" "${BASE_DIR}/config"
cp -Rf "${WORKSPACE}/config/." "${BASE_DIR}/config/"

if [ ! -d "${BASE_DIR}/.west" ]; then
  echo "::group::west init"
  ( cd "${BASE_DIR}" && west init -l "${BASE_DIR}/config" )
  echo "::endgroup::"
else
  echo "west workspace already initialized at ${BASE_DIR}; skipping init."
fi

echo "::group::west update"
( cd "${BASE_DIR}" && west update --fetch-opt=--filter=tree:0 )
echo "::endgroup::"

echo "::group::west zephyr-export"
( cd "${BASE_DIR}" && west zephyr-export )
echo "::endgroup::"

case "$TARGET" in
  left)           SHIELDS="toucan_left rgbled_adapter toucan_view" ;;
  right)          SHIELDS="toucan_right rgbled_adapter" ;;
  dongle)         SHIELDS="toucan_dongle rgbled_adapter prospector_adapter" ;;
  settings_reset) SHIELDS="settings_reset" ;;
  *) echo "unknown target: $TARGET"; exit 1 ;;
esac

build_dir="${WORK}/build-${TARGET}"
rm -rf "${build_dir}"
echo "::group::west build (${TARGET})"
( cd "${BASE_DIR}" && west build -s zmk/app -d "${build_dir}" -b "${BOARD}" -- \
  -DZMK_CONFIG="${BASE_DIR}/config" \
  -DSHIELD="${SHIELDS}" \
  -DZMK_EXTRA_MODULES="${WORKSPACE}" \
  -DCONFIG_ZMK_SLEEP=y \
  -DCONFIG_ZMK_PM_SOFT_OFF=y )
echo "::endgroup::"

cp "${build_dir}/zephyr/zmk.uf2" "${OUT_DIR}/toucan_${TARGET}_41.uf2"
echo "Wrote ${OUT_DIR}/toucan_${TARGET}_41.uf2"
