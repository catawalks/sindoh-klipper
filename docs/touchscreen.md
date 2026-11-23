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
| Move | HOME, JOG (X, Y, Z by 0.1 / 1 / 10 / 50 mm; the config macro `JOG`), LOWER BED, MOTORS OFF, CLEAN (nozzle), EMPTY BIN, BED LEVEL, CALIBRATE. |
| Bed level | PROBE the bed and show how far to turn each screw, in eighths of a turn. |
| Calibrate | Z HEIGHT and PROBE OFFSET (the paper test, with SAVE / DISCARD), PID TUNE (nozzle or bed), INPUT SHAPING (with a USB accelerometer: [input_shaping.md](input_shaping.md)), SAVE Z OFFSET. |
| Dryer | Use the heated bed as a filament dryer: START, STOP DRYING. |
| System | KLIPPER (restart), NETWORK, DISPLAY, INFO, UPDATE, POWER. |
| Network | Addresses of both ports, Wi-Fi scan and saved networks (PREFER, FORGET), an on-screen keyboard for the password, DHCP or STATIC with a number pad. |
| Display | TIMEOUT (1 min to never) and CONSOLE (the kernel log, full screen). When the printer has been idle (no print, heaters off) and untouched for the timeout, the screen program runs the config macro `SCREEN_TIMEOUT`, and `SCREEN_WAKE` at the next touch. As shipped the screen goes black and the case lamp goes off, and the lamp returns to its old brightness on waking. To change that, repeat `[gcode_macro SCREEN_TIMEOUT]` in printer.cfg with `variable_lamp: 0` (lamp stays on) or `variable_display: 0` (screen stays on), or replace the two macros. |
| Info | Build and versions, the stock firmware version, storage. |
| Update | Mainsail through Moonraker's updater: CHECK NOW, UPDATE. |
| Power | SHUT DOWN, REBOOT, KLIPPER, SCREEN OFF. On our kernel, with a Sindoh update stick plugged in, TO STOCK reverts the printer to Sindoh's firmware after two confirmations. |
| Error | Shown when Klipper is shut down or cannot start, with the message and the buttons that help (restart, network). |

## What a model's macros provide

One screen program serves every model. It has no per-model routines: a
button sends a command, and the model's macro file
(`dp200_macros.cfg`, `x1/x1_macros.cfg`) makes that command do the right
thing on its hardware. A button whose command the config does not define
is greyed out and says "not set up yet". For a new model, write these:

| Command | The screen sends it for | Notes |
|---|---|---|
| `LOAD_FILAMENT TEMP=<C>` | FILAMENT, LOAD | The screen always passes the temperature of the chosen filament as `TEMP=`. A macro may also accept `MATERIAL=` for use from the console. |
| `UNLOAD_FILAMENT TEMP=<C>` | FILAMENT, UNLOAD | As above. |
| `CARTRIDGE_RELEASE` | FILAMENT, UNLOCK | Cartridge latch. |
| `FILAMENT_DRY`, `FILAMENT_DRY_STOP` | FILAMENT, DRYER | |
| `CLEAN_NOZZLE` | MOVE, CLEAN | Counts a purge. |
| `EMPTY_BIN`, `BIN_EMPTIED` | MOVE, EMPTY BIN | Purges are counted in `save_variables` `bin_count`. |
| `JOG AXIS=<X/Y/Z> D=<mm>` | MOVE, JOG | Refuses an axis that is not homed, stops at the limits. |
| `G28`, `BED_CLEAR` | MOVE, HOME | Z homing needs `BED_CLEAR` first. |
| `BED_LEVEL SCRUB=<0/1>` | MOVE, BED LEVEL, on a model without a mesh probe | Three touches with the nozzle. The page shows the macro's `M117` line while it runs, then reads the result from the macro `_LEVEL`: `back`, `fl`, `fr` (touch heights), `click` (mm per wheel click), `cw_raises`, `ok`. A model that defines `BED_MESH_CALIBRATE` gets the DP200's mesh-and-screws page instead. |
| `SCREEN_TIMEOUT`, `SCREEN_WAKE` | the idle timeout | `variable_display`, `variable_lamp` say what goes dark. |
| `LAMP_TOGGLE` | LAMP | |

**Say what you are doing.** A routine that takes more than a few seconds
(load, unload, cleaning, anything that waits for a heater) announces each
step with `M117 <text>`. The screen's running page shows that line with
the nozzle temperature, and Mainsail shows it too, so nobody waits in the
dark. Rules:

- One short line per step, in plain words, naming a temperature the step
  waits for: `M117 Heating the nozzle to {temp|int} C`.
- Put `M400` before an `M117` that follows queued moves (`G1`, `G4`).
  Klipper reads ahead, so without it the line changes while the previous
  step is still moving.
- End the routine with a bare `M117`, which clears the line.
- Keep the steps in the order they happen; the screen shows only the
  current one.

The steps used so far, for the same wording on the next model: "Homing X
and Y", "Moving to the purge bin" (1X: "dump bin"), "Heating the nozzle
to N C", "Feeding to the extruder", "Feeding on while the nozzle heats",
"Waiting for the nozzle to reach N C", "Feeding to the nozzle", "Purging
into the bin", "Wiping the nozzle", "Pulling the filament out of the
nozzle", "Pulling the filament back".

Before `M117` existed in the macros the page guessed the step from the
homing state and the temperature; it still does when a macro sends no
line.

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

**1X** (bring-up, beside Sindoh's own system; started by
`install/x1/x1_web.sh`). Same app; the panel is the same size in pixels
(800×480, stored sideways) but 24 bit. What differs while stock still
runs underneath:

- **NETWORK** shows both ports (address, gateway, MAC, DNS). Joining a
  WiFi network and the IP settings stay on Sindoh's side for now, so
  those three buttons are off. The WiFi name is not shown (the WiFi
  program's socket is on the stock side).
- **POWER:** SHUT DOWN and REBOOT are done by a helper on the stock side
  (`x1_web.sh powerd`, see the script). The app turns heaters and motors
  off, draws its progress frames and writes the request to
  `/run/dp200/power`; the buttons are off unless the helper's flag
  `/run/dp200/power.ok` exists. A reboot starts Sindoh's firmware:
  Klipper has to be started again. The front power button is Sindoh's
  business there: its program `/app/powerkeyd` keeps running and, when
  the button is held, saves the files and cuts the power, also during
  a print. (The program acts 20 ms after its input changes, but that
  input comes from the power circuit, not straight from the button:
  the owner has to hold it. Hold time not measured.)
- **UPDATE:** Moonraker's updater for Mainsail, as on the DP200
  (`install/x1/x1_moonraker.conf`). Klipper and Moonraker are pinned to
  the commits on the card.
- **INFO:** `x1_web.sh` writes `/run/dp200/stock_info` (kernel, Sindoh
  firmware version, model ID, serial number), which the DP200's start
  script does there.
