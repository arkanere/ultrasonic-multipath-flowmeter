# Ultrasonic Multipath Flow Meter — Go

A Go implementation of a transit-time differential ultrasonic flow meter for
educational purposes. It computes the same physics as the [C
implementation](../c-language/), split into an importable package and a `cmd`
binary, with errors returned rather than signalled.

## Table of Contents

- [Overview](#overview)
- [Physics & Theory](#physics--theory)
- [Architecture](#architecture)
- [Running](#running)
- [Interactive Usage](#interactive-usage)
- [File Descriptions](#file-descriptions)
- [Example Output](#example-output)
- [Go Idioms Used](#go-idioms-used)
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

Two packages, following the standard Go layout: a library other programs can
import, and a `main` package under `cmd/` that is only an entry point. It is
the same library/binary split as the [Rust
implementation](../rust-language/)'s `lib.rs` and `main.rs`.

Records are plain structs passed by value. There is no constructor ceremony
beyond the four `New*` functions that derive a field from its inputs:

```go
flowmeter.NewAcousticPath(pipeDiameter, position, angle, weight) AcousticPath
// Length is derived as the chord D / sin(angle)

flowmeter.NewPathMeasurement(tUpstream, tDownstream) PathMeasurement
// DeltaT is derived once, at construction

flowmeter.NewConfig(pipeDiameter, paths) Config
// The paths slice is copied, so a later write by the caller cannot reach in
```

The algorithm and the builders:

```go
config.NumPaths() int
config.PipeArea() float64                          // π (D/2)²
flowmeter.CalculatePathVelocity(path, m) float64   // m/s
flowmeter.CalculateFlowRate(config, ms) (Result, error)

flowmeter.New2PathConfig(pipeDiameter) Config
flowmeter.New4PathConfig(pipeDiameter) Config

flowmeter.CubicMetersToLitersPerSecond(m3PerS) float64
flowmeter.CubicMetersToLitersPerMinute(m3PerS) float64
```

`NewAcousticPath` derives the path length from the pipe diameter and angle, so
the `D / sin(θ)` formula appears exactly once.

Errors are values. `CalculateFlowRate` returns one of two sentinel errors —
`ErrNoPaths` or `ErrMeasurementCount` — which callers can test with
`errors.Is`. `CalculatePathVelocity` returns `0` for non-physical transit times
or a degenerate (axial) path angle rather than an error, matching the C
behavior: a bad reading on one path is data, not a failure.

`PipeArea` and `NumPaths` are methods on `Config` because they are properties of
a configuration; the solver functions are package-level because they take two
arguments and belong to neither.

## Running

**Prerequisites:** Go 1.21 or newer. No dependencies.

```bash
go run ./cmd/flowmeter
```

Or build a binary:

```bash
go build -o flowmeter ./cmd/flowmeter
./flowmeter
```

Vetting and formatting, both of which should be silent:

```bash
go vet ./...
gofmt -l .
```

## Interactive Usage

Go has no REPL, so the equivalent of poking at the core is a short program or a
test. The package is pure and has no init-time side effects, so it drops into
either unchanged:

```go
package main

import (
	"fmt"

	"github.com/arkanere/ultrasonic-multipath-flowmeter/go-language/flowmeter"
)

func main() {
	config := flowmeter.New2PathConfig(0.1)
	fmt.Println(config.PipeArea())
	// 0.007853981633974483

	m := flowmeter.NewPathMeasurement(0.1/(1480-2), 0.1/(1480+2))
	fmt.Println(m.DeltaT)
	// 1.8261538096308498e-07

	result, err := flowmeter.CalculateFlowRate(config, []flowmeter.PathMeasurement{m, m})
	fmt.Println(result.VolumetricFlow, err)
	// 0.031415926535899315 <nil>
}
```

The exported API also reads well through the documentation tool:

```bash
go doc ./flowmeter
go doc ./flowmeter CalculatePathVelocity
```

## File Descriptions

### `flowmeter/flowmeter.go`

The algorithm: the four record types, the two solver functions, the config
builders, the sentinel errors, and the unit conversions. Pure — it imports only
`errors` and `math`.

### `cmd/flowmeter/main.go`

Simulation and presentation. Generates synthetic transit times for a known flow
velocity (sound speed 1480 m/s, water at 20 °C), prints the configuration and
results, and calls `runDemo` once per configuration. This is the only file that
touches `fmt` or `os`.

### `go.mod`

Module path and language version. No `require` directives — nothing outside the
standard library is used.

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
byte-identical to the C reference, exponent format included: Go's `%.2e` pads
the exponent to two digits exactly as C's does.

Path velocity reads as 4.0 m/s for a true flow of 2.0 m/s because the demo's
`L = D / sin θ` leaves a `1 / sin²θ` factor in the recovered velocity — an
artifact of the simplified geometry, not a meter calibration. At 60° the same
factor gives 2.6667 m/s.

## Go Idioms Used

| Idiom | Where |
|-------|-------|
| Package + `cmd` binary | `flowmeter/` is importable; `cmd/flowmeter/` is only an entry point |
| Value semantics | `AcousticPath`, `PathMeasurement`, and `Config` are copied, not shared |
| Errors as values | `(Result, error)` returns, with `errors.Is`-comparable sentinels |
| `errors.New` sentinels | `ErrNoPaths`, `ErrMeasurementCount` |
| Methods vs. functions | `config.PipeArea()` is a property; `CalculateFlowRate` is not |
| Defensive slice copy | `append([]AcousticPath(nil), paths...)` in `NewConfig` |
| `for i, x := range` | Numbering paths `1..n` when printing |
| Exported/unexported | Capitalized in the library, lowercase throughout `main` |
| `run() error` + `main()` | The entry point does nothing but map an error to an exit code |
| Doc comments | Every exported name begins its comment with its own identifier |

## Further Learning

### Concepts to Explore

- **Errors as values** — why `CalculateFlowRate` returns an error but `CalculatePathVelocity` returns `0`
- **Value vs. pointer receivers** — `Config` is small and immutable, so it is copied
- **Slice aliasing** — what `NewConfig`'s copy prevents
- **`float64` is IEEE-754** — the same double as C's, hence identical output
- **Package boundaries** — the core cannot print, because it does not import `fmt`

### Suggested Modifications

1. Add table-driven tests in `flowmeter/flowmeter_test.go` with `go test ./...`
2. Add a benchmark for `CalculateFlowRate` and run `go test -bench .`
3. Add measurement noise and average over many samples
4. Add 6-path and 8-path configurations with proper Gauss-Jacobi weights
5. Solve each path concurrently with a `sync.WaitGroup`, then measure whether it helped
6. Make the sound speed temperature-dependent
7. Wrap the core in an HTTP handler that returns the flow rate as JSON

## License & Notes

MIT License — free to use and modify for educational purposes. See the
[top-level README](../README.md) for the cross-language comparison.
