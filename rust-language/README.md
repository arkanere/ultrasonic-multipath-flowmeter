# Ultrasonic Multipath Flow Meter — Rust

A Rust implementation of a transit-time differential ultrasonic flow meter for
educational purposes. It computes the same physics as the [C
implementation](../c-language/), organized as a library crate (`src/lib.rs`)
with a thin binary (`src/main.rs`) that runs the demonstration.

## Table of Contents

- [Overview](#overview)
- [Physics & Theory](#physics--theory)
- [Architecture](#architecture)
- [Building & Running](#building--running)
- [File Descriptions](#file-descriptions)
- [Example Output](#example-output)
- [Rust Idioms Used](#rust-idioms-used)
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

Four plain data types, with the behavior attached to the type it belongs to:

```rust
pub struct AcousticPath {
    pub position: f64,  // Normalized position on the pipe diameter, -1.0..=1.0
    pub angle: f64,     // Angle from the pipe axis, in radians
    pub length: f64,    // Acoustic path length, in meters
    pub weight: f64,    // Gauss-Jacobi weighting coefficient
}

pub struct PathMeasurement {
    pub t_upstream: f64,
    pub t_downstream: f64,
}

pub struct FlowMeterConfig {
    pub pipe_diameter: f64,
    pub paths: Vec<AcousticPath>,
}

pub struct FlowResult {
    pub path_velocities: Vec<f64>,
    pub volumetric_flow: f64,
}
```

The API:

```rust
impl AcousticPath {
    pub fn new(pipe_diameter: f64, position: f64, angle: f64, weight: f64) -> Self;
    pub fn velocity(&self, measurement: &PathMeasurement) -> f64;
}

impl PathMeasurement {
    pub fn new(t_upstream: f64, t_downstream: f64) -> Self;
    pub fn delta_t(&self) -> f64;
}

impl FlowMeterConfig {
    pub fn two_path(pipe_diameter: f64) -> Self;
    pub fn four_path(pipe_diameter: f64) -> Self;
    pub fn pipe_area(&self) -> f64;
    pub fn calculate_flow_rate(&self, measurements: &[PathMeasurement]) -> FlowResult;
}

impl FlowResult {
    pub fn liters_per_second(&self) -> f64;
    pub fn liters_per_minute(&self) -> f64;
}
```

`AcousticPath::new` derives the path length from the pipe diameter and angle, so
the `D / sin(θ)` formula appears exactly once. `calculate_flow_rate` panics if
the configuration has no paths or if the measurement count does not match the
path count — a programming error rather than a runtime condition, which is why
it asserts rather than returning `Result`. `AcousticPath::velocity` returns
`0.0` for non-physical transit times or a degenerate (axial) angle, matching the
C behavior.

## Building & Running

**Prerequisites:** Rust 1.70+ (2021 edition). No external dependencies.

```bash
cargo run                # Build and run the demo
cargo build --release    # Optimized build
./target/release/flowmeter
cargo doc --open         # Browse the API documentation
cargo clippy             # Lint
```

## File Descriptions

### `Cargo.toml`

Package `ultrasonic-flowmeter`, edition 2021, no dependencies. Declares the
binary target `flowmeter` alongside the implicit library target.

### `src/lib.rs`

The library: all four types and the full algorithm. Documented with `///` doc
comments, so `cargo doc` produces browsable API docs.

### `src/main.rs`

The demo binary. Generates synthetic transit times for a known flow velocity
(sound speed 1480 m/s, water at 20°C), prints the configuration and results, and
calls `run_demo` once per configuration. It consumes the library through
`use ultrasonic_flowmeter::{...}` exactly as an external crate would.

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
  Path 1: t_upstream = 0.00006766 s, t_downstream = 0.00006748 s, Δt = 1.83e-7 s
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
every other implementation. The only textual difference from the C output is the
exponent format: Rust's `{:.2e}` prints `1.83e-7` where C's `%.2e` prints
`1.83e-07`.

Path velocity reads as 4.0 m/s for a true flow of 2.0 m/s because the demo's
`L = D / sin θ` leaves a `1 / sin²θ` factor in the recovered velocity — an
artifact of the simplified geometry, not a meter calibration. At 60° the same
factor gives 2.6667 m/s.

## Rust Idioms Used

| Idiom | Where |
|-------|-------|
| Inherent methods over free functions | `path.velocity(&m)`, `config.calculate_flow_rate(&m)` |
| Named constructors | `FlowMeterConfig::two_path`, `AcousticPath::new` |
| Iterator chains | `paths.iter().zip(measurements).map(...).collect()` for the velocities, `.sum()` for the weighted total |
| Slices as parameters | `&[PathMeasurement]` accepts a `Vec`, an array, or a sub-slice |
| Derived traits | `Debug`, `Clone`, `Copy`, `PartialEq` on the data types |
| Doc comments | `///` on every public item, checked by `cargo doc` |
| Inline format captures | `println!("{velocity:.4} m/s")` |

## Further Learning

### Concepts to Explore

- **Ownership** — `FlowResult` owns its `Vec`, so there is no free function to call
- **Borrowing** — the solver takes `&self` and `&[PathMeasurement]`, copying nothing
- **`assert!` vs `Result`** — when a wrong argument count is a bug, not an error
- **Zero-cost abstraction** — the iterator chain compiles to the same loop as the C version

### Suggested Modifications

1. Add `#[cfg(test)] mod tests` with `assert!((q - 0.031416).abs() < 1e-6)`
2. Return `Result<FlowResult, FlowError>` instead of asserting, and define the error type
3. Add measurement noise with the `rand` crate and average over many samples
4. Add 6-path and 8-path configurations with proper Gauss-Jacobi weights
5. Make the sound speed temperature-dependent
6. Benchmark against the C implementation with `criterion`

## License & Notes

MIT License — free to use and modify for educational purposes. See the
[top-level README](../README.md) for the cross-language comparison.
