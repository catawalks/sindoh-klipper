# Development and test tools

Scripts used while developing on the dev printer. None of them is needed
to install or use Klipper. Each file starts with a comment that says what
it does and how to run it. Rules for testing on a printer are in
[../docs/dev_printer_testing.md](../docs/dev_printer_testing.md): above
all, **Z homes upward**, and anything that moves or heats needs the owner
at the printer.

Where they run: `.ps1` and most `.py` files on the PC (over the serial
console or the network); `.sh` files on the printer.

## Talking to the printer

| File | What |
|---|---|
| `serial_cmd.ps1`, `serial_watch.py`, `serial_push.py` | Run a command on the serial console; record its output; push files over serial |
| `net_send.py`, `fetchall.sh` | Send a file over TCP; fetch test files from the PC with size checks |
| `klog.sh` | Mark and check the kernel log around every test |
| `fb_grab.py` | Save the touch screen's framebuffer as a PNG |
| `remote_shell/` | SSH on a stock printer from a USB stick (made for the 1X) |

## Building and switching Klipper on the dev printer

| File | What |
|---|---|
| `fork_build_on_printer.sh`, `fork_build_install.sh` | Build the fork's firmware and helper on the printer; install that build |
| `fork_check.sh` | Check that Klipper code lives only in the fork |
| `klippy_switch.sh`, `firmware_swap.sh`, `fm_rebuild.sh`, `kbuild_load.sh` | Switch between Klipper builds; swap or rebuild only the UPC firmware |
| `klippy_build_chelper.sh`, `klippy_batch_check.sh`, `kbuild.py` | Build klippy's C helper; offline config check; build the firmware on Windows |
| `payload_prep.sh`, `payload_verify.sh` | Prepare and verify the USB installer payload |

## Config checks and generators

| File | What |
|---|---|
| `cfgcheck.py`, `cfglint.py` | Check pin names against the firmware; compile every G-code macro |
| `gen_thermistors.py`, `rescale_sensor.py` | Thermistor tables from Sindoh's lookup tables; rescale to reference readings |
| `gen_test_prints.py`, `print_watch.py` | Simple test prints without a slicer; start a print and watch it |

## Hardware tests through Klipper (owner at the printer)

| File | What |
|---|---|
| `kstatus.py`, `kreset.py`, `khost.py` | Identify the two MCUs; reset them; read-only hardware test |
| `kwatch.py`, `ksense.py`, `kbuttons.py`, `regwatch.py` | Watch input pins and registers for changes (read-only) |
| `ktest_*.py`, `kmove.py` | One test each: fans, heaters, homing, moves, probe, filament feed, load, unload |
| `drift_test.py`, `probe_repeat.py`, `probe_settle.py`, `bed_soak.ps1` | Lost-step test; probe repeatability and settling; bed heat soak |
| `fast_stepping_*.py` | Step-rate and load measurements for the faster stepping work |
| `beep_test.sh`, `bed_pose_sweep.sh` | Beeper test; bed camera pose sweep |

## 3DWOX 1X bring-up

The 1X runs our programs from an SD card beside its stock system
([../docs/1x_port_plan.md](../docs/1x_port_plan.md)); its start scripts
are in `../install/x1/`. Its stock Linux has no Python: the `.py` files
run inside the card's Debian root or on the PC.

| File | What |
|---|---|
| `x1_query.py`, `x1_gcode.py`, `x1_sens.py` | Klipper's state; send G-code through the API socket; watch the filament switches |
| `x1_estopd.py` | Emergency stop over the network (any connection to its port stops Klipper) |
| `x1_tmc.py` | Read the TMC2224 drivers, compare with what stock sets, set them up for a cold start |
| `x1_current_test.py`, `x1_speed_test.py` | Which reference output feeds which motor; does an axis keep its position at speed (owner at the printer) |
| `x1_home_sections.sh` | Home a manual stepper in short sections (first motion tests) |
| `x1_gpiolog.sh`, `x1_fbshot.py`, `x1_ucode_probe.py` | Log GPIO changes; turn a copy of the stock screen into a PNG; run the stock microcode in an emulator |
| `../host/movewatch.c`, `../host/regwatch.c` | Record a running stock printer move by move, or once a second (read-only) |

## Studying the stock firmware

| File | What |
|---|---|
| `dbdump.py`, `dbcols.py`, `stockparams.py` | Read Sindoh's settings database (`karas.db`) |
| `fmseq.py`, `fmprobe.py`, `pwmprobe.py`, `engtest.sh`, `engabort.sh` | Emulate or exercise the stock motion and heater microcode |
| `kemu.py`, `pemu.py`, `clkcheck.py` | Run our UPC firmware in an emulator |
| `armdis.py`, `elfdis.py`, `kodis.py`, `vfpscan.py` | Disassemblers and scanners for ARM code |
| `cartridge_probe.py`, `memdump.py`, `regsnap.sh` | Read-only probes: cartridge chip, physical memory, SoC registers |
| `kernel_re/`, `ikconfig.py` | Extract and study the stock kernel image |
| `stock_wifimon.sh` | Watch Wi-Fi state on the stock system |

## Kernel, boot and NAND (for [sindoh-kernel](https://github.com/catawalks/sindoh-kernel))

NAND writes need the owner's OK every time; see
[../docs/nand_layout.md](../docs/nand_layout.md).

| File | What |
|---|---|
| `uboot_cmd.py`, `uboot_upload.py`, `uboot_timing.py`, `uboot_baud_scan.py` | Work at the U-Boot prompt safely; upload to RAM; time a boot |
| `sd_raw_install.sh`, `sd_raw_boot.sh`, `sd_kernel_boot.sh`, `eth_kernel_boot.sh` | Put a test kernel on the SD card and boot it from RAM |
| `sd_stock_boot.sh`, `rescue_stock_boot.sh` | Recovery: boot the stock system from the SD card |
| `mtd0_kernel_update.sh` | Replace our kernel in NAND (owner's OK) |
| `end_goal_stage4.sh`, `end_goal_stage5.sh` | Steps of the end-goal install on the dev printer |
| `nand_*.py`, `nand_*.sh`, `bulkread.py`, `pagetest.sh`, `nfcregs.py`, `ndcrpoke.py` | NAND read checks, soaks and controller register dumps |
| `ubi_*.py`, `ubi_*.sh`, `mtd3_rewrite_check.py` | UBI checks and the staged write tests |
| `hang_logger.sh` | Log what a hanging kernel still exposes |
| `jtagulator.py` | Talk to a JTAGulator |
