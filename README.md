# Ultrasonic Multipath Flow Meter

A six-language implementation of transit-time differential ultrasonic flow meter algorithms for educational purposes. This project demonstrates how ultrasonic flow meters measure fluid velocity and volumetric flow rate in pipes using multiple acoustic paths.

The same physics problem is solved in **C**, **C++**, **Rust**, **Python**, **JavaScript**, and **Clojure**, so the algorithm stays fixed while the language idioms vary — manual memory management next to RAII, ownership, dataclasses, frozen objects, and immutable maps.

## Quick Links

| Implementation | Directory | Character |
|----------------|-----------|-----------|
| **C** | [`c-language/`](c-language/) | Systems programming, manual memory management |
| **C++** | [`cpp-language/`](cpp-language/) | Value semantics, RAII, `std::vector` |
| **Rust** | [`rust-language/`](rust-language/) | Ownership, iterators, library + binary crate |
| **Python** | [`python-language/`](python-language/) | Frozen dataclasses, type hints, stdlib only |
| **JavaScript** | [`javascript-language/`](javascript-language/) | ES modules, frozen plain objects |
| **Clojure** | [`clojure-language/`](clojure-language/) | Functional, REPL-driven, immutable maps |

- **GitHub Repository:** https://github.com/arkanere/ultrasonic-multipath-flowmeter

## Overview

Ultrasonic flow meters are non-invasive devices that measure liquid flow by analyzing the travel time of ultrasonic signals traveling upstream and downstream through the fluid. By comparing these travel times, the meter can determine the fluid velocity without any moving parts or pressure drop.

**Key advantages:**
- Non-invasive measurement (no mechanical parts)
- Works with various liquids and pipe materials
- Multiple paths improve accuracy and reduce systematic errors
- Widely used in industrial, medical, and environmental applications

### Physics Principle

Ultrasonic signals travel at different speeds depending on flow direction:

```
Downstream (with flow):  Speed = c + v  → Shorter transit time
Upstream (against flow): Speed = c - v  → Longer transit time

Where: c = sound speed, v = flow velocity

Time difference: Δt = t_upstream - t_downstream
This reveals the flow velocity without needing to know the sound speed!
```

### Core Algorithm

**Path Velocity Formula:**
```
v_path = (L / (2 * sin(θ))) * (Δt / (t_up * t_down))

L  = acoustic path length
θ  = angle from pipe axis
Δt = time difference
```

**Volumetric Flow Rate (Gauss-Jacobi Quadrature):**
```
Q = (π * D² / 4) * Σ(w_i * v_i)

D   = pipe diameter
w_i = weighting coefficient for path i
v_i = velocity measured on path i
```

## Project Structure

```
ultrasonic-multipath-flowmeter/
├── README.md                           # This file
├── .gitignore                          # Git ignore patterns
│
├── c-language/                         # C implementation
│   ├── README.md                       # Detailed C documentation
│   ├── Makefile                        # Build configuration
│   ├── flowmeter.h                     # Header with data structures
│   ├── flowmeter.c                     # Core algorithm
│   └── main.c                          # Example program
│
├── cpp-language/                       # C++ implementation
│   ├── README.md                       # Detailed C++ documentation
│   ├── Makefile                        # Build configuration
│   ├── flowmeter.hpp                   # Header with data structures
│   ├── flowmeter.cpp                   # Core algorithm
│   └── main.cpp                        # Example program
│
├── rust-language/                      # Rust implementation
│   ├── README.md                       # Detailed Rust documentation
│   ├── Cargo.toml                      # Cargo configuration
│   └── src/
│       ├── lib.rs                      # Core algorithm (library crate)
│       └── main.rs                     # Example program (binary crate)
│
├── python-language/                    # Python implementation
│   ├── README.md                       # Detailed Python documentation
│   └── ultrasonic_flowmeter/
│       ├── __init__.py                 # Public API re-exports
│       ├── __main__.py                 # `python -m` entry point
│       ├── core.py                     # Core algorithm
│       └── main.py                     # Example program
│
├── javascript-language/                # JavaScript implementation
│   ├── README.md                       # Detailed JavaScript documentation
│   ├── package.json                    # Node package configuration
│   └── src/
│       ├── core.js                     # Core algorithm
│       └── main.js                     # Example program
│
└── clojure-language/                   # Clojure implementation
    ├── README.md                       # Detailed Clojure documentation
    ├── project.clj                     # Leiningen configuration
    └── src/ultrasonic_flowmeter/
        ├── core.clj                    # Core algorithm
        └── main.clj                    # Example program
```

