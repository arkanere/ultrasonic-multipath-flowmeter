# Ultrasonic Multipath Flow Meter — TypeScript

A TypeScript implementation of a transit-time differential ultrasonic flow meter
for educational purposes. It computes the same physics as the [C
implementation](../c-language/), and is a deliberate companion to the
[JavaScript implementation](../javascript-language/): the same code, with the
runtime `Object.freeze` calls replaced by `readonly` types the compiler checks.

## Table of Contents

- [Overview](#overview)
- [Physics & Theory](#physics--theory)
- [Architecture](#architecture)
- [Running](#running)
- [Interactive Usage](#interactive-usage)
- [File Descriptions](#file-descriptions)
- [Example Output](#example-output)
- [TypeScript Idioms Used](#typescript-idioms-used)
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

Still no classes: data is built by factory functions that return plain objects.
What changes from JavaScript is where immutability is enforced. JavaScript
freezes each object at run time; TypeScript declares every field `readonly` and
rejects a mutation at compile time, so no freezing call is needed at all.

```ts
interface AcousticPath {
  readonly position: number;   // normalized to -1..1
  readonly angle: number;      // radians from the pipe axis
  readonly length: number;     // the chord D / sin(angle)
  readonly weight: number;     // Gauss-Jacobi coefficient
}

interface PathMeasurement {
  readonly tUpstream: number;
  readonly tDownstream: number;
  readonly deltaT: number;
}

interface FlowMeterConfig {
  readonly pipeDiameter: number;
  readonly paths: readonly AcousticPath[];
  readonly numPaths: number;
}

interface FlowResult {
  readonly pathVelocities: readonly number[];
  readonly volumetricFlow: number;
}
```

The algorithm and the builders:

```ts
pipeArea(config): number                            // π (D/2)²
calculatePathVelocity(path, measurement): number    // m/s
calculateFlowRate(config, measurements): FlowResult

create2PathConfig(pipeDiameter): FlowMeterConfig
create4PathConfig(pipeDiameter): FlowMeterConfig

cubicMetersToLitersPerSecond(m3PerS): number
cubicMetersToLitersPerMinute(m3PerS): number
```

`acousticPath` derives the path length from the pipe diameter and angle, so the
`D / sin(θ)` formula appears exactly once. `calculateFlowRate` throws if the
configuration has no paths or if the measurement count does not match the path
count. `calculatePathVelocity` returns `0` for non-physical transit times or a
degenerate (axial) path angle, matching the C behavior.

**Where the types changed the code.** `tsconfig.json` enables
`noUncheckedIndexedAccess`, which types `measurements[i]` as
`PathMeasurement | undefined` — indexing an array is not a proof that the index
is in range. JavaScript's `map` + `reduce` pair therefore does not typecheck
without a cast, so `calculateFlowRate` walks both sequences in a single loop
instead, narrowing the measurement once and accumulating the weighted sum
alongside the velocity it weights. Reading the two files side by side shows the
strict flag doing real work, not just decorating the JavaScript.

`readonly AcousticPath[]` (a read-only array of paths) is not the same as
`ReadonlyArray<AcousticPath>` used loosely: the interface field is the former,
so callers cannot `push` onto `config.paths`. The constructor still copies the
input array, so a caller holding a mutable array cannot reach inside afterwards.

## Running

**Prerequisites:** Node.js 18 or newer.

```bash
npm install
npm start          # tsx src/main.ts
```

Or without the script:

```bash
npx tsx src/main.ts
```

Typecheck without emitting anything:

```bash
npm run typecheck  # tsc --noEmit
```

`tsx` compiles and runs the TypeScript in one step; nothing is written to disk.
`tsconfig.json` sets `noEmit`, so `tsc` is a checker here, not a build step.

## Interactive Usage

`tsx` installs a loader that lets the Node REPL import `.ts` files directly:

```bash
npx tsx
```

```ts
> const core = await import('./src/core.ts');
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

The REPL does not typecheck — it strips the types and runs. To see the compiler
catch a mistake, add `config.pipeDiameter = 0.2;` to `src/main.ts` and run
`npm run typecheck`:

```
error TS2540: Cannot assign to 'pipeDiameter' because it is a read-only property.
```

That is the same guarantee the JavaScript version buys with `Object.freeze`,
moved from run time to compile time.

## File Descriptions

### `src/core.ts`

The algorithm: the four interfaces, the factory functions, the two solver
functions, the config builders, and the unit conversions. Pure and side-effect
free.

### `src/main.ts`

Simulation and presentation. Generates synthetic transit times for a known flow
velocity (sound speed 1480 m/s, water at 20 °C), prints the configuration and
results, and calls `runDemo` once per configuration. This is the only file that
touches `console`.

### `tsconfig.json`

`strict: true` plus `noUncheckedIndexedAccess`,
`exactOptionalPropertyTypes`, `noUnusedLocals`, and `noUnusedParameters`.
`verbatimModuleSyntax` is what forces the `import type { ... }` line in
`main.ts` — a type-only import must say so.

### `package.json`

Declares `"type": "module"`, the `start` and `typecheck` scripts, and `tsx`,
`typescript`, and `@types/node` as dev dependencies. Nothing ships at run time.

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
exponent format, inherited from JavaScript: `toExponential(2)` prints `1.83e-7`
where C's `%.2e` prints `1.83e-07`. Six lines differ, all of them Δt.

Path velocity reads as 4.0 m/s for a true flow of 2.0 m/s because the demo's
`L = D / sin θ` leaves a `1 / sin²θ` factor in the recovered velocity — an
artifact of the simplified geometry, not a meter calibration. At 60° the same
factor gives 2.6667 m/s.

## TypeScript Idioms Used

| Idiom | Where |
|-------|-------|
| `interface` with `readonly` | Every record field; immutability without `Object.freeze` |
| `readonly T[]` | `config.paths` and `result.pathVelocities` |
| `import type` | The type-only import in `main.ts`, required by `verbatimModuleSyntax` |
| Structural typing | Factory functions return object literals; no `implements`, no classes |
| Explicit return types | Every exported function, so a change of shape is a compile error |
| Narrowing over casting | `if (measurement === undefined)` instead of `as PathMeasurement` |
| `strict` + `noUncheckedIndexedAccess` | Turns array indexing into something you have to justify |
| `noEmit` | The compiler is a checker; `tsx` does the running |

## Further Learning

### Concepts to Explore

- **Compile-time vs. run-time immutability** — `readonly` versus `Object.freeze`, and why `readonly` disappears at run time
- **`noUncheckedIndexedAccess`** — the flag that changed `calculateFlowRate`'s shape
- **Structural typing** — why no interface is ever `implement`ed here
- **Type-only imports** — what `verbatimModuleSyntax` enforces and why bundlers care
- **`number` is IEEE-754** — the same double as C's, hence identical arithmetic

### Suggested Modifications

1. Add tests with `node:test` and `tsx --test`
2. Give velocities and flow rates branded types (`type MetersPerSecond = number & { __brand: 'm/s' }`) so a unit mix-up is a compile error
3. Make `numPaths` a template-literal-typed tuple length instead of a stored number
4. Add measurement noise and average over many samples
5. Add 6-path and 8-path configurations with proper Gauss-Jacobi weights
6. Match C's exponent format exactly with a small `formatScientific` helper, then diff against `c-language`
7. Compile with `tsc` and run the emitted JavaScript, comparing it to `javascript-language/src/`

## License & Notes

MIT License — free to use and modify for educational purposes. See the
[top-level README](../README.md) for the cross-language comparison.
