# ZMK config for beekeeb Toucan Keyboard (fork)

[The beekeeb Toucan Keyboard](https://beekeeb.com/toucan-keyboard/) is a wireless
split 42-key column-stagger keyboard with a display and a trackpad, plus an
aggressive stagger on the pinky columns.

This fork ([clairesrc/zmk-keyboard-toucan](https://github.com/clairesrc/zmk-keyboard-toucan))
builds off the upstream `prospector-dongle` branch and makes it (a) actually
buildable and (b) target **Zephyr 4.1 / ZMK `main`** so the prospector dongle's
new status screens work. It also adds a few quality-of-life features.

## What changed vs. upstream

### Upstream breakage fixes (originally on the Zephyr 3.5 track)
- **`config/west.yml`**: removed the `zmk-dongle-screen` project. Its pinned
  revision (`claude/enhance-wpm-meter-y9Hrb`) was deleted from the upstream
  fork, which broke `west update`. That module only serves the old
  `dongle_screen` shield and is unneeded now.
- **`config/toucan.conf`**: commented out the `CONFIG_DONGLE_SCREEN_*` symbols.
  They were defined only by that deleted module branch and only affect the
  dongle's old screen, so they are irrelevant to the keyboard halves (and would
  otherwise be fatal Kconfig errors).
- **Dongle display**: uses `prospector_adapter` (the prospector hardware's own
  display shield) in place of the unavailable `dongle_screen`.

### Zephyr 4.1 / ZMK `main` migration
- **`config/west.yml`**: `zmk` → `main`; `prospector-zmk-module` →
  `feat/new-status-screens` (new prospector status screens); `zmk-rgbled-widget`
  → `main`; **removed `cirque-input-module`** (Zephyr 4.1 ships its own Pinnacle
  trackpad driver, which collided with the third-party one on Kconfig).
- **Board**: `seeeduino_xiao_ble` → `xiao_ble//zmk`.
- **`boards/shields/toucan/toucan_right.overlay`**: adapted the Cirque trackpad
  node to the mainline binding (`data-ready-gpios`, `primary-tap-enable`) and
  wired the `tap_dedupe` input processor onto the split input.
- **`boards/shields/toucan/toucan.dtsi`**: trackpad **X-axis inversion via
  per-axis scalers** (negative X multiplier), since the mainline relative-mode
  driver can't invert a single axis. Also adds the nav-layer right-click override
  (see below).
- **New `tap_dedupe` module** (`src/tap_dedupe.c`, `dts/bindings/…`,
  `CMakeLists.txt`, `zephyr/module.yml`): a custom ZMK input processor that
  forces each movement frame to commit at `REL_Y` and dedupes the redundant
  per-sample `BTN_TOUCH` events the mainline Cirque driver emits. Without it,
  enabling tap-to-click floods/degrades the X-axis over the BLE split; with it,
  tap-to-click and smooth movement coexist.

### Features added
- **Left-half display (`boards/shields/toucan_view/`)**: a small shield that
  drives the nice!view GEM (Sharp LS0xx, 144×168) and shows ZMK's built-in
  status screen (battery / peripheral status icons). The original `toucan_pet`
  widget is LVGL-8 and was not portable in this pass, so the built-in screen is
  used instead.
- **Right-click via trackpad tap on the NAV layer**: a layer-conditional
  code-mapper override (`right_click_on_nav`, layer 1) remaps the tap from
  left-click (`BTN_TOUCH`) to right-click (`BTN_1`). Base/SYM layers still
  left-click; NAV-layer tap right-clicks. Existing scroll behavior is preserved
  via `process-next`.
- **Media keys in the ADJ layer**: `C_PREV`, `C_PP` (play/pause), `C_NEXT`
  placed directly under the volume keys (`C_VOL_DN / C_MUTE / C_VOL_UP`).

### Build tooling
- `build-local.sh`, `build-settingsreset.sh`, `build-dongle.sh` — build the
  **Zephyr 3.5 / ZMK v0.3** targets (`seeeduino_xiao_ble`) via the
  `zmkfirmware/zmk-build-arm:3.5-branch` Docker image.
- `build-41.sh` — builds the **Zephyr 4.1 / ZMK `main`** targets
  (`xiao_ble//zmk`): `left`, `right`, `dongle`, `settings_reset`, via the
  `zmkfirmware/zmk-build-arm:4.1-branch` image.
- `.gitignore` excludes the large local west workspaces (`.zmk-workspace*/`),
  build output (`build-output/`), and prebuilt firmware (`firmware/`).

## Building

The 4.1 track is the current default. From the repo root, with Docker available:

```bash
# left half, right half, dongle, settings reset
docker run --rm \
  -v "$PWD:/workspace" -v "$PWD/.zmk-workspace-41:/work" \
  -e WORKSPACE=/workspace -e WORK=/work -e OUT_DIR=/workspace/build-output \
  zmkfirmware/zmk-build-arm:4.1-branch \
  bash /workspace/build-41.sh <left|right|dongle|settings_reset>
```

Outputs land in `build-output/` (UF2 images). For the legacy Zephyr 3.5 track,
use `build-local.sh` / `build-dongle.sh` / `build-settingsreset.sh` with the
`3.5-branch` image instead.

> Flashing a different ZMK version than what's on a device invalidates its BLE
> bonds. When moving a half/dongle between the 3.5 and 4.1 tracks, flash
> `settings_reset` to each device first, then the real firmware, then re-pair
> (boot dongle → left → right).

## Known limitations

- **Left-half `toucan_pet` (pet animation) is not ported.** Its widgets are
  LVGL-8 and won't compile on Zephyr 4.1's LVGL-9. The built-in status screen is
  shown instead.
- **Tap-to-click** relies on the mainline Cirque driver's `primary-tap-enable`,
  relayed over the BLE split with the custom `tap_dedupe` processor. It works but
  is sensitive to that setup.
- **Dongle RAM is ~87%** with the prospector display + split central + the new
  features. If it ever becomes unstable, reduce `CONFIG_LV_Z_VDB_SIZE`.

## License

The code in this repo is available under the MIT license.

The included shield nice_view_gem is modified from
https://github.com/M165437/nice-view-gem licensed under the MIT License.

ZMK code snippets are taken from the ZMK documentation under the MIT license.

The embedded font QuinqueFive is designed by GGBotNet, licensed under the SIL
Open Font License, Version 1.1.