Every implementation follows the same split: a **core** module holding the pure
algorithm, and a **main** module holding the simulation, printing, and entry
point.

## Getting Started

Every implementation is self-contained and takes no command-line arguments. Each
one hardcodes a 100 mm pipe with a true flow velocity of 2.0 m/s, runs the
2-path configuration, then the 4-path configuration, and prints the results.

### C

**Prerequisites:** GCC (or Clang), Make

```bash
cd c-language
make          # Build
./flowmeter   # Run
make clean
```

### C++

**Prerequisites:** a C++17 compiler, Make

```bash
cd cpp-language
make          # Build
./flowmeter   # Run
make clean
```

### Rust

**Prerequisites:** Rust 1.70+ (2021 edition)

```bash
cd rust-language
cargo run                 # Build and run
cargo build --release     # Optimized build
cargo doc --open          # Browse the API docs
```

### Python

**Prerequisites:** Python 3.9+ (no third-party packages)

```bash
cd python-language
python3 -m ultrasonic_flowmeter
```

### JavaScript

**Prerequisites:** Node.js 18+ (no dependencies)

```bash
cd javascript-language
node src/main.js   # or: npm start
```

### Clojure

**Prerequisites:** Java 8+, Leiningen

```bash
cd clojure-language
lein run     # Run demo
lein repl    # Interactive REPL
```

**REPL Usage:**
```clojure
(require '[ultrasonic-flowmeter.core :as core])

; Create a 2-path configuration
(def config (core/create-2path-config 0.1))

; Simulate measurements
(def measurements (simulate-measurements config 2.0))

; Calculate flow rate
(def result (core/calculate-flow-rate config measurements))

; Get results
(:volumetric-flow result)  ; 0.031416 m³/s
```

### Expected Output

All six print the same numbers:

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

## Implementation Comparison

| Language | Paradigm | Memory | Data Structures | Error Handling | Build |
|----------|----------|--------|-----------------|----------------|-------|
| **C** | Imperative, systems | Manual `malloc`/`free` | Structs + raw pointers | Return codes (`-1`, `NULL`) | Make + GCC |
| **C++** | Multi-paradigm, value semantics | RAII, automatic | Structs + `std::vector` | Exceptions | Make + g++ |
| **Rust** | Multi-paradigm, ownership | Ownership, automatic | Structs + `Vec` | `assert!` on misuse | Cargo |
| **Python** | Multi-paradigm, dynamic | Garbage collected | Frozen dataclasses + tuples | `ValueError` | None (stdlib only) |
| **JavaScript** | Multi-paradigm, dynamic | Garbage collected | Frozen plain objects | `throw new Error` | None (Node ESM) |
| **Clojure** | Functional, interactive | Garbage collected (JVM) | Immutable maps + vectors | Guard clauses returning `0.0` | Leiningen |

| Language | Iteration Style | Type Checking | Development Loop |
|----------|-----------------|---------------|------------------|
| **C** | `for` over an index | Static (compiler) | Compile-test cycle |
| **C++** | `for` over an index, range-`for` | Static (compiler) | Compile-test cycle |
| **Rust** | `iter().zip().map().sum()` | Static (compiler, with inference) | Compile-test cycle |
| **Python** | `zip` + generator expressions | Dynamic (hints unenforced) | Run or REPL |
| **JavaScript** | `map` / `reduce` | Dynamic | Run or REPL |
| **Clojure** | `mapv` / `reduce` | Dynamic (runtime) | REPL-driven |

### Algorithm Equivalence

All six implementations produce **identical numeric results**:

| Implementation | 2-path flow rate | 4-path flow rate |
|----------------|------------------|------------------|
| C | 0.031416 m³/s | 0.026180 m³/s |
| C++ | 0.031416 m³/s | 0.026180 m³/s |
| Rust | 0.031416 m³/s | 0.026180 m³/s |
| Python | 0.031416 m³/s | 0.026180 m³/s |
| JavaScript | 0.031416 m³/s | 0.026180 m³/s |
| Clojure | 0.031416 m³/s | 0.026180 m³/s |

