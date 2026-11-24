# Documentation map and rules

Users: start with [INSTALL.md](INSTALL.md). This page is for people
working on the project.

The project is split over several repositories (listed in the
[top README](../README.md)): this one holds the installer, configs,
screen app and their docs; kernel and boot documents are in
[sindoh-kernel](https://github.com/catawalks/sindoh-kernel); notes on
other printer models are in [sindoh](https://github.com/catawalks/sindoh).

Read in this order when you pick the project up:
1. [STATUS.md](STATUS.md): what runs on each printer today, and who owns what.
2. [../TODO.md](../TODO.md): open items only.
3. [../PROJECTS.md](../PROJECTS.md): larger projects, with decisions.
4. The reference document for your area (table below).

## Where things go

| Kind of information | Its one home | Rule |
|---|---|---|
| Current state of the printers, sessions and their areas | `docs/STATUS.md` | Overwrite in place. One page. No history. |
| Open work | `TODO.md` | Open items only, a few lines each. When an item is done, delete it and add a line to the changelog. |
| What was done, and when | `docs/history/CHANGELOG.md` | Append, newest first: date, one or two lines, the commit. |
| Larger projects and decisions | `PROJECTS.md` | Status line first. Decisions with their date. |
| How a thing works (facts, measured values) | one reference doc in `docs/` (kernel and boot: the sindoh-kernel repo; other models: the sindoh repo) | Describe how it is now. No dated diary. Each fact lives in one file; other files link to it. |
| A plan that is not finished | `docs/*_plan.md` | Status line on top. When finished or dropped, move it to `docs/history/` with a `**Status:**` line and fold the lasting facts into a reference doc. |
| Test logs, investigations, session notes, raw captures | `docs/history/` (kernel ones in sindoh-kernel's `docs/history/`) | Never in `TODO.md` or a reference doc. Start each with a `**Status:**` line (SOLVED / DONE / SUPERSEDED / HISTORY) and where the live facts are. |
| Anything that needs the owner at the printer | `TODO.md`, section "Owner at a printer" | One list. (`docs/history/printer_checks_2026-10-31.md` is folded into it.) |

Rules that keep it tidy:
- **One home per file, too.** Klipper code lives in the fork, printer
  configuration here: [../klipper/README.md](../klipper/README.md).
- **One home per fact.** NAND partitions and the boot path: `nand_layout.md`.
  Network settings: `network.md`. Wi-Fi setup and the 8782 driver:
  `wifi.md`, and `wifi_88w8782.md` in sindoh-kernel. Link, don't copy.
- **Same commit.** Update `TODO.md`, `STATUS.md` and the changelog in the
  commit that does the work.
- **Sections, not sprawl.** A session edits only its own area's entries in
  `TODO.md`; the coordinating session merges and publishes.
- **No results in TODO.md.** A test result is one changelog line plus, if
  the detail matters, a file in `docs/history/`.
- **Dates are absolute** (2026-11-12, not "yesterday").
- **Nothing is deleted from history**; it is moved there.
- Code comments and kernel patches may still name a document by its old
  path. If it isn't there, it is in `docs/history/` under the same name.

## Reference documents

| Area | Document |
|---|---|
| Install from the USB stick (stock 3.2 kernel) | [INSTALL.md](INSTALL.md), [usb_installer.md](usb_installer.md) |
| Before a public release | [release_checklist.md](release_checklist.md) |
| NAND partitions, boot path, write rules | [nand_layout.md](nand_layout.md), [nand_restore.md](nand_restore.md), [sindoh-kernel: nand_boot_cmdline.md](https://github.com/catawalks/sindoh-kernel/blob/main/docs/nand_boot_cmdline.md) |
| End-goal install (our kernel + root in NAND) | [end_goal_install_plan.md](end_goal_install_plan.md), [internal_firmware_plan.md](internal_firmware_plan.md), [sindoh-kernel: revert_to_stock_plan.md](https://github.com/catawalks/sindoh-kernel/blob/main/docs/revert_to_stock_plan.md) |
| Mainline kernel | [sindoh-kernel: no_gpl_plan.md](https://github.com/catawalks/sindoh-kernel/blob/main/docs/no_gpl_plan.md), [sindoh-kernel: smp_freeze_summary.md](https://github.com/catawalks/sindoh-kernel/blob/main/docs/smp_freeze_summary.md), [sindoh-kernel: upc_mainline_design.md](https://github.com/catawalks/sindoh-kernel/blob/main/docs/upc_mainline_design.md), [sindoh-kernel: debian_root_boot.md](https://github.com/catawalks/sindoh-kernel/blob/main/docs/debian_root_boot.md), [sindoh-kernel: rtc_setup.md](https://github.com/catawalks/sindoh-kernel/blob/main/docs/rtc_setup.md), [sindoh-kernel: touch_bu21029.md](https://github.com/catawalks/sindoh-kernel/blob/main/docs/touch_bu21029.md) |
| Wi-Fi and network | [wifi.md](wifi.md), [network.md](network.md), [sindoh-kernel: wifi_88w8782.md](https://github.com/catawalks/sindoh-kernel/blob/main/docs/wifi_88w8782.md) |
| Hardware facts | [hardware_notes.md](hardware_notes.md), [stock_routines.md](stock_routines.md), [sindoh-kernel: 6270_vs_6170.md](https://github.com/catawalks/sindoh-kernel/blob/main/docs/6270_vs_6170.md), sindoh-kernel's `docs/uboot_*.txt` and `docs/vendor_*` |
| Klipper code and configuration: what lives where | [../klipper/README.md](../klipper/README.md) |
| Testing on the dev printer: rules, switching Klipper builds, the standard tests, probe calibration | [dev_printer_testing.md](dev_printer_testing.md) |
| Motion and stepping | [faster_stepping_plan.md](faster_stepping_plan.md), [input_shaping.md](input_shaping.md) |
| Touch screen app | [touchscreen.md](touchscreen.md) |
| Other topics | [cartridge_chip.md](cartridge_chip.md), [sindoh: other_models.md](https://github.com/catawalks/sindoh/blob/main/docs/other_models.md), [sindoh: 3dwox1.md](https://github.com/catawalks/sindoh/blob/main/docs/3dwox1.md), [sindoh: 1x.md](https://github.com/catawalks/sindoh/blob/main/docs/1x.md), [sindoh: prime_sd.md](https://github.com/catawalks/sindoh/blob/main/docs/prime_sd.md), [sindoh-kernel: sd_boot_plan.md](https://github.com/catawalks/sindoh-kernel/blob/main/docs/sd_boot_plan.md), [sindoh-kernel: jtag_prep.md](https://github.com/catawalks/sindoh-kernel/blob/main/docs/jtag_prep.md), [sindoh-kernel: marvell_github.md](https://github.com/catawalks/sindoh-kernel/blob/main/docs/marvell_github.md) |
| The 1X port | [1x_port_plan.md](1x_port_plan.md); [1x_install_plan.md](1x_install_plan.md) (install, boot, uninstall, update); [1x_slicer_profiles.md](1x_slicer_profiles.md) (Sindoh's slicer settings against ours); facts in [sindoh: 1x.md](https://github.com/catawalks/sindoh/blob/main/docs/1x.md) |
| History | [history/CHANGELOG.md](history/CHANGELOG.md), everything else in `history/` |
