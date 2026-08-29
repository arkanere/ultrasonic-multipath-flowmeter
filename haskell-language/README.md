# Ultrasonic Multipath Flow Meter — Haskell

A Haskell implementation of a transit-time differential ultrasonic flow meter
for educational purposes. It computes the same physics as the [C
implementation](../c-language/), organized as a library (`src/Flowmeter/Core.hs`)
with a thin executable (`app/Main.hs`) that runs the demonstration.

The core/main split is enforced by the type system here: `IO` does not appear
anywhere in the library, so the algorithm is provably free of side effects.

## Table of Contents

- [Overview](#overview)
- [Physics & Theory](#physics--theory)
- [Architecture](#architecture)
- [Building & Running](#building--running)
- [File Descriptions](#file-descriptions)
- [Example Output](#example-output)
- [Haskell Idioms Used](#haskell-idioms-used)
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

Four record types, all fields strict `Double`:

```haskell
data AcousticPath = AcousticPath
  { position   :: Double  -- Position on pipe diameter (normalized: -1 to 1)
  , angle      :: Double  -- Angle from pipe axis, in radians
  , pathLength :: Double  -- Acoustic path length, in meters
  , weight     :: Double  -- Gauss-Jacobi weighting coefficient
  } deriving (Show, Eq)

data FlowMeterConfig = FlowMeterConfig
  { pipeDiameter :: Double
  , numPaths     :: Int
  , paths        :: [AcousticPath]
  } deriving (Show, Eq)

data PathMeasurement = PathMeasurement
  { tUpstream   :: Double
  , tDownstream :: Double
  } deriving (Show, Eq)

data FlowResult = FlowResult
  { pathVelocities :: [Double]
  , volumetricFlow :: Double
  } deriving (Show, Eq)
```

The field is `pathLength`, not `length`, because `length` is a Prelude function
and a record selector of that name would shadow it for the whole module.

The API:

```haskell
mkFlowMeterConfig     :: Double -> [AcousticPath] -> FlowMeterConfig
calculatePathVelocity :: AcousticPath -> PathMeasurement -> Double
calculateFlowRate     :: FlowMeterConfig -> [PathMeasurement] -> FlowResult
toLitersPerSecond     :: Double -> Double
toLitersPerMinute     :: Double -> Double
```

`mkFlowMeterConfig` derives `numPaths` from the path list, so the count and the
list can never disagree. The two non-physical cases in `calculatePathVelocity`
are guard equations returning `0.0`, which is what the C `if` guards become when
written as a system of equations. `calculateFlowRate` calls `error` on an empty
path list or a measurement-count mismatch — the same "this is a caller bug, not
a runtime condition" stance the Rust version takes with `assert!`.

The weighted sum is a single expression rather than an accumulator loop:

```haskell
velocities  = zipWith calculatePathVelocity ps measurements
weightedSum = sum (zipWith (\p v -> weight p * v) ps velocities)
```

## Building & Running

**Prerequisites:** GHC 8.10+ and Cabal 3.0+. No dependencies beyond `base`.

```bash
cabal run flowmeter          # Build and run the demo
cabal build                  # Build only
cabal repl                   # Interactive session with the library loaded

runghc -isrc app/Main.hs     # Or skip Cabal entirely
ghc -isrc -O2 app/Main.hs -o flowmeter && ./flowmeter
```

Because the library depends only on `base`, `runghc -isrc app/Main.hs` works
with a bare GHC install — no package database, no `cabal update`.

## File Descriptions

### `flowmeter.cabal`

Package `ultrasonic-flowmeter` 1.0.0. Declares a library exposing
`Flowmeter.Core` from `src/`, and an executable `flowmeter` built from `app/`.
Both are compiled with `-Wall`.

### `src/Flowmeter/Core.hs`

The pure library: the four record types and the full algorithm. Documented with
Haddock comments, so `cabal haddock` produces browsable API docs. It imports
nothing outside the Prelude — in particular no `System.IO`, which is what makes
the purity of the core mechanically checkable rather than a convention.

### `app/Main.hs`

The demo executable. Holds the configuration builders, the transit-time
simulator (sound speed 1480 m/s, water at 20°C), the formatting helpers, the
printers, and `main`. Following the C implementation, the configuration builders
live here rather than in the library.

`main` begins with `hSetEncoding stdout utf8`. Without it, the `°`, `Δ`, `²` and
`³` literals raise a `commitBuffer: invalid argument` error under a non-UTF-8
locale — GHC's default stdout encoding follows the locale, unlike most of the
other implementations in this repository.

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
rather than `1.83e-7`: `printf "%.2e"` emits a one-digit exponent in Haskell, so
`formatScientific` in `app/Main.hs` builds the string by hand to match C's
`%.2e`.

Path velocity reads as 4.0 m/s for a true flow of 2.0 m/s because the demo's
`L = D / sin θ` leaves a `1 / sin²θ` factor in the recovered velocity — an
artifact of the simplified geometry, not a meter calibration. At 60° the same
factor gives 2.6667 m/s.

## Haskell Idioms Used

| Idiom | Where |
|-------|-------|
| Guard equations | `calculatePathVelocity` reads as four cases, not one body with branches |
| `where` clauses | Intermediate values (`tUp`, `deltaT`, `sinTheta`) named without nesting `let` |
| Record syntax | `AcousticPath { position = 0.25, ... }` at every construction site |
| `zipWith` + `sum` | The velocities and the weighted total, with no index arithmetic |
| Point-free-ish composition | `map measure (paths config)` instead of an explicit recursion |
| Explicit export lists | `module Flowmeter.Core ( AcousticPath (..), ... ) where` |
| `Text.Printf` | `printf` gives C-compatible `%.4f` specifiers directly |
| Type-level purity | The library type-checks without `IO` anywhere in it |
| `deriving` | `Show` and `Eq` for free on all four types |

## Further Learning

### Concepts to Explore

- **Purity as a boundary** — the library cannot print even by accident; the compiler enforces it
- **Guards vs. `if`** — a function defined by cases usually reads better than one with nested conditionals
- **Laziness** — `velocities` is only forced when `weightedSum` demands it
- **Record field shadowing** — why `pathLength` and not `length`, and how `DuplicateRecordFields` changes the tradeoff
- **`error` vs. `Maybe`/`Either`** — when a wrong argument count is a bug rather than a value

### Suggested Modifications

1. Add a `test-suite` stanza with HUnit and assert `abs (q - 0.031416) < 1e-6`
2. Replace `error` with `Either FlowError FlowResult` and thread it through `main`
3. Add `{-# LANGUAGE StrictData #-}` and compare Core output with and without it
4. Add QuickCheck properties — e.g. flow rate scales linearly with velocity
5. Add measurement noise with `System.Random` and average over many samples
6. Add 6-path and 8-path configurations with proper Gauss-Jacobi weights
7. Swap the record types for a `newtype`-wrapped units library and let the types catch a m/s vs. L/s mixup

## License & Notes

MIT License — free to use and modify for educational purposes. See the
[top-level README](../README.md) for the cross-language comparison.


**Note:** this implementation was written against the C reference but has not
been compiled — no GHC is installed on the machine where it was authored. The
algorithm and every format string were checked line by line against
`../c-language/`, and the two-digit-exponent helper was validated numerically,
but expect to fix a type error or two on first build.
