# The touch screen app

The DP200's built-in panel runs our own small app in Klipper mode:
`install/display/dp200_screen.py` (Python with Pillow, drawing straight
to the framebuffer). It talks to Moonraker on the printer itself, so it
shows the same state as Mainsail. This page describes it as it is; how
the choice was made (KlipperScreen and the other options) is in
[history/touchscreen_options.md](history/touchscreen_options.md).

## How it runs

- Started as the `screen` service by `rc.dp200`, as root inside the
  Debian root. `SCREEN_ENABLED=0` in `/etc/dp200/screen.conf` turns it
  off. Sindoh's own UI is stopped while Klipper mode runs, so the panel
  is free.
- Its own settings (screen timeout, custom macro buttons) are saved in
  `/etc/dp200/screen_settings.json`.
- `python3 dp200_screen.py --demo FILE` draws a page into a PNG without
  a panel. The `test_dp200_*.py` files next to it are PC tests.
- Wi-Fi setup is in `dp200_wifi.py`, port and IP settings in
  `dp200_net.py` ([wifi.md](wifi.md), [network.md](network.md)).

## Rules the app follows

- Anything that moves or heats asks for confirmation first.
- **STOP** is at the bottom right of every page: an emergency stop,
  held for 1 second.
- Before a print it asks whether the bed is empty (Z homes upward).
- After the timeout without a touch the image goes black, and the first
  tap only wakes it. The backlight itself cannot be switched off.
- A short press of the front power button opens the POWER page. Holding
  it makes the printer's power controller cut the power by itself; the
  app can only warn.

## Pages

| Page | What is on it |
|---|---|
| Home | Temperatures and state; JOB, LAMP, FILAMENT, PREHEAT, MOVE, MACROS, SYSTEM, COOL DOWN. A paused print shows RESUME and CANCEL here. |
| Print (shown by itself during a print) | Progress, PAUSE / RESUME, CANCEL, Z baby-stepping in 0.025 mm steps, LAMP, OBJECTS (cancel one object of the print). |
| Starting | The "bed empty?" question and the start of the print (heat, home, mesh, purge), with CANCEL. |
| Filament | LOAD, UNLOAD, UNLOCK, DRYER. LOAD and UNLOAD ask for the material (it sets the nozzle temperature) or a CUSTOM temperature, show their steps while running, and on a stop (jam, filament not grabbed) offer TRY AGAIN or UNLOAD. |
| Bin | After the purge bin is emptied: DONE resets the count. |
| Macros | Buttons for the owner's own macros; EDIT picks which macros get a button. Each asks before it runs. |
| Preheat | Material presets and COOL DOWN. |
| Move | Jog, HOME, LOWER BED, CLEAN (nozzle), MOTORS OFF, EMPTY BIN, CALIBRATE, BED LEVEL. |
| Bed level | PROBE the bed and show how far to turn each screw, in eighths of a turn. |
| Calibrate | Z HEIGHT and PROBE OFFSET (the paper test, with SAVE / DISCARD), PID TUNE (nozzle or bed), INPUT SHAPING (with a USB accelerometer: [input_shaping.md](input_shaping.md)), SAVE Z OFFSET. |
| Dryer | Use the heated bed as a filament dryer: START, STOP DRYING. |
| System | KLIPPER (restart), NETWORK, DISPLAY, INFO, UPDATE, POWER. |
| Network | Addresses of both ports, Wi-Fi scan and saved networks (PREFER, FORGET), an on-screen keyboard for the password, DHCP or STATIC with a number pad. |
| Display | TIMEOUT (1 min to never) and CONSOLE (the kernel log, full screen). When the screen goes black the case lamp goes off with it, and comes back at its old brightness when the screen wakes (only while idle: a print keeps its light). |
| Info | Build and versions, the stock firmware version, storage. |
| Update | Mainsail through Moonraker's updater: CHECK NOW, UPDATE. |
| Power | SHUT DOWN, REBOOT, KLIPPER, SCREEN OFF. On our kernel, with a Sindoh update stick plugged in, TO STOCK reverts the printer to Sindoh's firmware after two confirmations. |
| Error | Shown when Klipper is shut down or cannot start, with the message and the buttons that help (restart, network). |

## The panel and touch controller (measured on the printer)

| | |
|---|---|
| Display | `/dev/fb0`, 800×480 at 60 Hz, 16 bpp RGB565 little-endian, stride 1600 |
| Mounting | **Portrait, 480×800 as the user sees it.** The app draws 480×800 and turns it 90° clockwise before writing: portrait (u, v) = fb (x = 799 − v, y = u). |
| Pages | Under the stock kernel the framebuffer is 800×960 virtual (two pages); the app writes both. |
| Touch | Rohm BU21029 (resistive, I²C). `/dev/event0` under the stock 3.2 kernel, `/dev/input/event0` under ours ([sindoh-kernel: touch_bu21029.md](https://github.com/catawalks/sindoh-kernel/blob/main/docs/touch_bu21029.md)). |
| Touch events | Multitouch protocol A only: ABS_MT_POSITION_X/Y, TRACKING_ID, TOUCH_MAJOR. No BTN_TOUCH. An empty frame, or about 0.3 s of silence, means the finger was lifted. |
| Event format | Under the stock kernel the 16-byte time32 `input_event`, so the app reads the device raw instead of using python-evdev. |
| Calibration | Axes swapped, raw x inverted: u = 0.14471 × raw_y − 66.6, v = 856.2 − 0.22272 × raw_x (four-corner test with `touch_cal.py`; corners agree to about ±4 px). |
| Front power button | GPIO bank 5 pin 27, 1 = pressed. |

## Other models

The 1X's panel is the same size in pixels (800×480, stored sideways) but
24 bit, and its touch device and buttons are not mapped yet. The app has
not been run there. See [1x_port_plan.md](1x_port_plan.md), stage 6.
