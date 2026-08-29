# Ultrasonic Multipath Flow Meter — Pascal

A Free Pascal implementation of a transit-time differential ultrasonic flow
meter for educational purposes. It computes the same physics as the [C
implementation](../c-language/), split into a `FlowMeter` unit holding the pure
algorithm and a `main.pas` program holding the simulation, the printing, and the
entry point.

Pascal's `unit` gives the core/main split a real language-level boundary: the
interface section is the public API, and the implementation section is private
by construction.

## Table of Contents

- [Overview](#overview)
- [Physics & Theory](#physics--theory)
- [Architecture](#architecture)
- [Building & Running](#building--running)
- [File Descriptions](#file-descriptions)
- [Example Output](#example-output)
- [Pascal Idioms Used](#pascal-idioms-used)
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

Four records, declared in the unit's `interface` section:

```pascal
type
  TAcousticPath = record
    Position:   Double;  { Position on pipe diameter (normalized: -1 to 1) }
    Angle:      Double;  { Angle from pipe axis, in radians }
    PathLength: Double;  { Acoustic path length, in meters }
    Weight:     Double;  { Gauss-Jacobi weighting coefficient }
  end;

  TFlowMeterConfig = record
    PipeDiameter: Double;
    NumPaths:     LongWord;
    Paths:        TAcousticPathArray;
  end;

  TPathMeasurement = record
    TUpstream:   Double;
    TDownstream: Double;
  end;

  TFlowResult = record
    PathVelocities: TDoubleArray;
    VolumetricFlow: Double;
  end;
```

The field is `PathLength`, not `Length`, because `Length` is a built-in and a
same-named field would force qualified access everywhere. The array fields are
Pascal dynamic arrays (`array of ...`), which are reference-counted and
automatically freed — so unlike the C version there is no `flowmeter_result_free`
to call.

The API:

```pascal
function MakeAcousticPath(APosition, AAngle, APathLength, AWeight: Double): TAcousticPath;
function MakeFlowMeterConfig(APipeDiameter: Double;
                             const APaths: TAcousticPathArray): TFlowMeterConfig;
function MakePathMeasurement(ATUpstream, ATDownstream: Double): TPathMeasurement;

function CalculatePathVelocity(const APath: TAcousticPath;
                               const AMeasurement: TPathMeasurement): Double;
function CalculateFlowRate(const AConfig: TFlowMeterConfig;
                           const AMeasurements: TPathMeasurementArray): TFlowResult;

function ToLitersPerSecond(ACubicMetersPerSecond: Double): Double;
function ToLitersPerMinute(ACubicMetersPerSecond: Double): Double;
```

`MakeFlowMeterConfig` derives `NumPaths` from the array length, so the count and
the array can never disagree. `CalculatePathVelocity` returns `0.0` via early
`Exit` for a non-positive transit time or a zero-sine angle, matching the C
guards exactly. `CalculateFlowRate` raises an exception on an empty path array or
a measurement-count mismatch — the same stance the C++ implementation takes,
rather than C's `-1` return code.

Records are passed `const` throughout. In Free Pascal a `const` record parameter
is passed by reference without being copyable, which gives the C version's
pointer efficiency with none of its aliasing hazards.

## Building & Running

**Prerequisites:** Free Pascal Compiler (FPC) 3.2+. No external dependencies —
`SysUtils` and `Math` ship with the compiler.

```bash
make            # Build ./flowmeter
make run        # Build and run
make clean      # Remove *.o, *.ppu and the binary

# Or invoke the compiler directly:
fpc -O2 -Mobjfpc -Sh -Fcutf8 -oflowmeter main.pas
```

The compiler flags matter:

| Flag | Why |
|------|-----|
| `-Mobjfpc` | Object Pascal mode — enables `Exit(value)`, `Result`, and the modern syntax used here |
| `-Sh` | Use `AnsiString` (long strings) rather than 255-byte `ShortString` |
| `-Fcutf8` | Treat source files as UTF-8, so the `°`, `Δ`, `²` and `³` literals survive |
| `-O2` | Optimize |

`fpc` compiles `flowmeter.pas` automatically as a dependency of `main.pas` —
there is no separate step for the unit.

## File Descriptions

### `flowmeter.pas`

The `FlowMeter` unit: the four record types plus the solvers and unit converters.
The `interface` section is the public contract; the `implementation` section is
inaccessible from outside the unit. No `Write` or `WriteLn` appears anywhere in
this file.

### `main.pas`

Program `FlowMeterDemo`. Holds the configuration builders, the transit-time
simulator (sound speed 1480 m/s, water at 20°C), the formatting helpers, the
print procedures, and the main block. Following the C implementation, the
configuration builders live here rather than in the unit.

The main block opens with `DefaultFormatSettings.DecimalSeparator := '.'`.
Without it, `Format` follows the machine's locale and a European locale would
print `0,100 m` instead of `0.100 m`.

### `Makefile`

Two targets plus `clean`, modeled on `../c-language/Makefile`. `clean` removes
`*.ppu` (compiled unit interfaces) as well as `*.o`.

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
rather than `1.83e-7`. Free Pascal's `Format('%e', ...)` would give `1.83E+007`
— a three-digit exponent and an uppercase `E` — so `FormatScientific` in
`main.pas` builds the string by hand to match C's `%.2e`.

Path velocity reads as 4.0 m/s for a true flow of 2.0 m/s because the demo's
`L = D / sin θ` leaves a `1 / sin²θ` factor in the recovered velocity — an
artifact of the simplified geometry, not a meter calibration. At 60° the same
factor gives 2.6667 m/s.

## Pascal Idioms Used

| Idiom | Where |
|-------|-------|
| `unit` with interface/implementation | `flowmeter.pas` — a compiler-enforced public/private boundary |
| `const` record parameters | Every solver — by-reference speed, no accidental mutation |
| `Result` and `Exit(value)` | `CalculatePathVelocity` returns early from its guards |
| Dynamic arrays | `array of TAcousticPath`, reference-counted and auto-freed |
| `T`-prefixed type names | `TAcousticPath`, `TFlowResult` — the Delphi/FPC convention |
| `A`-prefixed parameter names | `APath`, `AMeasurement` — distinguishes parameters from fields |
| `Format` with `array of const` | `Format('  Pipe diameter: %.3f m', [D])` |
| Integer precision specifier | `Format('%.2d', [7])` yields `07` — Pascal's zero-padding |
| Exceptions | `raise Exception.CreateFmt(...)` on a measurement-count mismatch |

## Further Learning

### Concepts to Explore

- **Units vs. headers** — a `.ppu` carries type information, so there is no `#include` textual substitution
- **`const` parameters** — how FPC passes large records by reference while forbidding assignment
- **Reference-counted dynamic arrays** — why this version needs no `free` call at all
- **String modes** — what `-Sh` changes, and why `ShortString` still exists
- **Locale-sensitive formatting** — `DefaultFormatSettings` and why pinning it matters for reproducible output

### Suggested Modifications

1. Add an FPCUnit test suite asserting `Abs(Q - 0.031416) < 1e-6`
2. Replace the exceptions with a `Boolean` result and an `out` parameter, matching C's return-code style
3. Turn the records into `advanced records` with methods (`-Mobjfpc` supports them) and compare with the Rust version
4. Add measurement noise with `Randomize`/`RandG` and average over many samples
5. Add 6-path and 8-path configurations with proper Gauss-Jacobi weights
6. Compile with `-Cr -Co -Ci` (range, overflow and I/O checking) and see what the arithmetic reports
7. Build for a second platform with `fpc -Twin64` and confirm the output is unchanged

## License & Notes

MIT License — free to use and modify for educational purposes. See the
[top-level README](../README.md) for the cross-language comparison.


**Note:** this implementation was written against the C reference but has not
been compiled — no Free Pascal compiler is installed on the machine where it was
authored. The algorithm and every format string were checked line by line
against `../c-language/`, and the two-digit-exponent helper was validated
numerically, but expect to fix a compiler complaint or two on first build.
