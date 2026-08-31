# Ultrasonic Multipath Flow Meter

A transit-time differential ultrasonic flow meter algorithm, implemented
seventeen times — in **C**, **C++**, **Rust**, **Go**, **Basic**, **Pascal**,
**Python**, **JavaScript**, **TypeScript**, **Clojure**, **Common Lisp**,
**Elixir**, **Haskell**, **Emacs Lisp**, **Lua**, **Vimscript**, and **Bash** —
for educational purposes. The physics is fixed; only the language idioms change,
so the seventeen `core` modules can be read side by side as a study in memory
models, error handling, iteration, and packaging.

The last four are the interesting ones. Vimscript, Emacs Lisp, and Lua are
editor scripting languages rarely written as standalone programs, and Bash has
no floating-point arithmetic at all — each has to solve a problem the other
thirteen never encounter.

- **GitHub:** https://github.com/arkanere/ultrasonic-multipath-flowmeter

## The Physics

Ultrasonic flow meters measure liquid flow non-invasively — no moving parts, no
pressure drop — by timing an ultrasonic pulse across the pipe both with the flow
and against it.

### Transit-time differential method

An acoustic pulse travels at the speed of sound `c` plus or minus the fluid
velocity `v`:

```
Downstream (with flow):    speed = c + v   → shorter transit time  t_down
Upstream  (against flow):   speed = c - v   → longer transit time   t_up

Δt = t_up - t_down
```

The speed of sound cancels out of `Δt`, so the meter recovers the flow velocity
without needing to know `c` (which drifts with temperature and fluid
composition). Only the difference matters.

### Path velocity

For a single acoustic path at angle θ to the pipe axis:

```
v_path = (L / (2 · sin θ)) · (Δt / (t_up · t_down))

L   = acoustic path length (the chord D / sin θ)
θ   = angle between the acoustic path and the pipe axis
Δt  = t_up - t_down
```

The `L / (2 · sin θ)` factor projects the diagonal measurement back onto the
pipe axis.

### Volumetric flow rate

A single path samples velocity at one place, but real pipes have a velocity
profile (fast at the center, slow at the walls). Multiple paths at different
positions approximate the cross-sectional integral by **Gauss-Jacobi
quadrature** — a weighted sum:

```
Q = (π · D² / 4) · Σ (w_i · v_i)

D   = pipe diameter        (π · D² / 4 = pipe area)
w_i = weight for path i
v_i = velocity on path i
```

More paths, at well-chosen angles and positions, average out systematic errors
(pipe-diameter uncertainty, angle miscalibration) and cover non-ideal flow
profiles better.

### Why the recovered velocity looks doubled

The demos simulate a true flow of 2.0 m/s but report 4.0 m/s on a 45° path. That
is expected: the simplified geometry `L = D / sin θ` leaves a `1 / sin²θ` factor
in the recovered value (`1 / sin²45° = 2`). At 60° the factor is `1 / sin²60° ≈
1.333`, giving 2.667 m/s. A real meter calibrates this out; the demos leave it
visible.

## Path Configurations

| Config | Paths | Angle | Position | Weight | Use case |
|--------|-------|-------|----------|--------|----------|
| **2-path** | 1–2 | 45° | ±0.25 D | 0.5 | Fast, low-cost measurement |
| **4-path** | 1–2 | 60° | ±0.35 D | 0.25 | Sample near the pipe wall |
| | 3–4 | 45° | ±0.15 D | 0.25 | Sample near the center |

The gap between the 2-path and 4-path flow rates is not an error — the different
path angles sample the velocity profile differently, which is exactly what a
real multipath meter exploits.

## The Seventeen Implementations

Every implementation follows the same split: a **core** module holding the pure
~40-line algorithm, and a **main** module holding the simulation, formatting, and
entry point. Each directory has its own README with the physics, an architecture
walkthrough, build details, and language-specific idioms.

| Language | Directory | Character |
|----------|-----------|-----------|
| **C** | [`c-language/`](c-language/) | Systems programming, manual `malloc`/`free` |
| **C++** | [`cpp-language/`](cpp-language/) | Value semantics, RAII, `std::vector` |
| **Rust** | [`rust-language/`](rust-language/) | Ownership, iterators, library + binary crate |
| **Go** | [`go-language/`](go-language/) | Explicit errors, value semantics, package + `cmd` binary |
| **Basic** | [`basic-language/`](basic-language/) | Procedural, `.bi` headers, explicit typing |
| **Pascal** | [`pascal-language/`](pascal-language/) | Structured, units, `const` record parameters |
| **Python** | [`python-language/`](python-language/) | Frozen dataclasses, type hints, stdlib only |
| **JavaScript** | [`javascript-language/`](javascript-language/) | ES modules, frozen plain objects |
| **TypeScript** | [`typescript-language/`](typescript-language/) | `readonly` types; immutability checked, not frozen |
| **Clojure** | [`clojure-language/`](clojure-language/) | Functional, REPL-driven, immutable maps |
| **Common Lisp** | [`lisp-language/`](lisp-language/) | `defstruct` records, ASDF systems, `format` directives |
| **Elixir** | [`elixir-language/`](elixir-language/) | Functional, pattern matching, BEAM runtime |
| **Haskell** | [`haskell-language/`](haskell-language/) | Pure functional, lazy, `IO`-free core |
| **Emacs Lisp** | [`emacs-language/`](emacs-language/) | `cl-defstruct`, lexical binding, runs under `--batch` |
| **Lua** | [`neovim-language/`](neovim-language/) | One data structure — the table; run by Neovim's `-l` |
| **Vimscript** | [`vim-language/`](vim-language/) | Dictionaries, `cpoptions` dance, output via `writefile` |
| **Bash** | [`bash-language/`](bash-language/) | Shell as glue, `awk` as the FPU, globals as return values |

