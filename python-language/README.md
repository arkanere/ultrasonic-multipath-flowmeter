# Ultrasonic Multipath Flow Meter — Python

A Python implementation of a transit-time differential ultrasonic flow meter for
educational purposes. It computes the same physics as the [C
implementation](../c-language/), using frozen dataclasses and type hints, with
no dependencies beyond the standard library.

## Table of Contents

- [Overview](#overview)
- [Physics & Theory](#physics--theory)
- [Architecture](#architecture)
- [Running](#running)
- [Interactive Usage](#interactive-usage)
- [File Descriptions](#file-descriptions)
- [Example Output](#example-output)
- [Python Idioms Used](#python-idioms-used)
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

Four frozen dataclasses, with derived quantities exposed as properties:

```python
@dataclass(frozen=True)
class AcousticPath:
    position: float  # Normalized position on the pipe diameter, -1.0..1.0
    angle: float     # Angle from the pipe axis, in radians
    length: float    # Acoustic path length, in meters
    weight: float    # Gauss-Jacobi weighting coefficient

    @classmethod
    def across(cls, pipe_diameter, position, angle, weight) -> AcousticPath: ...


@dataclass(frozen=True)
class PathMeasurement:
    t_upstream: float
    t_downstream: float

    @property
    def delta_t(self) -> float: ...


@dataclass(frozen=True)
class FlowMeterConfig:
    pipe_diameter: float
    paths: tuple[AcousticPath, ...]

    @property
    def num_paths(self) -> int: ...
    @property
    def pipe_area(self) -> float: ...   # pi (D/2)**2


@dataclass(frozen=True)
class FlowResult:
    path_velocities: tuple[float, ...]
    volumetric_flow: float
```

The algorithm is module-level functions over those types:

```python
calculate_path_velocity(path: AcousticPath,
                        measurement: PathMeasurement) -> float

calculate_flow_rate(config: FlowMeterConfig,
                    measurements: Sequence[PathMeasurement]) -> FlowResult

create_2path_config(pipe_diameter: float) -> FlowMeterConfig
create_4path_config(pipe_diameter: float) -> FlowMeterConfig

cubic_meters_to_liters_per_second(m3_per_s: float) -> float
cubic_meters_to_liters_per_minute(m3_per_s: float) -> float
```

`AcousticPath.across` derives the path length from the pipe diameter and angle,
so the `D / sin(θ)` formula appears exactly once. `calculate_flow_rate` raises
`ValueError` if the configuration has no paths or if the measurement count does
not match the path count. `calculate_path_velocity` returns `0.0` for
non-physical transit times or a degenerate (axial) path angle, matching the C
behavior.

`frozen=True` plus `tuple` fields means a configuration cannot be mutated after
construction — the same immutability the Clojure implementation gets from its
maps and vectors.

## Running

**Prerequisites:** Python 3.9 or newer. No third-party packages.

```bash
python3 -m ultrasonic_flowmeter
```

Run it from this directory so the package is importable. To run from anywhere:

```bash
PYTHONPATH=/path/to/python-language python3 -m ultrasonic_flowmeter
```

## Interactive Usage

The core module is import-friendly; nothing runs on import.

```python
>>> from ultrasonic_flowmeter.core import create_2path_config, calculate_flow_rate
>>> from ultrasonic_flowmeter.main import simulate_measurements

>>> config = create_2path_config(0.1)
>>> config.pipe_area
0.007853981633974483

>>> measurements = simulate_measurements(config, 2.0)
>>> measurements[0].delta_t
1.8261538096308498e-07

>>> result = calculate_flow_rate(config, measurements)
>>> result.volumetric_flow
0.031415926535899315
>>> result.path_velocities
(4.000000000000176, 4.000000000000176)
```

Build a configuration by hand to explore other geometries:

```python
>>> import math
>>> from ultrasonic_flowmeter.core import AcousticPath, FlowMeterConfig

>>> config = FlowMeterConfig(0.1, (
...     AcousticPath.across(0.1, 0.0, math.radians(30), 1.0),
... ))
>>> calculate_flow_rate(config, simulate_measurements(config, 2.0)).volumetric_flow
0.06283185307179863
```

## File Descriptions

### `ultrasonic_flowmeter/core.py`

The algorithm: the four dataclasses, the two solver functions, the config
builders, and the unit conversions. Pure and side-effect free.

### `ultrasonic_flowmeter/main.py`

Simulation and presentation. Generates synthetic transit times for a known flow
velocity (sound speed 1480 m/s, water at 20°C), prints the configuration and
results, and calls `run_demo` once per configuration.

### `ultrasonic_flowmeter/__init__.py`

Re-exports the public API so `from ultrasonic_flowmeter import
calculate_flow_rate` works.

### `ultrasonic_flowmeter/__main__.py`

Entry point for `python -m ultrasonic_flowmeter`.

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

## Python Idioms Used

| Idiom | Where |
|-------|-------|
| Frozen dataclasses | All four data types — immutable, with free `__repr__` and `__eq__` |
| `@property` | `delta_t`, `pipe_area`, `num_paths` — derived values, not stored fields |
| `@classmethod` constructor | `AcousticPath.across` builds a path from pipe geometry |
| Type hints | Every signature, with `from __future__ import annotations` |
| `zip` over parallel sequences | Pairing paths with their measurements |
| Generator expressions | Velocity computation and the weighted `sum()` |
| f-strings with format specs | `f"{value:.4f}"` mirrors C's `printf` formats |
| `Sequence` for parameters | Accepts lists, tuples, or any sequence |

## Further Learning

### Concepts to Explore

- **Immutability by construction** — why `tuple` fields matter in a frozen dataclass
- **Properties vs. stored fields** — keeping derived values from drifting out of sync
- **Duck typing at the boundary** — `Sequence[PathMeasurement]` instead of `list`
- **Floating point** — why `path_velocities` shows `4.000000000000176`

### Suggested Modifications

1. Add `pytest` tests asserting the 2-path and 4-path flow rates
2. Add measurement noise with `random.gauss` and average over many samples
3. Add 6-path and 8-path configurations with proper Gauss-Jacobi weights
4. Make the sound speed temperature-dependent
5. Weight paths by a parabolic (laminar) or flat (turbulent) velocity profile
6. Plot the recovered velocity profile with `matplotlib`
7. Vectorize the solver with NumPy and compare timings

## License & Notes

MIT License — free to use and modify for educational purposes. See the
[top-level README](../README.md) for the cross-language comparison.
