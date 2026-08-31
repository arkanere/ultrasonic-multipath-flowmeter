# Ultrasonic Multipath Flow Meter — Emacs Lisp

An Emacs Lisp implementation of a transit-time differential ultrasonic flow
meter for educational purposes. It computes the same physics as the [C
implementation](../c-language/), written as `cl-defstruct` records and run under
`emacs --batch` — an editor extension language used as a general-purpose one.

## Table of Contents

- [Overview](#overview)
- [Physics & Theory](#physics--theory)
- [Architecture](#architecture)
- [Running](#running)
- [Interactive Usage](#interactive-usage)
- [File Descriptions](#file-descriptions)
- [Example Output](#example-output)
- [Emacs Lisp Idioms Used](#emacs-lisp-idioms-used)
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

Records are `cl-defstruct`s with `:read-only t` slots. Emacs Lisp has no
namespaces, so — as every Emacs package does — every global name carries the
`flowmeter-` prefix, and the demonstration's internals carry a `--` in the name
to mark them private by convention:

```elisp
(cl-defstruct (flowmeter-path (:constructor flowmeter-path--create))
  (position 0.0 :read-only t)   ; normalized to -1..1
  (angle    0.0 :read-only t)   ; radians from the pipe axis
  (length   0.0 :read-only t)   ; the chord D / sin(angle)
  (weight   0.0 :read-only t))  ; Gauss-Jacobi coefficient
```

The raw constructors are private; the public ones derive:

```elisp
(flowmeter-make-path pipe-diameter position angle weight)  ; derives length
(flowmeter-make-measurement t-upstream t-downstream)       ; derives delta-t
(flowmeter-make-config pipe-diameter paths)                ; copies the path list
```

The algorithm and the builders:

```elisp
(flowmeter-num-paths config)
(flowmeter-pipe-area config)                    ; π (D/2)²
(flowmeter-path-velocity path measurement)      ; m/s
(flowmeter-flow-rate config measurements)       ; a flowmeter-result

(flowmeter-2-path-config pipe-diameter)
(flowmeter-4-path-config pipe-diameter)

(flowmeter-cubic-meters-to-liters-per-second m3-per-s)
(flowmeter-cubic-meters-to-liters-per-minute m3-per-s)
```

`flowmeter-make-path` derives the path length, so the `D / sin(θ)` formula
appears exactly once. `flowmeter-flow-rate` calls `error` if the configuration
has no paths or if the measurement count does not match.
`flowmeter-path-velocity` returns `0.0` for non-physical transit times or a
degenerate (axial) path angle, matching the C behavior.

### Two things Emacs makes you decide

**`princ`, not `message`.** Under `--batch`, `message` writes to **stderr** —
it is the echo-area function, and the echo area is the terminal's error stream.
Redirecting the program's stdout to a file would capture nothing. `princ` writes
to `standard-output`, which under batch is stdout, so every line goes through
the one-line `flowmeter-main--say` helper built on it.

**`lexical-binding: t`.** Emacs Lisp still defaults to dynamic binding for files
without the header cookie. The closure passed to `mapcar` in
`flowmeter-main--simulate-measurements` captures `true-flow-velocity`; under
dynamic binding that capture does not happen the way the rest of this repository
assumes. Both files carry the cookie on line 1, which is where Emacs looks for
it.

Beyond that, `float-pi` is provided, `format` is a faithful wrapper over C's
`printf` — `%.2e` and all — and Emacs floats are IEEE-754 doubles, so the
arithmetic and the output match C without any adjustment.

## Running

**Prerequisites:** Emacs 25.1 or newer, for `cl-lib` and `float-pi`. Tested with
GNU Emacs 30.2.

```bash
emacs --batch -l main.el
```

`main.el` puts its own directory on `load-path` before `(require 'flowmeter)`,
so the command works from anywhere. The file ends in a call to
`flowmeter-main`, so loading it is running it.

To byte-compile (optional; it changes nothing but speed):

```bash
emacs --batch -f batch-byte-compile flowmeter.el
```

## Interactive Usage

The core has no side effects on load, so `ielm` is the natural place to poke at
it:

```
M-x ielm
```

```elisp
ELISP> (add-to-list 'load-path "/path/to/emacs-language")
ELISP> (require 'flowmeter)
flowmeter

ELISP> (setq config (flowmeter-2-path-config 0.1))
ELISP> (flowmeter-pipe-area config)
0.007853981633974483

ELISP> (flowmeter-path-length (car (flowmeter-config-paths config)))
0.14142135623730953

ELISP> (setq m (flowmeter-make-measurement (/ 0.1 (- 1480 2)) (/ 0.1 (+ 1480 2))))
ELISP> (flowmeter-measurement-delta-t m)
1.8261538096308498e-07

ELISP> (setq result (flowmeter-flow-rate config (list m m)))
ELISP> (flowmeter-result-volumetric-flow result)
0.031415926535899315
ELISP> (flowmeter-result-path-velocities result)
(4.000000000000176 4.000000000000176)
```

Because the structs are `cl-defstruct`s, `C-h o` (`describe-symbol`) documents
every accessor, `cl-print` renders a record readably, and `M-x edebug-defun` on
`flowmeter-path-velocity` lets you step the formula one subexpression at a time
— the reason to write this in Emacs Lisp rather than anything else.

## File Descriptions

### `flowmeter.el`

The algorithm: four `cl-defstruct` records, the deriving constructors, the two
solver functions, the config builders, and the unit conversions. Ends in
`(provide 'flowmeter)`. Pure — nothing here prints, reads a buffer, or touches
the minibuffer.

### `main.el`

Simulation and presentation. Holds `flowmeter-main-sound-speed`, the
`flowmeter-main--say` output helper, the printers, `flowmeter-main--run-demo`,
and `flowmeter-main`. This is the only file that writes to `standard-output`.

Both files carry the `-*- lexical-binding: t; -*-` cookie and the conventional
`;;; Commentary:` / `;;; Code:` structure that `checkdoc` and the package
linters expect.

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
byte-identical to the C reference, exponent padding included.

Path velocity reads as 4.0 m/s for a true flow of 2.0 m/s because the demo's
`L = D / sin θ` leaves a `1 / sin²θ` factor in the recovered velocity — an
artifact of the simplified geometry, not a meter calibration. At 60° the same
factor gives 2.6667 m/s.

## Emacs Lisp Idioms Used

| Idiom | Where |
|-------|-------|
| `lexical-binding: t` cookie | Line 1 of both files; closures capture the way you expect |
| `cl-defstruct` with `:read-only t` | All four records |
| Private `--create` constructors | Raw slot setting is hidden behind the deriving constructors |
| `flowmeter-` prefix | Namespacing by convention, because there are no namespaces |
| `--` for internal names | `flowmeter-main--say` and friends, private by convention |
| `cl-loop` | The weighted sum, and numbering paths `1..n` when printing |
| `cl-mapcar` over two lists | Pairing paths with measurements |
| `princ` over `message` | Writing to stdout instead of stderr under `--batch` |
| `float-pi` | Provided, unlike in Vimscript or awk |
| `(provide 'flowmeter)` / `require` | The file-level module protocol |
| `;;; Commentary:` headers | The library layout `checkdoc` expects |

## Further Learning

### Concepts to Explore

- **Dynamic vs. lexical binding** — remove the cookie from `main.el` and watch the closure break
- **`message` vs. `princ`** — `emacs --batch -l main.el > out.txt` proves which stream is which
- **`cl-lib` vs. core Elisp** — `cl-loop` is a compiler macro, not a function
- **Emacs floats** — IEEE-754 doubles, hence output identical to C's
- **Edebug** — instrumenting `flowmeter-path-velocity` and stepping the formula

### Suggested Modifications

1. Add an interactive `M-x flowmeter` command that renders the report into a dedicated buffer
2. Add ERT tests (`ert-deftest`) and run them with `emacs --batch -l ert -l tests.el -f ert-run-tests-batch-and-exit`
3. Define a `flowmeter-mode` with font-lock rules for the report buffer
4. Make the pipe diameter and flow velocity `defcustom`s
5. Add measurement noise and average over many samples
6. Add 6-path and 8-path configurations with proper Gauss-Jacobi weights
7. Draw the recovered velocity profile as an SVG image inserted into the buffer

## License & Notes

MIT License — free to use and modify for educational purposes. See the
[top-level README](../README.md) for the cross-language comparison.
