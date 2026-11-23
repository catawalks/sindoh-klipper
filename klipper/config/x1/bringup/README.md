# 1X bring-up configs (history)

The step-by-step test configs of the port's stages 4 and 5
([docs/1x_port_plan.md](../../../../docs/1x_port_plan.md)), kept for
reference. None of them is a printer config: use `printer.cfg`,
`x1_printer.cfg` and `x1_macros.cfg` one folder up.

| File | What it tested |
|---|---|
| `x1_stage4.cfg` | Look only: thermistors and inputs, no output defined |
| `x1_stage5a.cfg` | Lights, beeper, fans |
| `x1_stage5b.cfg` | X, Y, Z as manual steppers |
| `x1_stage5c.cfg` | Both heaters at low limits |
| `x1_stage5d.cfg`, `x1_stage5e.cfg` | Extruder motor attempts |
| `x1_stage5f.cfg` | Filament switches and the feed path |
| `x1_stage5g.cfg` | A real `[extruder]`, load and unload on the sensors |

On the printer they are started as
`x1_stage4.sh start x1_stage5a.cfg` from the card's `stage` folder.