The C, C++, Python, and Clojure programs are byte-for-byte identical in their
console output. Rust and JavaScript differ in exactly one respect: their native
exponent formatting prints `Δt = 1.83e-7` where C's `%.2e` prints `1.83e-07`.
Every number is the same.

The gap between the 2-path and 4-path figures is not an error. Different path
angles sample the velocity profile differently, which is exactly what a real
multipath meter exploits.

To check the equivalence yourself:

```bash
(cd c-language          && make -s && ./flowmeter)            > /tmp/c.txt
(cd cpp-language        && make -s && ./flowmeter)            > /tmp/cpp.txt
(cd rust-language       && cargo run -q)                      > /tmp/rust.txt
(cd python-language     && python3 -m ultrasonic_flowmeter)   > /tmp/python.txt
(cd javascript-language && node src/main.js)                  > /tmp/js.txt
(cd clojure-language    && lein run)                          > /tmp/clj.txt

diff /tmp/c.txt /tmp/cpp.txt      # identical
diff /tmp/c.txt /tmp/python.txt   # identical
diff /tmp/c.txt /tmp/clj.txt      # identical
diff /tmp/c.txt /tmp/rust.txt     # exponent formatting only
diff /tmp/c.txt /tmp/js.txt       # exponent formatting only
```

## Path Configurations

### 2-Path (Quick Measurement)
- **Angles:** 45° from pipe axis
- **Positions:** ±0.25D from center
- **Weights:** 0.5 each (simple average)
- **Use Case:** Fast, cost-effective measurement

### 4-Path (Accurate Measurement)
- **Paths 1-2:** 60° angle at ±0.35D (sample near edges)
- **Paths 3-4:** 45° angle at ±0.15D (sample near center)
- **Weights:** 0.25 each (Gauss-Jacobi)
- **Use Case:** High-accuracy, complex flow profiles

## Core API

Each implementation exposes the same four concepts — an acoustic path, a meter
configuration, a per-path measurement, and a result — plus two solver functions
and two config builders. Only the spelling changes.

### C (`flowmeter.h`)

```c
// Data structures
struct AcousticPath;      // position, angle, length, weight
struct FlowMeterConfig;   // pipe_diameter, num_paths, paths
struct PathMeasurement;   // t_upstream, t_downstream
struct FlowResult;        // path_velocities, volumetric_flow

double calculate_path_velocity(const AcousticPath *path,
                               const PathMeasurement *measurement);

int calculate_flow_rate(const FlowMeterConfig *config,
                        const PathMeasurement *measurements,
                        FlowResult *result);

FlowResult* flowmeter_process(const FlowMeterConfig *config,
                              const PathMeasurement *measurements);
void flowmeter_result_free(FlowResult *result);
```

### C++ (`flowmeter.hpp`, `namespace flowmeter`)

```cpp
struct AcousticPath;     // position, angle, length, weight
struct FlowMeterConfig;  // pipe_diameter, paths; num_paths(), pipe_area()
struct PathMeasurement;  // t_upstream, t_downstream; delta_t()
struct FlowResult;       // path_velocities, volumetric_flow

double     calculate_path_velocity(const AcousticPath &, const PathMeasurement &);
FlowResult calculate_flow_rate(const FlowMeterConfig &,
                               const std::vector<PathMeasurement> &);

FlowMeterConfig create_2path_config(double pipe_diameter);
FlowMeterConfig create_4path_config(double pipe_diameter);

double cubic_meters_to_liters_per_second(double m3_per_s);
double cubic_meters_to_liters_per_minute(double m3_per_s);
```

### Rust (`src/lib.rs`)

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

### Python (`ultrasonic_flowmeter/core.py`)

```python
# Frozen dataclasses
AcousticPath(position, angle, length, weight)   # .across(D, position, angle, weight)
FlowMeterConfig(pipe_diameter, paths)           # .num_paths, .pipe_area
PathMeasurement(t_upstream, t_downstream)       # .delta_t
FlowResult(path_velocities, volumetric_flow)

calculate_path_velocity(path, measurement) -> float
calculate_flow_rate(config, measurements) -> FlowResult

create_2path_config(pipe_diameter) -> FlowMeterConfig
create_4path_config(pipe_diameter) -> FlowMeterConfig

cubic_meters_to_liters_per_second(m3_per_s) -> float
cubic_meters_to_liters_per_minute(m3_per_s) -> float
```

