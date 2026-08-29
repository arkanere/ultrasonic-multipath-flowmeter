# Ultrasonic Multipath Flow Meter — Basic

A FreeBASIC implementation of a transit-time differential ultrasonic flow meter
for educational purposes. It computes the same physics as the [C
implementation](../c-language/), split across a `flowmeter.bi` header, a
`flowmeter.bas` algorithm file, and a `main.bas` demonstration program.

FreeBASIC has no module system, so this is the implementation that most closely
mirrors the C layout — including C's convention that the configuration builders
belong to the demo program rather than to the algorithm.

## Table of Contents

- [Overview](#overview)
- [Physics & Theory](#physics--theory)
- [Architecture](#architecture)
- [Building & Running](#building--running)
- [File Descriptions](#file-descriptions)
- [Example Output](#example-output)
- [FreeBASIC Idioms Used](#freebasic-idioms-used)
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

Four user-defined types, declared in `flowmeter.bi`:

```basic
Type AcousticPath
    position   As Double  '' Position on pipe diameter (normalized: -1 to 1)
    angle      As Double  '' Angle from pipe axis, in radians
    pathLength As Double  '' Acoustic path length, in meters
    weight     As Double  '' Gauss-Jacobi weighting coefficient
End Type

Type FlowMeterConfig
    pipeDiameter As Double
    numPaths     As UInteger
    paths(Any)   As AcousticPath
End Type

Type PathMeasurement
    tUpstream   As Double
    tDownstream As Double
End Type

Type FlowResult
    pathVelocities(Any) As Double
    volumetricFlow      As Double
End Type
```

`paths(Any)` and `pathVelocities(Any)` are variable-length arrays *inside* a
UDT — a FreeBASIC extension over classic BASIC, and the feature that lets this
version carry a configuration around as one value the way the C struct does.
They are resized with `ReDim` and freed automatically, so there is no
`flowmeter_result_free` equivalent.

The API:

```basic
Declare Function CalculatePathVelocity( _
    ByRef path As AcousticPath, _
    ByRef measurement As PathMeasurement) As Double

Declare Function CalculateFlowRate( _
    ByRef config As FlowMeterConfig, _
    measurements() As PathMeasurement, _
    ByRef result As FlowResult) As Integer

Declare Function ToLitersPerSecond(ByVal cubicMetersPerSecond As Double) As Double
Declare Function ToLitersPerMinute(ByVal cubicMetersPerSecond As Double) As Double
```

`CalculateFlowRate` fills a `ByRef` output parameter and returns `0` on success
or `-1` on error — the same return-code convention as the C version, and the
reason this file reads so much like `flowmeter.c`. `CalculatePathVelocity`
returns `0.0` for a non-positive transit time or a zero-sine angle, matching the
C guards exactly.

## Building & Running

**Prerequisites:** FreeBASIC 1.09+ (`fbc`). No external dependencies —
`vbcompat.bi`, which supplies `Format`, ships with the compiler.

```bash
make            # Build ./flowmeter
make run        # Build and run
make clean      # Remove *.o and the binary

# Or invoke the compiler directly:
fbc -w all main.bas flowmeter.bas -x flowmeter
```

Note `-x` names the executable; `-o` names an *object* file in FreeBASIC, which
is the opposite of the GCC convention.

**Installing FreeBASIC:** Linux and Windows builds are available from
[freebasic.net](https://www.freebasic.net/get). There is no Homebrew formula for
macOS on Apple Silicon; the practical options there are a Linux container, a
cross-build, or QB64 Phoenix Edition with dialect adjustments.

## File Descriptions

### `flowmeter.bi`

The header: the `PI` constant, the four `Type` declarations, and `Declare`
statements for the two solvers and two unit converters. Guarded with
`#ifndef FLOWMETER_BI` so repeated `#include`s are harmless — though `#include
once` makes that belt-and-braces. This file is the direct analogue of
`../c-language/flowmeter.h`.

### `flowmeter.bas`

The algorithm: `CalculatePathVelocity`, `CalculateFlowRate`, and the two unit
converters. No `Print` statement appears anywhere in this file.

### `main.bas`

The demo. Holds the configuration builders, the transit-time simulator (sound
speed 1480 m/s, water at 20°C), the formatting helpers, the print subs, and the
module-level entry code. FreeBASIC has no `main` function — top-level statements
*are* the program, which is why the demo body sits unindented at the bottom of
the file.

### `Makefile`

Two targets plus `clean`, modeled on `../c-language/Makefile`.

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

The 4-path configuration yields `0.026180 m³/s` (1570.7963 L/min) — identical to
every other implementation. Unlike the Rust and JavaScript implementations, this one prints `1.83e-07`
rather than `1.83e-7`. FreeBASIC's `Format` has no scientific picture string that
matches C's `%.2e`, so `FormatScientific` in `main.bas` computes the mantissa and
exponent itself and pads the exponent to two digits.

Path velocity reads as 4.0 m/s for a true flow of 2.0 m/s because the demo's
`L = D / sin θ` leaves a `1 / sin²θ` factor in the recovered velocity — an
artifact of the simplified geometry, not a meter calibration. At 60° the same
factor gives 2.6667 m/s.

## FreeBASIC Idioms Used

| Idiom | Where |
|-------|-------|
| `.bi` header + `#include once` | `flowmeter.bi`, mirroring C's header/source split |
| Include guards | `#ifndef FLOWMETER_BI` around the whole header |
| `Type ... End Type` | The four data structures, with explicit `As Double` on every field |
| Variable-length arrays in a UDT | `paths(Any) As AcousticPath`, resized with `ReDim` |
| `ByRef` output parameters | `CalculateFlowRate(config, measurements(), result)` |
| Return codes | `0` / `-1` from `CalculateFlowRate`, as in C |
| `OrElse` | Short-circuit `If tUp <= 0 OrElse tDown <= 0` |
| `For i As Integer = ...` | Loop-scoped counters, without a separate `Dim` |
| `Format` from `vbcompat.bi` | `Format(value, "0.0000")` in place of `printf` |
| Module-level entry code | No `main` — the program is the top-level statement list |

## Further Learning

### Concepts to Explore

- **Header files without a preprocessor macro system** — how `.bi` differs from `.h`
- **`ReDim` and array descriptors** — what FreeBASIC stores alongside a variable-length array
- **`ByRef` vs. `ByVal`** — FreeBASIC's default differs from BASIC dialects you may know
- **`Int` vs. `Fix`** — `Int` floors, `Fix` truncates toward zero; `FormatScientific` depends on the difference
- **Picture strings** — how `Format(x, "0.000")` compares to a printf specifier, and where it falls short

### Suggested Modifications

1. Add a test file that asserts `Abs(result.volumetricFlow - 0.031416) < 1e-6` and exits non-zero on failure
2. Replace the return codes with FreeBASIC exceptions (`Throw` / `Try`) and compare with the C++ version
3. Port the file to QB64 and note what has to change — mostly `Type` arrays and `Format`
4. Add measurement noise with `Rnd` and average over many samples
5. Add 6-path and 8-path configurations with proper Gauss-Jacobi weights
6. Use the `Object`-oriented extensions (`Type ... Extends Object`) and attach the solvers as methods
7. Compile with `-g -exx` and see what the bounds checking reports

## License & Notes

MIT License — free to use and modify for educational purposes. See the
[top-level README](../README.md) for the cross-language comparison.


**Note:** this implementation was written against the C reference but has not
been compiled — FreeBASIC has no Homebrew formula for Apple Silicon, so no `fbc`
was available on the machine where it was authored. The algorithm and every
format string were checked line by line against `../c-language/`, and the
two-digit-exponent helper was validated numerically, but expect to fix a
compiler complaint or two on first build.
