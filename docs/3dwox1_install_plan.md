# 3DWOX 1 (and Mimaki 3DFF-222): installer plan

**Status (2026-11-24): plan, nothing built.** We have no 3DWOX 1. The
config in `klipper/config/3dwox1/` is Fredrik Gustafsson's (untested by
us), and the installer refuses the 3DWOX 1's firmware line by name. This
page is what it takes to install on one, the same way the DP201 was
added: from the stock firmware's own data, marked untested until an
owner tries it.

Sources: sindoh `docs/3dwox1.md` (Fredrik's unit and Sebastian Schmidt's
dumps), sindoh `docs/model_ids.md` (the model tables, the board check),
sindoh `docs/other_models.md` (the update folder and key).

## What the 3DWOX 1 line is

| | DP200 line | 3DWOX 1 line |
|---|---|---|
| Firmware tag | `RODIN_200730_2` | `RODUP_...` (Fredrik `RODUP_200730_4`, newest `RODUP_220111_1`), `RODIN_SUB=U` |
| Chip, kernel | 88PA6170, `3.2.0-g67a8e16` (#6, 2016) | the same chip and version string (#20, 2018) |
| NAND layout | | the DP200's `mtdparts` (Sebastian's dump) |
| USB folder, cipher | `_update_rodin`, des3 | `_update_rodin_up`, AES `sindoh024601779U` |
| Model IDs | the DP200/DP201 lists | `3D1Q` `3D1AQ` `3D1CQ` `3D1KQ` `3DP103` `RDPU0000-SQ` and their H forms (code `0x08000100`); **Mimaki 3DFF-222**: `3D1JQ` `3D1JH` (`0x40001000`) |
| Driver boards | A4982 | **two**: A4982, or TMC2224 ("Trinamic"), told apart by the board-select pin (GPIO bank 2 pin 0) |
| Free root space | ~100 MB | 34.5 MB on Fredrik's unit |

The motion code tests no brand bits, so the Mimaki needs nothing of its
own (sindoh `docs/model_ids.md`).

## Steps

1. **The stick.** Build the `.she` files twice: des3 for
   `_update_rodin/` (as now) and AES with the 3DWOX 1 key for
   `_update_rodin_up/` (`pack_she.sh` gets a cipher option). One stick
   then serves both lines; the payload is shared.
2. **The checks** (`unmistakable_klipper_install.sh`):
   - firmware: accept `RODUP_` beside `RODIN_200730_2`; which `RODUP_`
     versions to take is open (Fredrik ran `200730_4`; the kernel version
     string matches all of them, but `upctool` and `cdc-acm.ko` were only
     run on the DP200's 2016 build: Fredrik ran upctool on his unit).
   - model: `FAMILY=3dwox1` for the IDs above, refused on a `RODIN_`
     firmware and the DP200 IDs refused on `RODUP_`.
   - space: the NAND root has 34.5 MB free on Fredrik's unit, where the
     DP200 install needs about 106 MB. Either the install frees stock
     files (as on the DP200: the Sindoh app and WebKit go to the stick)
     and still fits, or the 3DWOX 1 installs to the SD card only. To
     measure from a survey report first.
3. **The config as a model file:** turn `3dwox1_printer.cfg` into
   `dp200_model_3dwox1.cfg` (the DP200's bed sections plus Fredrik's
   3DWOX 1 values), so the 3DWOX 1 uses the same `printer.cfg`,
   `dp200_printer.cfg` and `dp200_macros.cfg` as the DP200, and the
   installer copies it to `dp200_model.cfg`. The separate
   `klipper/config/3dwox1/printer.cfg` then goes.
4. **The two driver boards:**
   - Motor current: the stock program sets all offsets to 99 on the
     TMC2224 board and keeps the stored ones on the A4982 board, so the
     installer's `dp200_machine.cfg` (from the database) already matches
     stock on both. Mark the board in that file (all 99 = TMC2224).
   - **TMC2224 set-up (the open part):** the stock app writes the
     drivers' registers over a serial line (CHOPCONF 16 microsteps, GCONF
     with `I_scale_analog`); without the stock app they stay at power-on
     defaults. Before a TMC2224 unit runs from NAND, read from the
     3DWOX 1's stock program exactly what it writes and on which port
     (Fredrik: `/dev/ttyS2`; our DP200 notes have `ttyS2` as the power
     MCU link), and do the same in our start script.
   - Read the board-select pin at boot and refuse to start Klipper if it
     does not match `dp200_machine.cfg` (a board swap).
5. **Boot hook and Wi-Fi:** the DP200 hook as is; Fredrik found that a
   start without the stock app leaves Wi-Fi without DHCP on his
   firmware: check our hook starts `udhcpc`.
6. **Remover, updates:** the same remover from `_update_rodin_up/`;
   upgrades as on the DP200.
7. **Test, with an owner** (none here): the survey stick first (space,
   board, model ID), then an SD-card install, homing with the bed empty,
   then NAND.

## Open questions

- Which `RODUP_` versions to accept.
- Room on the NAND root (34.5 MB free on one unit).
- What the stock program writes to the TMC2224s, and over which port.
- A 3DWOX 1 owner to test (Fredrik's unit has the TMC2224 board).