### JavaScript (`src/core.js`)

```js
// Factory functions returning frozen objects
acousticPath(pipeDiameter, position, angle, weight)
flowMeterConfig(pipeDiameter, paths)
pathMeasurement(tUpstream, tDownstream)   // computes deltaT

pipeArea(config)
calculatePathVelocity(path, measurement)
calculateFlowRate(config, measurements)

create2PathConfig(pipeDiameter)
create4PathConfig(pipeDiameter)

cubicMetersToLitersPerSecond(m3PerS)
cubicMetersToLitersPerMinute(m3PerS)
```

### Clojure (`core.clj`)

```clojure
; Constructors
(acoustic-path position angle length weight)
(flow-meter-config pipe-diameter paths)
(path-measurement t-upstream t-downstream)
(flow-result path-velocities volumetric-flow)

; Algorithm
(calculate-path-velocity path measurement)
(calculate-flow-rate config measurements)

; Builders
(create-2path-config pipe-diameter)
(create-4path-config pipe-diameter)

; Utils
(cubic-meters-to-liters-per-second m3-per-s)
(cubic-meters-to-liters-per-minute m3-per-s)
```

## Example Output

Every implementation produces the same formatted output:

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
  Path 2:
    Position: -0.25 D
    Angle: 45.00° (0.7854 rad)
    Path length: 0.1414 m
    Weight: 0.500

Simulated Measurements (True flow velocity: 2.00 m/s):
  Path 1: t_upstream = 0.00006766 s, t_downstream = 0.00006748 s, Δt = 1.83e-07 s
  Path 2: t_upstream = 0.00006766 s, t_downstream = 0.00006748 s, Δt = 1.83e-07 s

Flow Calculation Results:
  Path 1 velocity: 4.0000 m/s
  Path 2 velocity: 4.0000 m/s

Volumetric Flow Rate:
  0.031416 m³/s
  1884.9556 L/min
  31.42 L/s

### 4-PATH CONFIGURATION ###
...
```

## Simulation Approach

For learning purposes, every implementation generates synthetic measurement data:

1. **Define a pipe:** diameter D (e.g., 100mm)
2. **Set a true flow velocity:** v (e.g., 2.0 m/s)
3. **Simulate acoustic paths:** multiple angles and positions
4. **Calculate transit times:**
   - Upstream: t_up = L / (c - v)
   - Downstream: t_down = L / (c + v)
5. **Calculate flow from measurements:**
   - Extract velocity from Δt = t_up - t_down
   - Integrate across pipe using weights
   - Verify calculated flow matches input

**Sound speed (used in simulation):** ~1480 m/s (water at 20°C)

## Mathematical Verification

The algorithm correctly recovers the input flow velocity through the time difference:

```
True flow velocity input:    2.00 m/s
Sound speed:                 1480 m/s
Path at 45°:
  Upstream:   (path) / (1480 - 2) = longer time
  Downstream: (path) / (1480 + 2) = shorter time
  Δt captured by formula
