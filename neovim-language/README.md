# Ultrasonic Multipath Flow Meter — Lua (Neovim)

A Lua implementation of a transit-time differential ultrasonic flow meter for
educational purposes. It computes the same physics as the [C
implementation](../c-language/), written as a plain Lua module and run through
Neovim's built-in interpreter with `nvim --headless -l`.

## Table of Contents

- [Overview](#overview)
- [Physics & Theory](#physics--theory)
- [Architecture](#architecture)
- [Running](#running)
- [Interactive Usage](#interactive-usage)
- [File Descriptions](#file-descriptions)
- [Example Output](#example-output)
- [Lua Idioms Used](#lua-idioms-used)
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

Lua has one data structure — the table — and one module protocol: build a local
table `M`, hang functions off it, `return M` at the bottom. Records are plain
tables built by factory functions; their shape lives in LuaLS annotations rather
than in the language:

```lua
---@param pipe_diameter number Pipe diameter, in meters.
---@param position number Position on the pipe diameter, normalized to -1..1.
---@param angle number Angle from the pipe axis, in radians.
---@param weight number Gauss-Jacobi weighting coefficient.
---@return table path
function M.acoustic_path(pipe_diameter, position, angle, weight)
  return { position = ..., angle = ..., length = ..., weight = ... }
end
```

The algorithm and the builders:

```lua
flowmeter.pipe_area(config)                          -- π (D/2)²
flowmeter.calculate_path_velocity(path, measurement) -- m/s
flowmeter.calculate_flow_rate(config, measurements)  -- {path_velocities, volumetric_flow}

flowmeter.create_2path_config(pipe_diameter)
flowmeter.create_4path_config(pipe_diameter)

flowmeter.cubic_meters_to_liters_per_second(m3_per_s)
flowmeter.cubic_meters_to_liters_per_minute(m3_per_s)
```

`acoustic_path` derives the path length, so the `D / sin(θ)` formula appears
exactly once. `calculate_flow_rate` raises via `error(msg, 2)` — the level `2`
blames the caller's line, not the library's — if the configuration has no paths
or if the measurement count does not match. `calculate_path_velocity` returns
`0` for non-physical transit times or a degenerate (axial) path angle, matching
the C behavior.

`flowmeter.lua` never touches a `vim.*` API. That is deliberate: the module runs
unchanged under `nvim -l`, under `:lua` in a running editor, and under a
standalone `lua` or `luajit` binary. Only the harness is Neovim-specific.

### Two things the Neovim runtime makes you decide

**`package.path` does not include the script's directory.** `nvim -l main.lua`
runs the file but does not put its parent on the module search path the way a
standalone `lua main.lua` does. `main.lua` therefore recovers its own location
from `debug.getinfo(1, 'S').source` and prepends it before `require`.

**`print` is Neovim's, not Lua's.** Inside `nvim`, `print` routes through the
message system, which is not a plain stdout write. `io.write` is, so every line
goes through the one-line `say` helper built on it.

`string.format` is a direct binding to C's `printf`, so `%.4f`, `%.6f`, and
`%.2e` all render exactly as the C reference does, exponent padding included.

## Running

**Prerequisites:** Neovim 0.9 or newer (for `nvim -l`). Tested with Neovim
0.12.5, which embeds LuaJIT 2.1.

```bash
nvim --headless -l main.lua
```

`-l` runs a Lua script and exits; `--headless` suppresses the UI. Because
`flowmeter.lua` is pure Lua, the same program runs without Neovim at all if you
have an interpreter:

```bash
lua main.lua      # or luajit main.lua
```

## Interactive Usage

Inside a running Neovim:

```vim
:lua package.path = './?.lua;' .. package.path
:lua flowmeter = require('flowmeter')

:lua config = flowmeter.create_2path_config(0.1)
:lua print(flowmeter.pipe_area(config))
" 0.0078539816339745

:lua print(config.paths[1].length)
" 0.14142135623731

:lua m = flowmeter.path_measurement(0.1 / (1480 - 2), 0.1 / (1480 + 2))
:lua print(m.delta_t)
" 1.8261538096308e-07

:lua result = flowmeter.calculate_flow_rate(config, { m, m })
:lua print(result.volumetric_flow)
" 0.031415926535899
:lua print(result.path_velocities[1], result.path_velocities[2])
" 4.0000000000002   4.0000000000002
```

Note that `print` shows 14 significant digits — that is `tostring`'s default
format, not the stored precision. The values are full doubles;
`string.format('%.17g', x)` shows all of them.

`:lua= flowmeter.pipe_area(config)` is the shorthand for printing an expression,
and `vim.print(config)` pretty-prints a whole table, which is the nicest way to
look at a configuration.

Reloading after an edit needs the module cache cleared:

```vim
:lua package.loaded.flowmeter = nil
:lua flowmeter = require('flowmeter')
```

## File Descriptions

### `flowmeter.lua`

The algorithm: the factory functions, the two solver functions, the config
builders, and the unit conversions, annotated for the Lua language server. Ends
in `return M`. Pure — no `vim.*`, no `io`, no globals.

### `main.lua`

Simulation and presentation. Fixes up `package.path`, holds `SOUND_SPEED`, the
`say` helper, the printers, `run_demo`, and `main`. This is the only file that
writes to stdout.

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
byte-identical to the C reference — `string.format` is C's `printf`.

Path velocity reads as 4.0 m/s for a true flow of 2.0 m/s because the demo's
`L = D / sin θ` leaves a `1 / sin²θ` factor in the recovered velocity — an
artifact of the simplified geometry, not a meter calibration. At 60° the same
factor gives 2.6667 m/s.

## Lua Idioms Used

| Idiom | Where |
|-------|-------|
| `local M = {} ... return M` | The whole module protocol |
| Tables as records | Every constructor returns a `{ key = value }` |
| `local function` | Everything in `main.lua`; no globals are created |
| `ipairs` with index | Numbering paths `1..n`, and pairing paths with measurements |
| 1-based indexing | `config.paths[1]` is the first path |
| `#t` length operator | `num_paths`, and the measurement-count check |
| `error(msg, 2)` | Raising with the blame on the caller's line |
| `string.format` | C-compatible formatting, including `%.2e` |
| `io.write` over `print` | Plain stdout, bypassing Neovim's message system |
| `select('#', ...)` | Distinguishing "format with args" from "literal string" in `say` |
| `debug.getinfo(1, 'S')` | Locating the running script to fix up `package.path` |
| LuaLS `---@param` annotations | Types as documentation, checkable by the language server |

## Further Learning

### Concepts to Explore

- **`nvim -l`** — `:help -l`, Neovim's script-runner entry point
- **`package.path` and `require`** — why the module cache makes reloading a two-step dance
- **Metatables** — what `setmetatable(path, {__index = ...})` would buy over plain tables
- **LuaJIT numbers** — doubles throughout, hence output identical to C's
- **`vim.print` vs. `print`** — the message system versus stdout

### Suggested Modifications

1. Add a `:Flowmeter` user command with `vim.api.nvim_create_user_command`
2. Render the report into a floating window with `vim.api.nvim_open_win`
3. Add tests with [busted](https://lunarmodules.github.io/busted/) or `vim.health`-style checks
4. Give the records metatables with `__tostring`, so `print(path)` describes itself
5. Add measurement noise and average over many samples
6. Add 6-path and 8-path configurations with proper Gauss-Jacobi weights
7. Package it as a proper Neovim plugin under `lua/flowmeter/` with a `setup()` function

## License & Notes

MIT License — free to use and modify for educational purposes. See the
[top-level README](../README.md) for the cross-language comparison.
