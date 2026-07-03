/*
 * Fix trackpad reporting over the ZMK BLE split when the mainline Cirque driver
 * has primary-tap-enable set.
 *
 * Problem: with primary-tap-enable, the mainline driver emits a BTN_TOUCH event
 * on every sample and makes THAT event carry the frame sync (sync=true), while
 * REL_X/REL_Y are sync=false. Each frame is therefore committed on the trailing
 * button event, which travels as its own BLE notify and degrades/corrupts the
 * X-axis movement on the central.
 *
 * Fix (two parts):
 *   1. Force REL_Y to carry sync=true so the movement frame commits right after
 *      X, exactly like the no-tap case (reliable commit point).
 *   2. With the commit now on REL_Y, the redundant per-sample BTN_TOUCH events
 *      can be dropped safely -- only real press/release transitions are
 *      forwarded, so tap-to-click still works without flooding the link.
 *
 * SPDX-License-Identifier: MIT
 */

#define DT_DRV_COMPAT zmk_input_processor_tap_dedupe

#include <zephyr/kernel.h>
#include <zephyr/device.h>
#include <zephyr/sys/util.h>
#include <drivers/input_processor.h>
#include <zephyr/dt-bindings/input/input-event-codes.h>
#include <zephyr/logging/log.h>

LOG_MODULE_DECLARE(zmk, CONFIG_ZMK_LOG_LEVEL);

struct tap_dedupe_data {
    int8_t last; /* last forwarded BTN_TOUCH value; -1 = none yet */
};

static int tap_dedupe_handle_event(const struct device *dev, struct input_event *event,
                                   uint32_t param1, uint32_t param2,
                                   struct zmk_input_processor_state *state) {
    ARG_UNUSED(param1);
    ARG_UNUSED(param2);
    ARG_UNUSED(state);

    if (event->type == INPUT_EV_KEY && event->code == INPUT_BTN_TOUCH) {
        struct tap_dedupe_data *data = dev->data;
        if (event->value == data->last) {
            /* Redundant per-sample button event -- drop it. Safe now that the
             * movement frame commits on REL_Y below. */
            return ZMK_INPUT_PROC_STOP;
        }
        data->last = (int8_t)event->value;
        return ZMK_INPUT_PROC_CONTINUE;
    }

    /* Commit the movement frame at REL_Y (right after X) instead of on the
     * trailing BTN_TOUCH event, matching the no-tap reporting cadence. */
    if (event->type == INPUT_EV_REL && event->code == INPUT_REL_Y) {
        event->sync = true;
    }

    return ZMK_INPUT_PROC_CONTINUE;
}

static const struct zmk_input_processor_driver_api tap_dedupe_api = {
    .handle_event = tap_dedupe_handle_event,
};

static int tap_dedupe_init(const struct device *dev) {
    struct tap_dedupe_data *data = dev->data;
    data->last = -1;
    return 0;
}

#define TAP_DEDUPE_INST(n)                                                                          \
    static struct tap_dedupe_data tap_dedupe_data_##n;                                             \
    DEVICE_DT_INST_DEFINE(n, tap_dedupe_init, NULL, &tap_dedupe_data_##n, NULL, POST_KERNEL,       \
                          CONFIG_KERNEL_INIT_PRIORITY_DEFAULT, &tap_dedupe_api);

DT_INST_FOREACH_STATUS_OKAY(TAP_DEDUPE_INST)
