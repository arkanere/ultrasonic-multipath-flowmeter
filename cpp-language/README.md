# Ultrasonic Multipath Flow Meter — C++

A C++17 implementation of a transit-time differential ultrasonic flow meter for
educational purposes. It computes the same physics as the [C
implementation](../c-language/), but replaces manual memory management with
value semantics: `std::vector`, return-by-value, and exceptions instead of
`malloc`/`free` and sentinel return codes.

## Table of Contents

- [Overview](#overview)
- [Physics & Theory](#physics--theory)
- [Architecture](#architecture)
- [Building & Running](#building--running)
- [File Descriptions](#file-descriptions)
- [Example Output](#example-output)
- [Differences from the C Implementation](#differences-from-the-c-implementation)
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

Everything lives in `namespace flowmeter`. The types are aggregates — plain
data with a couple of derived-value accessors — so they stay easy to construct
with brace initialization:

```cpp
struct AcousticPath {
    double position;  // Normalized position on the pipe diameter (-1 to 1)
    double angle;     // Angle from the pipe axis, in radians
    double length;    // Acoustic path length, in meters
    double weight;    // Gauss-Jacobi weighting coefficient
};

struct FlowMeterConfig {
    double pipe_diameter;
    std::vector<AcousticPath> paths;

    std::size_t num_paths() const;
    double pipe_area() const;   // π (D/2)²
};

struct PathMeasurement {
    double t_upstream;
    double t_downstream;

    double delta_t() const;     // t_upstream - t_downstream
};

struct FlowResult {
    std::vector<double> path_velocities;
    double volumetric_flow;
};
```

The API is free functions over those types:

```cpp
double     calculate_path_velocity(const AcousticPath &, const PathMeasurement &);
FlowResult calculate_flow_rate(const FlowMeterConfig &,
                               const std::vector<PathMeasurement> &);

FlowMeterConfig create_2path_config(double pipe_diameter);
FlowMeterConfig create_4path_config(double pipe_diameter);

double cubic_meters_to_liters_per_second(double m3_per_s);
double cubic_meters_to_liters_per_minute(double m3_per_s);
```

`calculate_flow_rate` throws `std::invalid_argument` if the configuration has no
paths or if the measurement count does not match the path count.
`calculate_path_velocity` returns `0.0` for non-physical transit times or a
degenerate (axial) path angle, matching the C behavior.

## Building & Running

**Prerequisites:** a C++17 compiler (`g++` or `clang++`) and Make.

```bash
make          # Build ./flowmeter
make run      # Build and run
make clean    # Remove objects and the executable
```

Or compile by hand:

```bash
g++ -Wall -Wextra -std=c++17 -O2 -c flowmeter.cpp
g++ -Wall -Wextra -std=c++17 -O2 -c main.cpp
g++ -Wall -Wextra -std=c++17 -O2 -o flowmeter flowmeter.o main.o
./flowmeter
```

No `-lm` is needed; `<cmath>` comes with the C++ standard library.

## File Descriptions

### `flowmeter.hpp`

Public interface: the four data types and the algorithm, builder, and unit
conversion functions, all inside `namespace flowmeter`.

### `flowmeter.cpp`

Core algorithm. Holds the private `make_path` helper that derives each path
length from the pipe diameter and angle, so the two config builders never repeat
the `D / sin(θ)` formula.

### `main.cpp`

Simulation and presentation, kept out of the library. Generates synthetic
transit times for a known flow velocity (sound speed 1480 m/s, water at 20°C),
prints the configuration and results, and runs `run_demo` once per
configuration. Everything here is in an anonymous namespace — none of it is part
of the public API.

### `Makefile`

`g++ -Wall -Wextra -std=c++17 -O2`, with `all`, `run`, and `clean` targets.

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

The 4-path configuration yields `0.026180 m³/s` (1570.7963 L/min). Output is
byte-for-byte identical to the C implementation.

Path velocity reads as 4.0 m/s for a true flow of 2.0 m/s because the demo's
`L = D / sin θ` leaves a `1 / sin²θ` factor in the recovered velocity — an
artifact of the simplified geometry, not a meter calibration. At 60° the same
factor gives 2.6667 m/s.

## Differences from the C Implementation

| Concern | C | C++ |
|---------|---|-----|
| Path storage | `AcousticPath *paths` + `uint32_t num_paths` | `std::vector<AcousticPath>` |
| Result lifetime | `malloc` + `flowmeter_result_free` | Returned by value, freed automatically |
| Error signalling | `-1` / `NULL` return codes | `std::invalid_argument` |
| Namespacing | `flowmeter_` prefixes | `namespace flowmeter` |
| Derived values | Recomputed at each call site | `pipe_area()`, `delta_t()` accessors |
| Link flags | `-lm` required | none |

The numeric core is deliberately unchanged: same formulas, same guards, same
constants.

## Further Learning

### Concepts to Explore

- **Value semantics** — why returning a `FlowResult` by value costs nothing here
- **Aggregate initialization** — building nested `vector`s of structs in one expression
- **`const` correctness** — every read-only accessor and parameter is marked `const`
- **Anonymous namespaces** — internal linkage for demo-only helpers

### Suggested Modifications

1. Add measurement noise and see how averaging across paths suppresses it
2. Add 6-path and 8-path configurations with proper Gauss-Jacobi weights
3. Make the sound speed temperature-dependent
4. Weight paths by a parabolic (laminar) or flat (turbulent) velocity profile
5. Template the code on the scalar type to compare `float` and `double` precision

## License & Notes

MIT License — free to use and modify for educational purposes. See the
[top-level README](../README.md) for the cross-language comparison.
