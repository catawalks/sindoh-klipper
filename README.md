# Klipper for Sindoh 3DWOX printers

[Klipper](https://www.klipper3d.org/), Moonraker and Mainsail running on
the printer's own mainboard. No extra hardware, no opening the printer:
it installs from a USB stick with Sindoh's own update mechanism, and a
second stick file puts the Sindoh firmware back.

**Status: v0.1.0, a beta.** It prints well on the maintainer's printers,
but it is young. Read the install guide fully before you start.

| | |
|---|---|
| **Supported printers** | Sindoh 3DWOX **DP200** (and the identical **DP102**) and its rebrands (Stanley Model 1, Leon 3D, ESUN China), also converted to DP200Q, on Sindoh firmware `RODIN_200730_2`. The stock firmware runs them all alike: only the boot logo and the regional defaults differ (catawalks/sindoh `docs/model_ids.md`) |
| **Not yet** | DP201 (same firmware, but PLA only with no heated bed: its config is written, untested, for the next release), 3DWOX 1, 2X, 1X, 7X (the installer refuses them by name; a 1X port is in progress, see [docs/1x_port_plan.md](docs/1x_port_plan.md)). Research on them: [catawalks/sindoh](https://github.com/catawalks/sindoh) |
| **Download** | [Releases](https://github.com/catawalks/sindoh-klipper/releases) |
| **Install guide** | [docs/INSTALL.md](docs/INSTALL.md) |
| **Slicer profiles** | [install/slicer/](install/slicer/) (PrusaSlicer, OrcaSlicer, Cura) |

## What you get

- Mainsail in your browser, over Wi-Fi or Ethernet.
- A touch screen app on the printer: home, preheat, load/unload, lamp,
  Wi-Fi setup, and an emergency STOP on every page.
- Bed mesh with the built-in probe, pause/resume, the webcam, and the
  beeper (`M300`).
- Your calibration lives in one file, `printer.cfg`, which updates never
  overwrite.

## Two things to know before printing

- **Z homes upward.** The bed rises to the nozzle, so anything left on the
  bed is crushed. Every print start asks "Is the bed empty?".
- **Klipper replaces Sindoh's heater protection** with its own (temperature
  limits, `verify_heater`, and outputs that switch off if the host stops).
  Watch the first print.

## How it works

Klipper's host software runs on the printer's Linux. The two real-time
"UPC" cores of the Marvell 88PA6170 chip, which ran Sindoh's motion and
heater code, run the Klipper MCU firmware instead.

```
 Linux ── Debian root ─────────────────────────────────────────────────────┐
 │ nginx+Mainsail :80 ── Moonraker :7125 ── klippy        touch screen app │
 │                                      ├── /tmp/klipper_upc_fm ─┐         │
 │                                      └── /tmp/klipper_upc_io ─┤ upctool │
 └───────────────────────────────────────────────────────────────┼─────────┘
                       DTCM rings (shared 256 KiB TCM, /dev/mem) │
   UPC FM core (/dev/upc1): steppers, endstops, motor current    │
   UPC IO core (/dev/upc0): heaters, fans, thermistors      ─────┘
```

The USB stick install runs on Sindoh's stock Linux 3.2 kernel. A later
"end goal" install puts our own mainline kernel in the printer as well
([docs/end_goal_install_plan.md](docs/end_goal_install_plan.md)); that is
still in development.

## The project's repositories

| Repository | What it holds |
|---|---|
| **sindoh-klipper** (this one) | The installer, printer configs, the touch screen app, tools and docs |
| [catawalks/klipper](https://github.com/catawalks/klipper/tree/sindoh-dp200), branch `sindoh-dp200` | The Klipper code itself: the UPC MCU port and host modules. [klipper/FORK](klipper/FORK) pins the commit a release is built from |
| [catawalks/sindoh-kernel](https://github.com/catawalks/sindoh-kernel) | The mainline Linux kernel port for the 88PA6170 (not needed for the USB stick install) |
| [catawalks/sindoh](https://github.com/catawalks/sindoh) | Hardware research: other models, teardown notes, the Model 1 converter |
| [catawalks/sindoh-model-survey](https://github.com/catawalks/sindoh-model-survey) | A read-only USB stick that reports a printer's hardware, to help support more models |
| [catawalks/sindoh-boot-logo](https://github.com/catawalks/sindoh-boot-logo) | Custom boot logo maker |

## For developers

| Read | For |
|---|---|
| [docs/README.md](docs/README.md) | The documentation map |
| [docs/STATUS.md](docs/STATUS.md) | What runs on each test printer today |
| [TODO.md](TODO.md), [PROJECTS.md](PROJECTS.md) | Open items; larger projects and decisions |
| [docs/history/CHANGELOG.md](docs/history/CHANGELOG.md) | What was done, by date |

| Path | What |
|---|---|
| `install/usb/` | The USB installer and remover, and the payload builder |
| `install/display/` | The touch screen app |
| `install/printer/`, `install/rootfs/` | Boot hook and service scripts |
| `install/slicer/` | Slicer profiles |
| `klipper/config/` | `printer.cfg` (yours), `dp200_printer.cfg`, `dp200_macros.cfg` and the model files `dp200_model_dp200.cfg` / `_dp201.cfg` / `_dp203.cfg` (replaced on updates; the installer copies the right one to `dp200_model.cfg`); `printer_dp201.cfg` is the DP201's first `printer.cfg` |
| `klipper/FORK` | The Klipper fork commit the printers build |
| `common/`, `host/upctool.c` | The UPC register map, and the Linux tool that loads and bridges the UPC firmware |
| `upc_fw/probe/` | A passive hardware probe firmware |
| `tools/` | Development and test scripts for the dev printer ([tools/README.md](tools/README.md)) |
| `docs/` | Documentation |

## Credits

Klipper, Moonraker and Mainsail and their authors. Fredrik Gustafsson for
the first 3DWOX 1 tests and notes. Sebastian Schmidt for his 2021 3DWOX 1
research, where this started.

## License

Free and open source under the **GNU General Public License, version 3 or
(at your option) any later version**: see [LICENSE](LICENSE). That is the
license of Klipper, Moonraker and Mainsail too.

Nothing from Sindoh or Marvell (firmware, images, apps, Wi-Fi firmware)
is part of this repository or its releases.
