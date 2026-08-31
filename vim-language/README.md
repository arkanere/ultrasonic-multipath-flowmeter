# Ultrasonic Multipath Flow Meter — Vimscript

A Vimscript implementation of a transit-time differential ultrasonic flow meter
for educational purposes. It computes the same physics as the [C
implementation](../c-language/), running headless under `vim -es` — an editor
scripting language pressed into service as a general-purpose one.

## Table of Contents

- [Overview](#overview)
- [Physics & Theory](#physics--theory)
- [Architecture](#architecture)
- [Running](#running)
- [Interactive Usage](#interactive-usage)
- [File Descriptions](#file-descriptions)
- [Example Output](#example-output)
- [Vimscript Idioms Used](#vimscript-idioms-used)
- [Further Learning](#further-learning)

## Overview

Ultrasonic flow meters measure liquid flow non-invasively by comparing how long
an ultrasonic pulse takes to cross the pipe with the flow versus against it. No
moving parts, no pressure drop, and the speed of sound cancels out of the
result.

This implementation demonstrates 2-path and 4-path configurations driven by
simulated measurement data.

## Physics & Theory

### Transit-Time Differential Method

- **Downstream** (with flow): speed = c + v → transit time is **shorter**
- **Upstream** (against flow): speed = c − v → transit time is **longer**

```
Δt = t_upstream - t_downstream
```

### Path Velocity Formula

For a single acoustic path at angle θ to the pipe axis:

```
v_path = (L / (2 * sin(θ))) * (Δt / (t_up * t_down))
```

- **L** = acoustic path length (the chord `D / sin(θ)`)
- **θ** = angle between the acoustic path and the pipe flow axis
- **Δt** = t_upstream − t_downstream

### Volumetric Flow Rate

Gauss-Jacobi quadrature integrates the sampled velocities across the pipe:

```
Q = (π * D² / 4) * Σ(w_i * v_i)
```

### Path Configurations

| Config | Paths | Angle | Position | Weight |
|--------|-------|-------|----------|--------|
| 2-path | 1, 2 | 45° | ±0.25 D | 0.5 |
| 4-path | 1, 2 | 60° | ±0.35 D | 0.25 |
| 4-path | 3, 4 | 45° | ±0.15 D | 0.25 |

## Architecture

Vimscript has no structs and no module system. Records are plain dictionaries;
the namespace is a shared `Flowmeter_` prefix on global functions, which is what
a plugin without an autoload directory does:

```vim
Flowmeter_acoustic_path(pipe_diameter, position, angle, weight)
" → {'position': ..., 'angle': ..., 'length': ..., 'weight': ...}
"   length is the chord D / sin(angle)

Flowmeter_path_measurement(t_upstream, t_downstream)
" → {'t_upstream': ..., 't_downstream': ..., 'delta_t': ...}

Flowmeter_config(pipe_diameter, paths)
" → {'pipe_diameter': ..., 'paths': ..., 'num_paths': ...}
```

The algorithm and the builders:

```vim
Flowmeter_pipe_area(config)                       " π (D/2)²
Flowmeter_path_velocity(path, measurement)        " m/s
Flowmeter_flow_rate(config, measurements)         " {'path_velocities', 'volumetric_flow'}

Flowmeter_2path_config(pipe_diameter)
Flowmeter_4path_config(pipe_diameter)

Flowmeter_to_liters_per_second(m3_per_s)
Flowmeter_to_liters_per_minute(m3_per_s)
```

`Flowmeter_acoustic_path` derives the path length, so the `D / sin(θ)` formula
appears exactly once. `Flowmeter_flow_rate` uses `throw` — Vimscript's exception
mechanism, catchable with `try`/`catch` — if the configuration has no paths or
the measurement count does not match. `Flowmeter_path_velocity` returns `0.0`
for non-physical transit times or a degenerate (axial) path angle, matching the
C behavior.

The demonstration uses script-local (`s:`) functions and variables throughout,
so nothing but the core's `Flowmeter_` API leaks into the global namespace.

### Three things Vimscript makes you do differently

**No `pi`.** There is no constant, so `g:flowmeter_pi` is computed once at
source time as `4.0 * atan(1.0)`.

**`:echo` produces nothing in Ex silent mode.** `vim -es` suppresses messages
entirely, which is exactly what makes it usable as a script runner and exactly
what makes printing awkward. So `main.vim` accumulates its lines in a list and
flushes them once through `writefile(s:output, '/dev/stdout')`. That also makes
the output a single atomic write, with no editor chrome interleaved.

**Line continuations are off by default under `-es`.** Ex silent mode starts in
`'compatible'` `cpoptions`, where a leading `\` is not a continuation and every
multi-line expression becomes an `E116: Invalid arguments` at run time. Both
files therefore open with the standard plugin prologue and close with its
matching restore:

```vim
let s:save_cpo = &cpoptions
set cpoptions&vim
" ... the whole file ...
let &cpoptions = s:save_cpo
unlet s:save_cpo
```

Every Vim plugin in the wild carries this dance. Running the program headless is
what makes the reason for it visible.

## Running

**Prerequisites:** Vim 8.0 or newer, compiled with `+float` (`vim --version |
grep float`). Tested with Vim 9.1.

```bash
vim -es -S main.vim
```

`-e` selects Ex mode, `-s` makes it silent, and `-S` sources the script.
`main.vim` sources `flowmeter.vim` from its own directory, so the command works
from anywhere. The script quits Vim itself once it has run.

Neovim runs the same files unchanged:

```bash
nvim -es -S main.vim
```

## Interactive Usage

The core sources cleanly into a running Vim and can be driven from the command
line:

```vim
:source flowmeter.vim

:let config = Flowmeter_2path_config(0.1)
:echo Flowmeter_pipe_area(config)
" 0.007854

:echo config.paths[0].length
" 0.141421

:let m = Flowmeter_path_measurement(0.1 / (1480 - 2), 0.1 / (1480 + 2))
:echo printf('%.2e', m.delta_t)
" 1.83e-07

:let result = Flowmeter_flow_rate(config, [m, m])
:echo printf('%.6f', result.volumetric_flow)
" 0.031416
:echo result.path_velocities
" [4.0, 4.0]
```

`:echo` truncates floats to six significant digits by default; `printf()` is
how you see the rest. To inspect a dictionary in full, use `:echo string(config)`.

Sourcing `main.vim` interactively runs the demonstration and writes it to
stdout, which in a terminal Vim means it lands underneath the editor's screen —
the guard at the bottom of the file skips the `qall!` in that case, so at least
the editor survives. Reading the output is better done headless.

## File Descriptions

### `flowmeter.vim`

The algorithm: the dictionary constructors, the two solver functions, the config
builders, and the unit conversions. Guarded by `g:loaded_flowmeter`, so sourcing
it twice is harmless. Pure — nothing here echoes, writes a file, or opens a
buffer.

### `main.vim`

Simulation and presentation. Generates synthetic transit times for a known flow
velocity (sound speed 1480 m/s, water at 20 °C), formats every line with
`printf()`, and flushes them through `writefile()`. This is the only file that
produces output.

## Example Output

```
=== Ultrasonic Multipath Flow Meter ===

### 2-PATH CONFIGURATION ###

Flow Meter Configuration:
  Pipe diameter: 0.100 m
  Number of paths: 2
  Pipe area: 0.007854 m²

Acoustic Paths:
  Path 1:
    Position: 0.25 D
    Angle: 45.00° (0.7854 rad)
    Path length: 0.1414 m
    Weight: 0.500
  ...

Simulated Measurements (True flow velocity: 2.00 m/s):
  Path 1: t_upstream = 0.00006766 s, t_downstream = 0.00006748 s, Δt = 1.83e-07 s
  ...

Flow Calculation Results:
  Path 1 velocity: 4.0000 m/s
  Path 2 velocity: 4.0000 m/s

Volumetric Flow Rate:
  0.031416 m³/s
  1884.9556 L/min
  31.42 L/s
```

The 4-path configuration yields `0.026180 m³/s` (1570.7963 L/min). The output is
byte-identical to the C reference — Vim's `printf()` is a faithful wrapper over
C's, exponent padding included.

Path velocity reads as 4.0 m/s for a true flow of 2.0 m/s because the demo's
`L = D / sin θ` leaves a `1 / sin²θ` factor in the recovered velocity — an
artifact of the simplified geometry, not a meter calibration. At 60° the same
factor gives 2.6667 m/s.

## Vimscript Idioms Used

| Idiom | Where |
|-------|-------|
| Dictionaries as records | Every constructor returns a `{...}` |
| `s:` script-local scope | All of `main.vim`'s functions and variables |
| `a:` and `l:` prefixes | Function arguments and locals, spelled explicitly |
| `function! ... abort` | Every function; `abort` stops on the first error |
| `let g:loaded_flowmeter` | The standard double-source guard |
| `cpoptions` save/restore | Enabling line continuations, as every plugin must |
| `throw` / `try` | Vimscript's exception mechanism for the two invalid inputs |
| `printf()` | C-compatible formatting, including `%.2e` |
| `writefile(lines, '/dev/stdout')` | Output, because `:echo` is silent under `-es` |
| `expand('<sfile>:p:h')` | Locating a sibling file relative to the running script |
| `4.0 * atan(1.0)` | π, which Vimscript does not provide |

## Further Learning

### Concepts to Explore

- **Ex mode** — `:help -s-ex`, and why `-es` is the scripting entry point
- **`'cpoptions'`** — `:help cpo-C`, the flag that disables line continuation
- **Vimscript floats** — `:help Float`, including why `:echo` shows six digits
- **Script-local functions** — `:help script-variable` and the `<SNR>` prefix in error messages
- **Vim9script** — the newer, faster dialect, and what it would change here

### Suggested Modifications

1. Add a `:Flowmeter` user command that echoes the result into the message area
2. Port the core to Vim9script (`vim9script`, `def`, typed variables) and compare the speed
3. Move the core to `autoload/flowmeter.vim` and use `flowmeter#path_velocity()` naming
4. Write the results into a scratch buffer instead of stdout, with syntax highlighting
5. Add measurement noise and average over many samples
6. Add 6-path and 8-path configurations with proper Gauss-Jacobi weights
7. Add tests with [vader.vim](https://github.com/junegunn/vader.vim) or `assert_equal()` and `v:errors`

## License & Notes

MIT License — free to use and modify for educational purposes. See the
[top-level README](../README.md) for the cross-language comparison.
