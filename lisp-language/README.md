# Ultrasonic Multipath Flow Meter — Common Lisp

A Common Lisp implementation of a transit-time differential ultrasonic flow
meter for educational purposes. It computes the same physics as the [C
implementation](../c-language/), written as `defstruct` records in an ASDF
system, with a hand-rolled scientific formatter so the output matches C exactly.

## Table of Contents

- [Overview](#overview)
- [Physics & Theory](#physics--theory)
- [Architecture](#architecture)
- [Running](#running)
- [Interactive Usage](#interactive-usage)
- [File Descriptions](#file-descriptions)
- [Example Output](#example-output)
- [Common Lisp Idioms Used](#common-lisp-idioms-used)
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

Records are `defstruct`s with `:read-only t` slots and a `:conc-name` that names
the concept rather than the struct — `path-angle`, not `acoustic-path-angle`:

```lisp
(defstruct (acoustic-path (:conc-name path-) (:copier nil))
  (position 0d0 :type double-float :read-only t)
  (angle    0d0 :type double-float :read-only t)
  (length   0d0 :type double-float :read-only t)
  (weight   0d0 :type double-float :read-only t))
```

Each struct is paired with a plain function of the same name that does the
derivation the raw constructor would not:

```lisp
(acoustic-path pipe-diameter position angle weight)  ; derives length
(path-measurement t-upstream t-downstream)           ; derives delta-t
(flow-meter-config pipe-diameter paths)              ; copies the path list
```

A symbol names a function and a type independently in Common Lisp, so
`acoustic-path` can be both a struct type and the function that builds one. The
generated `make-acoustic-path` remains exported for anyone who wants the raw
slots.

The algorithm and the builders:

```lisp
(pipe-area config)                        ; π (D/2)²
(calculate-path-velocity path measurement) ; m/s
(calculate-flow-rate config measurements)  ; a flow-result

(create-2path-config pipe-diameter)
(create-4path-config pipe-diameter)

(cubic-meters-to-liters-per-second m3-per-s)
(cubic-meters-to-liters-per-minute m3-per-s)
```

`acoustic-path` derives the path length from the pipe diameter and angle, so the
`D / sin(θ)` formula appears exactly once. `calculate-flow-rate` signals a
`flow-meter-error` — a `simple-error` subtype, so it is handleable by class —
if the configuration has no paths or if the measurement count does not match.
`calculate-path-velocity` returns `0d0` for non-physical transit times or a
degenerate (axial) path angle, matching the C behavior.

**Every literal carries a `d0` suffix.** An unsuffixed `0.25` in Common Lisp is
a `single-float`, and the whole exercise is to compute in the same IEEE-754
doubles the C reference uses. `(float x 0d0)` coerces caller-supplied numbers at
the boundary, and the `:type double-float` slot declarations make a mistake a
loud one.

**`format` cannot print C's `%.2e`.** The `~E` directive produces `1.83e-7` — no
forced sign, no zero-padded exponent — so `main.lisp` carries a
`format-scientific` helper that normalizes the mantissa into `[1, 10)`, handles
the case where rounding pushes it back to `10.00`, and assembles the string by
hand. The Basic, Pascal, and Haskell implementations carry the same helper for
the same reason. Everything else uses `~,3F`, `~,4F`, `~,6F`, and `~D`, which
round the way C's `printf` does.

## Running

**Prerequisites:** SBCL, or any ANSI Common Lisp. Tested with SBCL 2.6.8.

```bash
sbcl --script src/main.lisp
```

`--script` implies `--no-userinit`, `--no-sysinit`, and `--disable-debugger`, so
the run is reproducible regardless of what is in `~/.sbclrc`. `main.lisp` loads
`core.lisp` from its own directory, so the command works from anywhere.

Through ASDF instead:

```bash
sbcl --eval '(require :asdf)' \
     --eval '(asdf:load-asd (merge-pathnames "ultrasonic-flowmeter.asd" (uiop:getcwd)))' \
     --eval '(asdf:load-system "ultrasonic-flowmeter/main")' \
     --quit
```

To build a standalone executable:

```bash
sbcl --eval '(require :asdf)' \
     --eval '(asdf:load-asd (merge-pathnames "ultrasonic-flowmeter.asd" (uiop:getcwd)))' \
     --eval '(asdf:make "ultrasonic-flowmeter/main")' \
     --quit
./flowmeter
```

## Interactive Usage

The core has no side effects on load, so it belongs in the REPL:

```bash
sbcl --load src/core.lisp
```

```lisp
* (in-package #:ultrasonic-flowmeter)

* (defparameter *config* (create-2path-config 0.1d0))
*CONFIG*

* (pipe-area *config*)
0.007853981633974483d0

* (defparameter *m*
    (let ((m (path-measurement (/ 0.1d0 (- 1480 2)) (/ 0.1d0 (+ 1480 2)))))
      (list m m)))
*M*

* (measurement-delta-t (first *m*))
1.8261538096308498d-7

* (result-volumetric-flow (calculate-flow-rate *config* *m*))
0.031415926535899315d0

* (result-path-velocities (calculate-flow-rate *config* *m*))
(4.000000000000176d0 4.000000000000176d0)
```

`describe` and `inspect` work on the structs directly:

```lisp
* (describe (first (config-paths *config*)))
```

Loading `src/main.lisp` into a REPL runs the demonstration once — the file ends
in a call to `main` — and leaves `ultrasonic-flowmeter/main:main` available to
call again.

## File Descriptions

### `src/core.lisp`

The package definition, the four `defstruct` records, the `flow-meter-error`
condition, the derivation constructors, the two solver functions, the config
builders, and the unit conversions. Pure — nothing here writes to a stream.

### `src/main.lisp`

Simulation and presentation, in its own `ultrasonic-flowmeter/main` package.
Holds `+sound-speed+`, `format-scientific`, the printers, `run-demo`, and
`main`. This is the only file that writes to `*standard-output*`.

### `ultrasonic-flowmeter.asd`

Two ASDF systems: `ultrasonic-flowmeter` (the core alone) and
`ultrasonic-flowmeter/main` (the demo, with a `program-op` build target and an
entry point). The file is named after its primary system, as ASDF requires.

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
byte-identical to the C reference, `1.83e-07` included — that is what
`format-scientific` is for.

Path velocity reads as 4.0 m/s for a true flow of 2.0 m/s because the demo's
`L = D / sin θ` leaves a `1 / sin²θ` factor in the recovered velocity — an
artifact of the simplified geometry, not a meter calibration. At 60° the same
factor gives 2.6667 m/s.

## Common Lisp Idioms Used

| Idiom | Where |
|-------|-------|
| `defstruct` with `:read-only t` | All four records; immutability without ceremony |
| `:conc-name` | `path-angle` rather than `acoustic-path-angle` |
| Function and type sharing a name | `acoustic-path` is both a struct type and its deriving constructor |
| `defpackage` with explicit `:export` | The core's API is the export list, nothing more |
| `define-condition` | `flow-meter-error`, handleable by class rather than by string |
| `d0` float literals | Forcing `double-float` instead of the default `single-float` |
| `loop ... for ... sum ... into` | The weighted velocity sum |
| `mapcar` over two lists | Pairing paths with measurements in `calculate-flow-rate` |
| `format` directives | `~,4F`, `~D`, `~%`, and `~:[~;-~]` for the sign in `format-scientific` |
| `eval-when` | Loading the core at compile, load, and execute time alike |
| ASDF system definition | `:serial t` components, `program-op`, `:entry-point` |

## Further Learning

### Concepts to Explore

- **Float contagion** — why `(/ pi 4.0)` and `(/ pi 4d0)` are not the same computation
- **`format` directives** — read the `~F`, `~E`, and `~:[` entries in the HyperSpec, then re-read `format-scientific`
- **Conditions vs. exceptions** — `handler-case` versus `handler-bind`, and why the restart system has no equivalent elsewhere in this repository
- **`defstruct` vs. CLOS** — when a struct's speed beats a class's flexibility
- **Symbols in two namespaces** — how `acoustic-path` names both a function and a type

### Suggested Modifications

1. Add a test system with FiveAM or Parachute and an `asdf:test-op`
2. Re-express the records as CLOS classes and compare the code and the speed
3. Signal a `flow-meter-error` with a restart that supplies a default measurement
4. Add measurement noise and average over many samples
5. Add 6-path and 8-path configurations with proper Gauss-Jacobi weights
6. Write a `~/` custom format directive for the scientific notation instead of a helper function
7. Add `(declaim (optimize (speed 3)))` and read SBCL's compiler notes about the boxed floats

## License & Notes

MIT License — free to use and modify for educational purposes. See the
[top-level README](../README.md) for the cross-language comparison.
