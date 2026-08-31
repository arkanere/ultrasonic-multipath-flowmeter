# Ultrasonic Multipath Flow Meter — Bash

A Bash implementation of a transit-time differential ultrasonic flow meter for
educational purposes. It computes the same physics as the [C
implementation](../c-language/) — in a language with no floating-point
arithmetic, no structures, and no way to return a value from a function.

## Table of Contents

- [Overview](#overview)
- [Physics & Theory](#physics--theory)
- [Architecture](#architecture)
- [Running](#running)
- [Interactive Usage](#interactive-usage)
- [File Descriptions](#file-descriptions)
- [Example Output](#example-output)
- [Bash Idioms Used](#bash-idioms-used)
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

This is the implementation where the language fights back, and the interesting
part is what it forces.

### awk is the FPU

Bash's `$(( ))` is integer-only. There is no float type, no `sin`, no π. So the
shell does what a shell is good at — naming things, looping, gluing — and hands
every arithmetic expression to `awk`, which computes in the same IEEE-754
doubles as C:

```bash
fm_calc() {
  awk "BEGIN { printf \"%.17g\", $1 }"
}

FM_PI=$(fm_calc 'atan2(0, -1)')
```

`%.17g` is the shortest format that round-trips a double, so values crossing
back into the shell as strings lose nothing. Every number in this program is a
decimal string that has been through `awk` at least once.

Even the comparisons go through it, because `[ "$a" -lt "$b" ]` is integer-only
and `[[ $a < $b ]]` compares strings:

```bash
if [ "$(fm_calc "($t_up <= 0 || $t_down <= 0 || $sin_theta == 0) ? 1 : 0")" = "1" ]; then
```

**Formatting, though, does not need awk.** Bash's own `printf` is a thin wrapper
over C's and parses decimal strings with `strtod`, so `%.4f`, `%.6f`, and `%.2e`
all work directly on what `fm_calc` returned — and produce byte-identical output
to the C reference, exponent padding included.

### Globals are the return values

A Bash function can return an exit status and write to stdout, and that is all.
There are no structures and no nested arrays. So a "record" is a set of parallel
indexed arrays sharing a prefix, and functions communicate by assigning to
well-known globals:

```bash
FM_PATH_POSITION=()   # path i's fields are element i of each array
FM_PATH_ANGLE=()
FM_PATH_LENGTH=()
FM_PATH_WEIGHT=()

FM_PIPE_DIAMETER=0.0
FM_NUM_PATHS=0
```

Two conventions keep this honest. Small pure functions — `fm_calc`,
`fm_pipe_area`, `fm_path_velocity`, the unit conversions — echo their answer, so
they compose under `$(...)`. Functions that build or solve a whole configuration
— `fm_create_2path_config`, `fm_calculate_flow_rate` — mutate the globals and
return an exit status, because a command substitution runs in a subshell and any
array they assigned there would vanish on return.

**Indexed arrays, not associative ones.** macOS ships bash 3.2 (the last GPLv2
release), which predates `declare -A`. Everything here runs under it.

### The public interface

```bash
fm_create_2path_config PIPE_DIAMETER   # → FM_PATH_* , FM_NUM_PATHS
fm_create_4path_config PIPE_DIAMETER

fm_add_measurement T_UP T_DOWN         # → FM_T_UPSTREAM, FM_T_DOWNSTREAM, FM_DELTA_T
fm_calculate_flow_rate                 # → FM_PATH_VELOCITIES, FM_VOLUMETRIC_FLOW

fm_pipe_area                           # echoes π (D/2)²
fm_path_velocity INDEX                 # echoes m/s
fm_to_liters_per_second VALUE
fm_to_liters_per_minute VALUE
```

`fm_add_path` derives the path length, so the `D / sin(θ)` formula appears
exactly once. `fm_calculate_flow_rate` returns 1 with a message on stderr if the
configuration has no paths or if the measurement count does not match.
`fm_path_velocity` echoes `0.0` for non-physical transit times or a degenerate
(axial) path angle, matching the C behavior.

`flowmeter.sh` exports `LC_ALL=C` at the top: a comma decimal separator from the
user's locale would break both `awk`'s parsing and `printf`'s output.

## Running

**Prerequisites:** Bash 3.2 or newer and any POSIX `awk`. Both ship with macOS
and every Linux distribution; nothing needs installing.

```bash
bash main.sh
```

`main.sh` sources `flowmeter.sh` from its own directory, so the command works
from anywhere. The script uses `set -u`, so an unset variable is a failure
rather than an empty string.

Syntax check without running:

```bash
bash -n main.sh flowmeter.sh
```

## Interactive Usage

`flowmeter.sh` is meant to be sourced, so an interactive shell is the REPL:

```bash
$ source flowmeter.sh

$ echo "$FM_PI"
3.1415926535897931

$ fm_create_2path_config 0.1
$ echo "$FM_NUM_PATHS"
2
$ fm_pipe_area
0.0078539816339744835
$ echo "${FM_PATH_LENGTH[0]}"
0.14142135623730953

$ fm_reset_measurements
$ up=$(fm_calc "0.1 / (1480 - 2)")
$ down=$(fm_calc "0.1 / (1480 + 2)")
$ fm_add_measurement "$up" "$down"
$ fm_add_measurement "$up" "$down"
$ echo "${FM_DELTA_T[0]}"
1.8261538096308498e-07

$ fm_calculate_flow_rate
$ echo "$FM_VOLUMETRIC_FLOW"
0.031415926535899315
$ echo "${FM_PATH_VELOCITIES[0]}"
4.0000000000001759

$ printf '%.6f m³/s\n' "$FM_VOLUMETRIC_FLOW"
0.031416 m³/s
```

The `%.17g` strings are not display formats — they are the storage. `printf` on
the last line is what turns one into a reading.

To watch the arithmetic, run with `bash -x main.sh`: every `awk` invocation
appears in the trace, which makes the shell-as-glue structure hard to miss.

## File Descriptions

### `flowmeter.sh`

The algorithm: `fm_calc`, the parallel-array records, the config builders, the
two solver functions, and the unit conversions. Meant to be sourced. Pure in the
sense that matters here — it never prints anything a caller did not ask for.

### `main.sh`

Simulation and presentation. Holds `FM_SOUND_SPEED`, the printers, `fm_run_demo`,
and `fm_main`. This is the only file that writes to stdout, and it does so with
bash's own `printf` rather than through `awk`.

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
byte-identical to the C reference — which is the point of routing the arithmetic
through `awk` rather than `bc`: `awk` computes in doubles and formats with C's
`printf`, so nothing is lost in either direction.

Path velocity reads as 4.0 m/s for a true flow of 2.0 m/s because the demo's
`L = D / sin θ` leaves a `1 / sin²θ` factor in the recovered velocity — an
artifact of the simplified geometry, not a meter calibration. At 60° the same
factor gives 2.6667 m/s.

## Bash Idioms Used

| Idiom | Where |
|-------|-------|
| `awk 'BEGIN { ... }'` as a calculator | `fm_calc`, wrapping every arithmetic expression |
| `%.17g` round-tripping | Passing doubles between processes as decimal strings |
| Parallel indexed arrays | Records, because bash 3.2 has no `declare -A` and no nesting |
| Globals as return values | Anything a subshell would swallow |
| Command substitution `$(...)` | The small pure functions that echo their answer |
| `local` declarations | Every function variable, so nothing leaks |
| `${#array[@]}` | Array length, for both appending and the count check |
| `for ((i = 0; ...))` | C-style arithmetic loops over path indices |
| `printf` over `echo` | Formatted output, and safety with leading-dash values |
| `set -u` | An unset variable aborts instead of expanding to nothing |
| `export LC_ALL=C` | Pinning the decimal separator for `awk` and `printf` alike |
| `${BASH_SOURCE[0]}` | Locating the running script to source its sibling |
| Return status + stderr | Error reporting, since there are no exceptions |

## Further Learning

### Concepts to Explore

- **Why not `bc`?** — `bc -l` has `s()` for sine and arbitrary precision, but it is decimal, not IEEE-754, and has no `%e`; the last digits would drift from C
- **Subshells** — why `fm_calculate_flow_rate` cannot echo its result
- **Word splitting** — what every `"$var"` quote in this file is preventing
- **bash 3.2 vs. 5.x** — `declare -A`, `${var^^}`, `mapfile`: none of them usable here
- **Process cost** — this program forks `awk` a few hundred times; C does it zero times

### Suggested Modifications

1. Run `shellcheck` over both files and address anything it finds
2. Batch the whole per-path calculation into a single `awk` script and measure the speedup with `time`
3. Rewrite it in pure `awk` and see how much of the shell disappears
4. Add measurement noise and average over many samples
5. Add 6-path and 8-path configurations with proper Gauss-Jacobi weights
6. Add `--diameter` and `--velocity` command-line options with `getopts`
7. Add a test script that diffs the output against `../c-language/flowmeter`

## License & Notes

MIT License — free to use and modify for educational purposes. See the
[top-level README](../README.md) for the cross-language comparison.
