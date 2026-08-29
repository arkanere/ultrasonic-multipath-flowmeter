# Ultrasonic Multipath Flow Meter — JavaScript

A JavaScript implementation of a transit-time differential ultrasonic flow meter
for educational purposes. It computes the same physics as the [C
implementation](../c-language/), written as ES modules with frozen plain objects
and no dependencies.

## Table of Contents

- [Overview](#overview)
- [Physics & Theory](#physics--theory)
- [Architecture](#architecture)
- [Running](#running)
- [Interactive Usage](#interactive-usage)
- [File Descriptions](#file-descriptions)
- [Example Output](#example-output)
- [JavaScript Idioms Used](#javascript-idioms-used)
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

No classes: data is built by factory functions that return `Object.freeze`d
plain objects, so a configuration cannot be mutated after construction.

```js
acousticPath(pipeDiameter, position, angle, weight)
// → { position, angle, length, weight }
//   length is the chord D / sin(angle)

pathMeasurement(tUpstream, tDownstream)
// → { tUpstream, tDownstream, deltaT }

flowMeterConfig(pipeDiameter, paths)
// → { pipeDiameter, paths, numPaths }

calculateFlowRate(config, measurements)
// → { pathVelocities, volumetricFlow }
```

The algorithm and the builders:

```js
pipeArea(config)                          // π (D/2)²
calculatePathVelocity(path, measurement)  // m/s
calculateFlowRate(config, measurements)   // FlowResult

create2PathConfig(pipeDiameter)
create4PathConfig(pipeDiameter)

cubicMetersToLitersPerSecond(m3PerS)
cubicMetersToLitersPerMinute(m3PerS)
```

`acousticPath` derives the path length from the pipe diameter and angle, so the
`D / sin(θ)` formula appears exactly once. `calculateFlowRate` throws if the
configuration has no paths or if the measurement count does not match the path
count. `calculatePathVelocity` returns `0` for non-physical transit times or a
degenerate (axial) path angle, matching the C behavior.

`deltaT` is computed once at construction rather than on every read — the object
is frozen, so it can never fall out of sync with the times it was derived from.

## Running

**Prerequisites:** Node.js 18 or newer. No dependencies to install.

```bash
node src/main.js
# or
npm start
```

The package sets `"type": "module"`, so the sources are ES modules and use
`import`/`export` rather than `require`.

## Interactive Usage

The core module has no side effects on import, so it works directly in the Node
REPL:

```bash
node --experimental-repl-await
```

```js
> const core = await import('./src/core.js');
> const config = core.create2PathConfig(0.1);
> core.pipeArea(config)
0.007853981633974483

> const m = [0, 1].map(() => core.pathMeasurement(0.1 / (1480 - 2), 0.1 / (1480 + 2)));
> m[0].deltaT
1.8261538096308498e-7

> const result = core.calculateFlowRate(config, m);
> result.volumetricFlow
0.031415926535899315
> result.pathVelocities
[ 4.000000000000176, 4.000000000000176 ]
```

Because the modules are plain ESM with no Node-specific APIs in `core.js`, the
core also runs unchanged in a browser or a bundler.

## File Descriptions

### `src/core.js`

The algorithm: factory functions, the two solver functions, the config builders,
and the unit conversions. Pure and side-effect free.

### `src/main.js`

Simulation and presentation. Generates synthetic transit times for a known flow
velocity (sound speed 1480 m/s, water at 20°C), prints the configuration and
results, and calls `runDemo` once per configuration. This is the only file that
touches `console`.

### `package.json`

Declares `"type": "module"`, the `npm start` script, and a Node 18+ engine
requirement. No dependencies.

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
exponent format: `toExponential(2)` prints `1.83e-7` where C's `%.2e` prints
`1.83e-07`.

Path velocity reads as 4.0 m/s for a true flow of 2.0 m/s because the demo's
`L = D / sin θ` leaves a `1 / sin²θ` factor in the recovered velocity — an
artifact of the simplified geometry, not a meter calibration. At 60° the same
factor gives 2.6667 m/s.

## JavaScript Idioms Used

| Idiom | Where |
|-------|-------|
| ES modules | Named `export`/`import` throughout; no `require` |
| `Object.freeze` | Every constructed object, giving immutability without classes |
| Factory functions | `acousticPath`, `pathMeasurement`, `flowMeterConfig` instead of `new` |
| `map` / `reduce` | Per-path velocities and the weighted sum |
| Arrow functions | The one-line unit conversions |
| `forEach` with index | Numbering paths `1..n` when printing |
| Template literals | String building, mirroring C's `printf` formats |
| `toFixed` / `toExponential` | Fixed-precision output matching the other implementations |

## Further Learning

### Concepts to Explore

- **Immutability without classes** — `Object.freeze` as the whole story
- **Shallow freezing** — why `paths` is frozen separately from the config object
- **Number precision** — JavaScript numbers are IEEE-754 doubles, same as C's `double`
- **Pure modules** — why `core.js` never touches `console` or `process`

### Suggested Modifications

1. Add tests with the built-in `node:test` runner and `node --test`
2. Add measurement noise and average over many samples
3. Add 6-path and 8-path configurations with proper Gauss-Jacobi weights
4. Make the sound speed temperature-dependent
5. Weight paths by a parabolic (laminar) or flat (turbulent) velocity profile
6. Build a browser page that plots the recovered velocity profile with the same `core.js`
7. Add JSDoc-driven type checking with `tsc --checkJs`

## License & Notes

MIT License — free to use and modify for educational purposes. See the
[top-level README](../README.md) for the cross-language comparison.
