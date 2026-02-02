# Ultrasonic Multipath Flow Meter - Clojure Implementation

A Clojure implementation of the transit-time differential ultrasonic flow meter algorithm. This is a functional programming approach to the same flow measurement problem solved in C, demonstrating idiomatic Clojure patterns and functional composition.

## Table of Contents

- [Quick Start](#quick-start)
- [Project Structure](#project-structure)
- [How It Works](#how-it-works)
- [Core API](#core-api)
- [Usage Examples](#usage-examples)
- [Running the Demo](#running-the-demo)
- [Clojure Idioms](#clojure-idioms)
- [Development](#development)

## Quick Start

### Prerequisites

- Java 8+
- Clojure 1.11+
- Leiningen (for building)

### Installation & Running

```bash
# Build the project
lein uberjar

# Run the demo
lein run

# Or run from REPL
lein repl
```

## Project Structure

```
clojure-language/
├── project.clj                              # Leiningen configuration
├── README.md                                # This file
└── src/
    └── ultrasonic_flowmeter/
        ├── core.clj                         # Core algorithm
        └── main.clj                         # Demo program
```

### File Descriptions

#### `project.clj`

Leiningen project configuration:
- Dependencies (Clojure 1.11.1)
- Main namespace entry point
- Project metadata

#### `src/ultrasonic_flowmeter/core.clj`

Core algorithm implementation:

**Data Constructors:**
- `acoustic-path` - Create path configuration
- `flow-meter-config` - Create meter configuration
- `path-measurement` - Create measurement data
- `flow-result` - Create result structure

**Core Algorithm:**
- `calculate-path-velocity` - Single path velocity calculation
- `calculate-flow-rate` - Multi-path integration

**Configuration Builders:**
- `create-2path-config` - 2-path meter (45° angles)
- `create-4path-config` - 4-path meter (mixed angles)

**Unit Conversion:**
- `cubic-meters-to-liters-per-second`
- `cubic-meters-to-liters-per-minute`

#### `src/ultrasonic_flowmeter/main.clj`

Demonstration and example program:

**Simulation:**
- `simulate-measurements` - Generate synthetic measurement data

**Output:**
- `print-config` - Display meter configuration
- `print-measurements` - Display measurement data
- `print-results` - Display calculated results
- `demo-2path` - Run 2-path demonstration
- `demo-4path` - Run 4-path demonstration
- `-main` - Entry point

## How It Works

### 1. Define Configuration

```clojure
(def config (core/create-2path-config 0.1))
; => {:pipe-diameter 0.1, :num-paths 2, :paths [...]}
```

### 2. Generate Measurements

```clojure
(def measurements (simulate-measurements config 2.0))
; => [{:t-upstream 0.00006766, :t-downstream 0.00006748} ...]
```

### 3. Calculate Flow Rate

```clojure
(def result (core/calculate-flow-rate config measurements))
; => {:path-velocities [4.0 4.0], :volumetric-flow 0.031416}
```

### 4. Extract Results

```clojure
(:volumetric-flow result)  ; 0.031416 m³/s

(core/cubic-meters-to-liters-per-minute (:volumetric-flow result))
; => 1884.9556 L/min
```

## Core API

### Data Structures

All data structures are represented as Clojure maps:

```clojure
;; Acoustic path
{:position 0.25          ; Position on pipe diameter (-1 to 1)
 :angle 0.7854           ; Angle from axis (radians)
 :length 0.1414          ; Path length (meters)
 :weight 0.5}            ; Weighting coefficient

;; Flow meter config
{:pipe-diameter 0.1      ; Pipe diameter (meters)
 :num-paths 2            ; Number of paths
 :paths [...]}           ; Vector of acoustic-path maps

;; Path measurement
{:t-upstream 0.00006766   ; Upstream transit time (seconds)
 :t-downstream 0.00006748}; Downstream transit time (seconds)

;; Flow result
{:path-velocities [4.0 4.0]  ; Vector of velocities (m/s)
 :volumetric-flow 0.031416}  ; Total flow rate (m³/s)
```

### Key Functions

#### `calculate-path-velocity`

```clojure
(core/calculate-path-velocity path measurement)
; Args: path (map), measurement (map)
; Returns: double (velocity in m/s)
```

Implements the transit-time differential formula:
```
v_path = (L / (2 * sin(θ))) * (Δt / (t_up * t_down))
```

#### `calculate-flow-rate`

```clojure
(core/calculate-flow-rate config measurements)
; Args: config (map), measurements (vector of maps)
; Returns: flow-result (map)
```

Integrates multiple paths using Gauss-Jacobi quadrature:
```
Q = (π * D² / 4) * Σ(w_i * v_i)
```

## Usage Examples

### Interactive REPL Usage

```clojure
;; Start REPL
lein repl

;; Create a 2-path configuration
(require '[ultrasonic-flowmeter.core :as core])
(def config (core/create-2path-config 0.1))

;; Simulate measurements
(require '[ultrasonic-flowmeter.main :as main])
(def measurements (main/simulate-measurements config 2.0))

;; Calculate flow rate
(def result (core/calculate-flow-rate config measurements))

;; Inspect results
(println result)

;; Extract specific values
(:volumetric-flow result)
(core/cubic-meters-to-liters-per-minute (:volumetric-flow result))
```

### Programmatic Usage

```clojure
(ns my-app.flow-measurement
  (:require [ultrasonic-flowmeter.core :as core]
            [ultrasonic-flowmeter.main :as main]))

(defn measure-flow
  "Measure flow rate for different velocity profiles"
  []
  (let [config (core/create-4path-config 0.1)]
    (doseq [velocity [1.0 2.0 3.0 5.0]]
      (let [measurements (main/simulate-measurements config velocity)
            result (core/calculate-flow-rate config measurements)]
        (println (format "Velocity: %.1f m/s -> Flow: %.2f L/min"
                        velocity
                        (core/cubic-meters-to-liters-per-minute
                         (:volumetric-flow result))))))))

(measure-flow)
```

## Running the Demo

### Via Leiningen

```bash
lein run
```

Output:
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

...
```

## Clojure Idioms

This implementation demonstrates several Clojure patterns:

### Maps for Data Structures

Instead of C structs, Clojure uses immutable maps:

```clojure
;; Instead of AcousticPath struct with fields
(acoustic-path 0.25 0.7854 0.1414 0.5)

;; We get a map
{:position 0.25 :angle 0.7854 :length 0.1414 :weight 0.5}

;; Destructuring extracts values
(let [{:keys [position angle length weight]} path]
  ...)
```

### Functional Composition

Instead of loops, we use higher-order functions:

```clojure
;; Vectorizing over paths
(mapv calculate-path-velocity paths measurements)

;; Calculating weighted sum
(apply + (mapv (fn [path velocity]
                 (* (:weight path) velocity))
               paths velocities))
```

### Keyword Arguments

Using keyword constructors makes intent clear:

```clojure
;; Explicit parameter names
(acoustic-path 0.25 (/ math/PI 4.0) 0.1414 0.5)

;; With destructuring in function signature
(defn calculate-path-velocity
  [{:keys [angle length]} {:keys [t-upstream t-downstream]}]
  ...)
```

### Error Handling via Cond

Clojure's `cond` provides clean conditional logic:

```clojure
(cond
  (<= t-up 0) 0.0
  (<= t-down 0) 0.0
  (zero? sin-theta) 0.0
  :else (calculate-velocity ...))
```

### Collection Operations

Clojure's rich collection library replaces C loops:

```clojure
;; Map over paths with index
(doseq [[idx path] (map-indexed vector paths)]
  (println (format "Path %d: %s" (inc idx) path)))

;; Build result using mapv (eager map to vector)
(mapv calculate-path-velocity paths measurements)
```

## Development

### Testing

To add tests, create `test/ultrasonic_flowmeter/core_test.clj`:

```clojure
(ns ultrasonic-flowmeter.core-test
  (:require [clojure.test :refer :all]
            [ultrasonic-flowmeter.core :as core]))

(deftest test-2path-config
  (let [config (core/create-2path-config 0.1)]
    (is (= (:pipe-diameter config) 0.1))
    (is (= (:num-paths config) 2))))

(deftest test-path-velocity-zero-time
  (let [path (core/acoustic-path 0 0.7854 0.1414 0.5)
        measurement (core/path-measurement 0 0.000067)]
    (is (= (core/calculate-path-velocity path measurement) 0.0))))
```

Run tests:
```bash
lein test
```

### REPL Development

The project is structured for interactive development:

```bash
lein repl
```

In the REPL:
```clojure
;; Load namespaces
(require '[ultrasonic-flowmeter.core :as core])
(require '[ultrasonic-flowmeter.main :as main])

;; Experiment with functions
(core/create-2path-config 0.1)

;; Test with different parameters
(main/simulate-measurements (core/create-4path-config 0.1) 3.5)
```

### Building

Create an executable JAR:

```bash
lein uberjar
```

Run it:
```bash
java -jar target/ultrasonic-flowmeter-0.1.0-SNAPSHOT-standalone.jar
```

## Comparison with C Implementation

| Aspect | C | Clojure |
|--------|---|---------|
| Data Structure | Struct | Map |
| Memory Management | Manual (malloc/free) | Automatic (GC) |
| Loops | for/while | mapv, doseq, reduce |
| Error Handling | Return codes | Exceptions, cond |
| Unit Tests | External framework | clojure.test |
| REPL | None | Interactive |
| Type Checking | Compiler | Dynamic |
| Parallelization | Manual threads | pmap, core.async |

## Further Learning

### Clojure Concepts

1. **Immutability & Persistent Data Structures**
   - All data structures are immutable
   - Efficient structural sharing under the hood

2. **Functional Composition**
   - Functions are first-class values
   - Easy to compose and create higher-order functions

3. **Lazy Evaluation**
   - `map`, `filter` are lazy
   - `mapv` is eager (used here for predictable ordering)

4. **REPL-Driven Development**
   - Interactive experimentation
   - Fast feedback loop

### Extensions

1. **Parallel Processing**
   ```clojure
   (pmap calculate-path-velocity paths measurements)
   ```

2. **Memoization**
   ```clojure
   (def cached-velocity (memoize calculate-path-velocity))
   ```

3. **Spec for Data Validation**
   ```clojure
   (require '[clojure.spec.alpha :as s])
   (s/def ::acoustic-path (s/keys :req-un [::position ::angle ::length ::weight]))
   ```

4. **Logging**
   ```clojure
   (require '[clojure.tools.logging :as log])
   (log/info "Calculated velocity: " velocity)
   ```

## References

- [Clojure Official Documentation](https://clojure.org/guides/getting_started)
- [ClojureDocs](https://clojuredocs.org/)
- [Leiningen](https://leiningen.org/)
- For physics background, see the C implementation README

## License

MIT License - See the root project license file.
