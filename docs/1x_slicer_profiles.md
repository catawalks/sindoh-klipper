# 1X: Sindoh's slicer settings and ours

What Sindoh's own slicer and its profiles for other slicers set for the
1X, next to what our test prints and config use. Read 2026-11-22 from
the owner's copies (none of it is in a repository):

- **3DWOX Desktop 1.6** (Sindoh's slicer): its `profile\` folder (23
  models; per model a machine file, the start/end code and the print
  profiles), an XYZ calibration cube sliced for the 1X with "Fast", and
  the line test stored on the printer (`/example/PLA/`, version 1.5).
- **Cura:** Sindoh's `Cura_Settings.zip` (definitions for the 3DWOX 1,
  1X, 2X and 7X, quality and material files) and its manual.
- **Simplify3D:** `Sindoh_3DWOX1_PLA.fff` (3DWOX 1 only) and its manual.

How the stock firmware treats a print file (coordinates, start code) is
in [sindoh: 1x_stock_routines.md](https://github.com/catawalks/sindoh/blob/main/docs/1x_stock_routines.md),
"Print files".

## PLA print settings

"Ours" is `tools/gen_test_prints.py --model x1`.

| Setting | 3DWOX Desktop "Normal" | Cura 1X "Normal" | Simplify3D (3DWOX 1) | Ours |
|---|---|---|---|---|
| Layer height | 0.2 | 0.2 | 0.2 | 0.2 |
| First layer | 0.2 high, 100 % wide | 0.2 | 0.22 | 0.25 high, 0.45 wide |
| Line width | 0.4 | 0.4 | 0.4 | 0.45 |
| Flow | 100 % | 100 % (ABS 110 %) | 90 % | 100 % |
| Nozzle | 200 C | 200 C | 195 C | 210 C |
| Bed | 60 C | 60 C (Cura's default) | 60 C | 60 C |
| Print speed | 40 mm/s | 40 | 40, outlines 20 | 40 (since 11-22; first print 30) |
| First layer speed | 20 mm/s | 20 | 20 | 20 |
| Top / bottom speed | 20 mm/s | | | as the rest |
| Travel | 130 mm/s | 130 | 80 | 130 (since 11-22; first print 100) |
| Retract | 6 mm at 30 mm/s | 6 at 30 | 6 at 40, coast 0.2, wipe 3 | 6 mm at 35 (since 11-22; first print 5) |
| Part fan | 50 % from 0.6 mm | 50 % from the third layer | 100 % from layer 2 | 100 % from the third layer |
| Walls | 0.8 mm | 0.8 mm | 2 | 2 |
| Top / bottom | 0.8 mm | 0.8 mm | 3 layers | 3 bottom layers |
| Infill | 15 % | 15 %, lines | 20 % | none (open box) |
| Bed adhesion | raft | raft | skirt, 2 lines | skirt, 2 lines, 3 mm gap |
| Z offset without a raft | -0.15 mm | | -0.15 mm (M206) | none |

3DWOX Desktop's other 1X profiles (PLA):

| Profile | Layer | Print | First layer | Top/bottom | Travel |
|---|---|---|---|---|---|
| Fast | 0.2 | 60 mm/s | 20 | 20 | 130 |
| Normal | 0.2 | 40 | 20 | 20 | 130 |
| Fine | 0.1 | 25 | 20 | 10 | 60 |
| Silent | 0.2 | 40 | 20 | 20 | 60 |

ABS: 230 C, bed 90 C, fan 8 %, retract 3 mm. Flexible: 240 C, 30 mm/s,
retract 7 mm at 70 mm/s, travel 100 mm/s.

Where ours differs, and why:

- **Nozzle 210 C** is the stock firmware's own PLA first-layer value
  (210, then 200); the slicer profiles say 200.
- **First layer 0.25 x 0.45:** kept (owner 11-22). Thicker and wider
  forgives height error and sticks better; Sindoh's thinner first layer
  normally sits on a raft, which hides an uneven bed and a rough Z zero.
- **Fan 100 %:** Sindoh runs PLA at 50 %. Not changed yet.
- **Speeds:** ours are Sindoh's "Normal"; "Fast" (60 mm/s) is the next
  step, more with input shaping (TODO 41).

## Machine limits

| | 3DWOX Desktop | Cura definition | Stock program (measured) | Our config |
|---|---|---|---|---|
| Bed | 228 x 200 x 300 | 228 x 200 x 300 | X -3.1 to 262.7, Y to 200 | X -8 to 262.7, Y 200.5, Z 310 |
| Max speed X, Y | 600 mm/s (no meaning) | 200 | ramp tables to 197.7 | 197 |
| Max speed Z | 40 (no meaning) | 10 | 12.0 | 12 |
| Max speed E | 25 | 50 | 86.7 | 86 (extrude-only) |
| Acceleration X, Y | 2500 mm/s2 | 2000 (default 2500) | about 1460 average | 2500 |
| Acceleration Z | 100 | 100 | about 110 | 100 |
| Corner speed X/Y, Z, E | 25, 0.4, 5 | 50, 0.1, 5 | 20, 0.1, 5 (database) | Klipper's default |

The same machine values serve nearly every model in 3DWOX Desktop; the
5X and 7X have 1600 mm/s2 and corner speed 20, the "1X DP302" 800 and 8.
Bed sizes: DP200, 3DWOX 1, DP102/103 210 x 200 x 195; 2X as the 1X; 5X
350 x 350 x 350; 7X 370 x 390 x 450. Nozzles 0.4, with 0.2 and 0.6
selectable.

## Start and end code

Every model in 3DWOX Desktop has the same:

    M107            ; fan off
    G200            ; nozzle cleaning
    G21, G90
    G92 E-20        ; with the later "G1 E0": feed 20 mm
    ...             ; the slicer adds M140/M104, M190/M109, G28, M298
    M2              ; end: the firmware does the rest

Cura's 1X definition has the same plus `G28`, `G1 F800 E0`, `G0 Z1.0`.
Our `PRINT_START BED= EXTRUDER=` and `PRINT_END` do those things in
macros; `G200`, `M298` and `M2` are not defined in our config, so a
file sliced with Sindoh's start code does not run on our port as it is.

A Cura post-processing script in the archive
(`DisplayInformationIn3DWOX.py`) writes the comment lines the stock
screen shows: `;ESTIMATION_TIME`, `;TOTAL_LAYER`, `;DIMENSION`,
`;ESTIMATION_FILAMENT_CARTRIDGE_0`.

## Mirroring: nothing in Sindoh's chain does it

- 3DWOX Desktop does not mirror: the calibration cube's engraved Z,
  drawn from the G-code with X to the right and Y up, reads as a
  normal Z.
- The Cura definition has no mirror setting; Simplify3D's
  `flipXoverride` is 1, its "not flipped".
- The stock program passes a file's X straight through, in the frame
  our config uses (sindoh `1x_stock_routines.md`).

So a file prints under our config exactly as under stock. Stock prints
have never come out mirrored on this printer (owner 11-22). Sindoh's
slicer centers the bed at X 114, Y 100; our test prints use X 110
(TODO 41).