## Running Them

Each implementation is self-contained, takes no arguments, and hardcodes the same
scenario: a 100 mm pipe with a true flow velocity of 2.0 m/s (sound speed 1480
m/s, water at 20 °C). It runs the 2-path configuration, then the 4-path
configuration, and prints the results.

| Language | From the repo root |
|----------|--------------------|
| C | `cd c-language && make && ./flowmeter` |
| C++ | `cd cpp-language && make && ./flowmeter` |
| Rust | `cd rust-language && cargo run` |
| Go | `cd go-language && go run ./cmd/flowmeter` |
| Basic | `cd basic-language && make && ./flowmeter` |
| Pascal | `cd pascal-language && make && ./flowmeter` |
| Python | `cd python-language && python3 -m ultrasonic_flowmeter` |
| JavaScript | `cd javascript-language && node src/main.js` |
| TypeScript | `cd typescript-language && npm install && npm start` |
| Clojure | `cd clojure-language && lein run` |
| Common Lisp | `cd lisp-language && sbcl --script src/main.lisp` |
| Elixir | `cd elixir-language && mix run -e "UltrasonicFlowmeter.Main.main([])"` |
| Haskell | `cd haskell-language && cabal run flowmeter` |
| Emacs Lisp | `cd emacs-language && emacs --batch -l main.el` |
| Lua | `cd neovim-language && nvim --headless -l main.lua` |
| Vimscript | `cd vim-language && vim -es -S main.vim` |
| Bash | `cd bash-language && bash main.sh` |

See each directory's README for prerequisites, REPL usage, and optimized builds.

### Expected output

```
=== 2-PATH CONFIGURATION ===
  Path 1 velocity: 4.0000 m/s
  Path 2 velocity: 4.0000 m/s
  Volumetric Flow Rate: 0.031416 m³/s (1884.9556 L/min, 31.42 L/s)

=== 4-PATH CONFIGURATION ===
  Path 1 velocity: 2.6667 m/s
  Path 2 velocity: 2.6667 m/s
  Path 3 velocity: 4.0000 m/s
  Path 4 velocity: 4.0000 m/s
  Volumetric Flow Rate: 0.026180 m³/s (1570.7963 L/min, 26.18 L/s)
```

## Verification Status

| Implementation | vs. the C reference |
|----------------|---------------------|
| C | reference |
| C++, Python, Clojure, Elixir | byte-identical console output |
| Go, Common Lisp, Emacs Lisp, Lua, Vimscript, Bash | byte-identical console output |
| Pascal, Haskell | byte-identical console output |
| Rust, JavaScript, TypeScript | identical numbers; native exponent format prints `1.83e-7` where C's `%.2e` prints `1.83e-07` |
| Basic | **not compiled** — FreeBASIC does not target macOS; see below |

Thirteen of the seventeen match C byte for byte. Four of them needed a
hand-written scientific-notation helper to get there — Basic, Pascal, Haskell,
and Common Lisp, whose native `~E`-style output drops the exponent's leading
zero. Go, Emacs Lisp, Lua, Vimscript, and Bash all reach C's `printf` closely
enough to need nothing.

Pascal compiled and matched on the first attempt. Haskell needed one fix: three
`where`-bound printers had to be given explicit type signatures, because
`printf` is variadic through a return-type class and GHC cannot infer which
instance an un-annotated local binding should use.

**Basic is the exception.** FreeBASIC does not target macOS — upstream dropped
Darwin support years ago, the 1.10.1 release ships no macOS asset of any
architecture, and the last Darwin builds were 32-bit x86 that Apple Silicon
cannot run. The implementation was checked line by line against `c-language/`
but has never been executed; see
[`basic-language/README.md`](basic-language/README.md) for how to run it under
Linux, where `fbc` is widely packaged.

To check the equivalence, run each command from the table above, redirect the
output to a file, and `diff` against the C output:

```bash
(cd c-language && make) && ./c-language/flowmeter > /tmp/ref.txt
diff <(cd go-language && go run ./cmd/flowmeter) /tmp/ref.txt
```

## License

MIT License — free to use and modify for educational purposes.
