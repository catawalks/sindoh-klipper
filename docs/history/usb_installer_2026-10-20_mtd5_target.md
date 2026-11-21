# USB installer: the mtd5 target of 2026-10-20

**Status: SUPERSEDED** (moved 2026-11-21 out of `docs/usb_installer.md`). On
2026-11-02 the stock root (mtd6) became the NAND target; mtd5 holds
Sindoh's recovery set and is never written. Current design:
[../usb_installer.md](../usb_installer.md).

## Update 2026-10-20: internal NAND is now the default target (superseded)

- **Target:** the installer writes Klipper to **mtd5 "recovery"** as UBI
  volume `klipper` (ubi2), mounted on `/klipper`. Before formatting it, it
  saves the partition to the stick: `nanddump -o -b` → `mtd5_recovery_backup.bin`
  + `.md5`, the exact stream `nandwrite -p` writes back.
  An empty file `_update_rodin/target_sd` selects the old SD-card target.
- **Boot:** `hook_install.sh` now copies `dp200-boot.sh` to `/etc/dp200-boot.sh`.
  This stage 1 attaches mtd5, mounts the volume, and starts
  `<root>/dp200/dp200-start.sh`; it falls back to the SD card.
  `dp200-start.sh` works out its root from its own path. On NAND, logs go to
  tmpfs (flash wear).
- **Remove stick:** restores the stock boot. If the backup + md5 are on the
  stick, it also writes mtd5 back (`flash_erase` + `nandwrite -p`).
- **Payload:** `make_payload.sh` builds the **runtime** image by default
  (`install/nand/runtime.exclude`: no compilers, docs or caches), plus a
  generic `printer_data`. This printer's calibration, database, logs and
  G-code are never shipped. `full` builds the whole tree for SD installs.
  Debian's tar runs inside the chroot (it needs Debian's libraries).
- **Rehearsal:** `DRY_RUN=1` (or a `dry_run` file in the folder) runs every
  check, unpacks with the **stock BusyBox tar** into `/mnt/sd/dryrun_root`,
  and verifies the key files. There's no screen, no flash access (it does
  not even attach mtd5, since UBI can write when attaching), no hook and no
  reboot.