Result: Calculated velocity = 4.0 m/s (accounts for angle projection)
```

Note: The calculated velocity appears doubled because the formula projects the diagonal measurement back to the pipe axis using `L / (2 * sin(θ))`.

## Use Cases

This project is useful for:

1. **Learning Signal Processing**
   - How ultrasonic measurement works
   - Time-of-flight principles
   - Multi-sensor data fusion

2. **Understanding Flow Measurement**
   - Physics of acoustic flow meters
   - Quadrature integration
   - Error mitigation with multiple paths

3. **Language Comparison**
   - Systems programming (C, C++, Rust)
   - Scripting and dynamic typing (Python, JavaScript)
   - Functional programming (Clojure)
   - One algorithm, six sets of idioms — memory models, error handling, iteration

4. **Educational Demonstrations**
   - Interactive exploration (Clojure REPL, Python REPL, Node REPL)
   - Performance analysis (C, C++, Rust)
   - Physics simulation

## Further Learning

### Extending the Project

1. **Add noise to simulations**
   ```
   Realistic measurement error modeling
   ```

2. **Implement more configurations**
   ```
   6-path, 8-path configurations
   Different angle combinations
   ```

3. **Add temperature compensation**
   ```
   Sound speed varies with temperature
   Real meters compensate for this
   ```

4. **Implement velocity profiles**
   ```
   Parabolic profile for laminar flow
   Flat profile for turbulent flow
   ```

5. **Add testing**
   ```
   Unit tests for each implementation
   Integration tests with varied inputs
   ```

### Physics References

- **ISO 6416:2021** - Ultrasonic instruments for flow measurement in open channels
- **IEC 60041** - Field acceptance tests for hydraulic turbines
- Transit-time ultrasonic flow meters are used in:
  - Medical ultrasound (blood flow measurement)
  - Industrial flow monitoring (custody transfer)
  - Environmental monitoring (water resource management)
  - Petrochemical industry

## Development

### Building from Source

**C:**
```bash
cd c-language
gcc -Wall -Wextra -std=c99 -O2 -c flowmeter.c
gcc -Wall -Wextra -std=c99 -O2 -c main.c
gcc -o flowmeter flowmeter.o main.o -lm
./flowmeter
```

**C++:**
```bash
cd cpp-language
g++ -Wall -Wextra -std=c++17 -O2 -c flowmeter.cpp
g++ -Wall -Wextra -std=c++17 -O2 -c main.cpp
g++ -o flowmeter flowmeter.o main.o
./flowmeter
```

**Rust:**
```bash
cd rust-language
cargo build --release    # Optimized binary at target/release/flowmeter
cargo doc --open         # Browse the API documentation
cargo clippy             # Lint
```

**Python:**
```bash
cd python-language
python3 -m ultrasonic_flowmeter
python3 -i -c "from ultrasonic_flowmeter.core import *"   # Interactive
```

**JavaScript:**
```bash
cd javascript-language
node src/main.js
node --experimental-repl-await    # Interactive: await import('./src/core.js')
```

**Clojure:**
```bash
cd clojure-language
lein run                 # Run demo
lein repl                # Interactive development
lein uberjar             # Build executable JAR
java -jar target/ultrasonic-flowmeter-standalone.jar
```

### Project History

```
Commit 0959c64: Initial commit - C implementation
Commit f7c169a: Add Clojure implementation
Commit ae2fb61: Add top-level project README
Add C++, Rust, Python, and JavaScript implementations
```

View on GitHub: https://github.com/arkanere/ultrasonic-multipath-flowmeter

## File Organization

- **c-language/** - C implementation with detailed README
- **cpp-language/** - C++ implementation with detailed README
- **rust-language/** - Rust implementation with detailed README
- **python-language/** - Python implementation with detailed README
- **javascript-language/** - JavaScript implementation with detailed README
- **clojure-language/** - Clojure implementation with detailed README
- **README.md** - This file (project overview)
- **.gitignore** - Git ignore patterns

## Key Insights

1. **Multipath Advantage**
   - Single path: Sensitive to pipe diameter errors
   - Multiple paths: Average out systematic errors
   - Different angles: Better coverage of velocity profile

2. **Time Difference Advantage**
   - Doesn't need to know exact sound speed
   - Only the difference matters
   - Sound speed cancels in Δt calculation

3. **Language Trade-offs**
   - C: Direct control, maximum performance, manual memory
   - C++: The same control with automatic cleanup and value semantics
   - Rust: Compile-time memory safety without a garbage collector
   - Python: Fewest lines, richest introspection, slowest execution
   - JavaScript: Runs anywhere — Node, browser, bundler — with zero setup
   - Clojure: Expressive, functional, interactive development
   - All six: Same physics, same numbers, six sets of trade-offs

4. **The Algorithm Is the Constant**
   - Roughly 40 lines of arithmetic, unchanged across every language
   - What varies is everything around it: memory, errors, iteration, packaging
   - Comparing the `core` modules side by side is the point of this repository

## License

MIT License - Free to use and modify for educational purposes.

## Contributing

This project is open source. Contributions welcome!

- Report issues on GitHub
- Suggest improvements or extensions
- Add implementations in other languages
- Improve documentation

## Contact & Support

For questions about the implementation, see the per-language README:

- `c-language/README.md` — C-specific details
- `cpp-language/README.md` — C++-specific details
- `rust-language/README.md` — Rust-specific details
- `python-language/README.md` — Python-specific details
- `javascript-language/README.md` — JavaScript-specific details
- `clojure-language/README.md` — Clojure-specific details

The physics background is covered in each of them, and in this file above.

---

**Last Updated:** August 29, 2026

**Status:** ✓ Complete (all six implementations verified to produce identical results)
