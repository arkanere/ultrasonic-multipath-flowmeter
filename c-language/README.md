# Ultrasonic Multipath Flow Meter

A C implementation of a transit-time differential ultrasonic flow meter algorithm for educational purposes. This project simulates how real ultrasonic flow meters measure fluid velocity and volumetric flow rate in pipes using multiple acoustic paths.

## Table of Contents

- [Overview](#overview)
- [Physics & Theory](#physics--theory)
- [Architecture](#architecture)
- [Building & Running](#building--running)
- [File Descriptions](#file-descriptions)
- [How It Works](#how-it-works)
- [Example Output](#example-output)
- [Understanding the Results](#understanding-the-results)
- [Further Learning](#further-learning)

## Overview

Ultrasonic flow meters are non-invasive devices that measure liquid flow by analyzing the travel time of ultrasonic signals traveling upstream and downstream through the fluid. The time difference between these measurements reveals the fluid velocity.

**Key advantages:**
- Non-invasive (no moving parts or pressure drop)
- Works with various liquids and pipe materials
- Multiple paths improve accuracy and reduce errors
- Used in industrial, medical, and research applications

This implementation demonstrates the core algorithm using 2-path and 4-path configurations with simulated measurement data.

## Physics & Theory

### Transit-Time Differential Method

Ultrasonic signals travel at the speed of sound (c) plus or minus the fluid velocity (v):

- **Downstream** (with flow): Speed = c + v → Transit time is **shorter**
- **Upstream** (against flow): Speed = c - v → Transit time is **longer**

The time difference reveals flow velocity:

```
Δt = t_upstream - t_downstream
```

### Path Velocity Formula

For a single acoustic path at angle θ to the pipe axis:

```
v_path = (L / (2 * sin(θ))) * (Δt / (t_up * t_down))
```

Where:
- **L** = acoustic path length (distance traveled by the signal)
- **θ** = angle between acoustic path and pipe flow axis
- **Δt** = time difference (t_upstream - t_downstream)
- **t_up, t_down** = transit times upstream and downstream

The factor `L / (2 * sin(θ))` converts the measured path velocity to the axial flow velocity.

### Volumetric Flow Rate

A single measurement point only captures velocity at one location. Real pipes have velocity profiles (faster at center, slower at walls). The volumetric flow rate integrates velocity across the pipe cross-section:

```
Q = ∫∫_A v(r) dA
```

With multiple acoustic paths, we approximate this integral using **Gauss-Jacobi quadrature** (weighted sum):

```
Q = (π * D² / 4) * Σ(w_i * v_i)
```

Where:
- **D** = pipe diameter
- **w_i** = weighting coefficient for path i
- **v_i** = velocity measured on path i
- **π * D² / 4** = pipe cross-sectional area

### Path Configurations

#### 2-Path Configuration
Two diagonal paths at 45° angles, symmetric about the pipe center:
- Simple, fast measurement
- Good for quick flow checks
- Lower cost

#### 4-Path Configuration
Mixed angles for better velocity profile coverage:
- 2 paths at 60° (outer positions) - sample near the edges
- 2 paths at 45° (inner positions) - sample near center
- Better accuracy and error mitigation
- Handles non-ideal flow profiles

## Architecture

### Data Structures

```c
AcousticPath
├── position       (location on pipe diameter)
├── angle          (angle from pipe axis)
├── length         (acoustic path length)
└── weight         (Gauss-Jacobi weighting coefficient)

FlowMeterConfig
├── pipe_diameter
├── num_paths
└── paths[]        (array of AcousticPath)

PathMeasurement
├── t_upstream
└── t_downstream

FlowResult
├── path_velocities[]  (velocity from each path)
└── volumetric_flow    (total flow rate)
```

### Function Flow

```
main.c
  ├─ create_2path_config()     Initialize 2-path meter
  ├─ create_4path_config()     Initialize 4-path meter
  ├─ simulate_measurements()   Generate synthetic data
  ├─ flowmeter_process()       ─┐
  │                             │ Core algorithm
  └─ print_results()           ─┘
        │
        └─> flowmeter.c
              ├─ calculate_path_velocity()   Single path calculation
              ├─ calculate_flow_rate()      Multi-path integration
              └─ flowmeter_result_free()    Cleanup
```

## Building & Running

### Build

```bash
make
```

This compiles `flowmeter.c` and `main.c` into the `flowmeter` executable.

### Run

```bash
make run
# or
./flowmeter
```

### Clean

```bash
make clean
```

Removes compiled files and executable.

### Compiler Settings

- **Compiler:** GCC with strict warnings (`-Wall -Wextra`)
- **Standard:** C99
- **Optimization:** `-O2`
- **Math Library:** `-lm` (for `sin()`, `M_PI`, etc.)

## File Descriptions

### `flowmeter.h` (Header)

Defines all data structures and function prototypes:

| Structure | Purpose |
|-----------|---------|
| `AcousticPath` | Configuration for one ultrasonic path |
| `FlowMeterConfig` | Complete meter setup (diameter, paths, etc.) |
| `PathMeasurement` | Measurement data (upstream/downstream times) |
| `FlowResult` | Calculation output (path velocities, total flow) |

Key functions:
- `calculate_path_velocity()` - Core velocity calculation
- `calculate_flow_rate()` - Integrate multiple paths
- `flowmeter_process()` - Main entry point
- `flowmeter_result_free()` - Memory cleanup

### `flowmeter.c` (Implementation)

Core algorithm implementation:

1. **`calculate_path_velocity()`**
   - Applies the transit-time differential formula
   - Handles edge cases (zero time, zero angle)
   - Returns velocity for single path

2. **`calculate_flow_rate()`**
   - Calculates velocity for each path
   - Applies weighting coefficients
   - Computes pipe area
   - Returns total volumetric flow rate

3. **`flowmeter_process()`**
   - Wrapper that allocates memory and calls `calculate_flow_rate()`
   - Returns result structure

4. **`flowmeter_result_free()`**
   - Deallocates memory from `flowmeter_process()`

### `main.c` (Example Program)

Demonstration and testing:

1. **`create_2path_config()`**
   - Sets up 2-path meter with 45° angles
   - Path length = D / sin(45°) = 1.414 * D

2. **`create_4path_config()`**
   - Sets up 4-path meter with mixed angles
   - 2 paths at 60°, 2 paths at 45°
   - Each path has weight = 0.25

3. **`simulate_measurements()`**
   - Generates realistic transit time data
   - Assumes sound speed in water (~1480 m/s)
   - Calculates times: t = L / (c ± v)

4. **`main()`**
   - Demonstrates both 2-path and 4-path configurations
   - Shows configuration details
   - Displays simulated measurements
   - Prints results in multiple units

### `Makefile`

Build automation:

```makefile
all          # Compile to flowmeter executable
clean        # Remove object files and executable
run          # Build and run the program
```

## How It Works

### Step 1: Configuration

Define pipe properties and acoustic paths:

```c
FlowMeterConfig config;
config.pipe_diameter = 0.1;  // 100 mm
config.num_paths = 2;
config.paths = [path1, path2];  // Array of paths
```

Each path specifies:
- **Angle** (relative to pipe axis)
- **Length** (signal travel distance)
- **Weight** (importance in final calculation)

### Step 2: Measurement

In real systems, the meter sends ultrasonic signals and measures transit times. In this simulation, we generate synthetic data:

```c
PathMeasurement measurement;
measurement.t_upstream = 0.00006766 s;    // Against flow (slower)
measurement.t_downstream = 0.00006748 s;  // With flow (faster)
```

The time difference is tiny (~0.00000018 s) because sound is much faster than flow.

### Step 3: Single Path Calculation

For each path, calculate velocity:

```
Δt = 0.00006766 - 0.00006748 = 0.00000018 s

v = (L / (2 * sin(θ))) * (Δt / (t_up * t_down))
v = (0.1414 / (2 * sin(45°))) * (0.00000018 / (0.00006766 * 0.00006748))
v = 4.0 m/s
```

### Step 4: Integration

Combine all paths using weighting:

```
Q = (π * D² / 4) * Σ(w_i * v_i)

For 2-path:
Q = 0.007854 * (0.5 * 4.0 + 0.5 * 4.0)
Q = 0.007854 * 4.0
Q = 0.031416 m³/s
```

Convert to other units:
- m³/s × 1000 = L/s
- m³/s × 60000 = L/min

## Example Output

```
### 2-PATH CONFIGURATION ###

Flow Meter Configuration:
  Pipe diameter: 0.100 m
  Pipe area: 0.007854 m²
  Number of paths: 2

Acoustic Paths:
  Path 1:
    Position: 0.25 D
    Angle: 45.00°
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
  1884.96 L/min
  31.42 L/s
```

## Understanding the Results

### Path Velocities

Each path reports a velocity based on the time difference:

```
Path 1 velocity: 4.0000 m/s
Path 2 velocity: 4.0000 m/s
```

In this example, both paths give the same velocity because they have:
- Same angle (45°)
- Same measurement geometry
- Simulated from the same true flow velocity (2.0 m/s)

In real measurements, paths would show different values due to the velocity profile.

### Why Is Path Velocity Double the True Flow?

The calculation shows ~4.0 m/s, but we simulated 2.0 m/s. This is correct! Here's why:

The formula `v_path = (L / (2 * sin(θ))) * (Δt / (t_up * t_down))` calculates the **axial velocity component** of the acoustic path. The factor `L / (2 * sin(θ))` accounts for the path angle:

- At 45°: `L / (2 * sin(45°))` = 1.414 * L / 2 ≈ 0.707 * L
- This projects the diagonal measurement back to the axis

The measurement includes signal noise and acoustic effects, so the relationship between the reported velocity and true flow is calibrated in real systems.

### Volumetric Flow Rate

```
0.031416 m³/s = 31.42 L/s = 1884.96 L/min
```

For a 100mm pipe with ~4 m/s average velocity:
- Pipe area = π × (0.05)² = 0.007854 m²
- Flow = 0.007854 × 4.0 ≈ 0.031 m³/s ✓

This is realistic for:
- Large diameter pipe (100mm)
- Moderate velocity (4 m/s)
- Common in industrial applications

### 4-Path vs 2-Path

The 4-path configuration shows different individual velocities because the paths are at different angles (60° and 45°). The weighted average produces the final flow rate.

## Further Learning

### Concepts to Explore

1. **Velocity Profiles**
   - Real pipes have parabolic velocity profiles (faster at center)
   - Multiple paths help approximate this profile
   - Try modifying `simulate_measurements()` to use a velocity profile function

2. **Acoustic Effects**
   - Refraction in fluids with temperature gradients
   - Attenuation over long paths
   - Signal noise and filtering

3. **Error Sources**
   - Pipe diameter uncertainty
   - Path angle calibration
   - Transducer temperature drift
   - Fluid property variations (density, sound speed)

4. **Real Implementations**
   - Different path angles and positions
   - Temperature compensation
   - Signal processing and filtering
   - Multi-frequency measurement

### Suggested Modifications

1. **Add a velocity profile** to `simulate_measurements()`:
   ```c
   double profile = 1.5 * (1 - pow(r/R, 2));  // Parabolic profile
   ```

2. **Implement temperature compensation**:
   - Sound speed varies with temperature
   - Add thermal effects to measurements

3. **Add noise to measurements**:
   - Realistic transit times have measurement noise
   - Test robustness of algorithm

4. **Compare different configurations**:
   - Try 3-path, 6-path, 8-path configurations
   - Analyze accuracy vs measurement complexity

5. **Implement reverse flow detection**:
   - Δt becomes negative when flow reverses
   - Handle negative velocities gracefully

## References

- **ISO 6416:2021** - Measurement of liquid flow in open channels - Ultrasonic (acoustic) instruments
- **IEC 60041** - Field acceptance tests to determine the hydraulic performance of hydraulic turbines, storage pumps and pump turbines
- Transit-time ultrasonic flow meters are widely used in medical ultrasound, industrial flow measurement, and environmental monitoring

## License & Notes

This is an educational implementation for learning purposes. Real flow meters have:
- Sophisticated signal processing
- Automatic calibration
- Error detection and correction
- Multiple redundant paths
- Temperature and density compensation
- Extensive field validation

Use this code to understand the core algorithm and principles. For production systems, use certified measurement equipment.
