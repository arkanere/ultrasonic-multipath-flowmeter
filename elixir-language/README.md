# Ultrasonic Multipath Flow Meter — Elixir

An Elixir implementation of a transit-time differential ultrasonic flow meter
for educational purposes. It computes the same physics as the [C
implementation](../c-language/), split into a pure `UltrasonicFlowmeter.Core`
module and an `UltrasonicFlowmeter.Main` module that holds the simulation, the
printing, and the entry point.

Its output is byte-for-byte identical to the C reference.

## Table of Contents

- [Overview](#overview)
- [Physics & Theory](#physics--theory)
- [Architecture](#architecture)
- [Running](#running)
- [Interactive Usage](#interactive-usage)
- [File Descriptions](#file-descriptions)
- [Example Output](#example-output)
- [Elixir Idioms Used](#elixir-idioms-used)
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

Four structs, each in its own nested module so the struct name reads as the type
name at every call site:

```elixir
defmodule UltrasonicFlowmeter.Core.AcousticPath do
  @enforce_keys [:position, :angle, :length, :weight]
  defstruct [:position, :angle, :length, :weight]
end

defmodule UltrasonicFlowmeter.Core.FlowMeterConfig do
  @enforce_keys [:pipe_diameter, :num_paths, :paths]
  defstruct [:pipe_diameter, :num_paths, :paths]
end

defmodule UltrasonicFlowmeter.Core.PathMeasurement do
  @enforce_keys [:t_upstream, :t_downstream]
  defstruct [:t_upstream, :t_downstream]
end

defmodule UltrasonicFlowmeter.Core.FlowResult do
  @enforce_keys [:path_velocities, :volumetric_flow]
  defstruct [:path_velocities, :volumetric_flow]
end
```

`@enforce_keys` on every struct means a half-built configuration fails at
construction rather than surfacing later as a `nil` in the arithmetic.

The API:

```elixir
# Construction
UltrasonicFlowmeter.acoustic_path(position, angle, length, weight)
UltrasonicFlowmeter.flow_meter_config(pipe_diameter, paths)
UltrasonicFlowmeter.path_measurement(t_upstream, t_downstream)
UltrasonicFlowmeter.flow_result(path_velocities, volumetric_flow)

# Solvers
UltrasonicFlowmeter.calculate_path_velocity(path, measurement)  # => float
UltrasonicFlowmeter.calculate_flow_rate(config, measurements)   # => %FlowResult{}

# Unit conversion
UltrasonicFlowmeter.to_liters_per_second(cubic_meters_per_second)
UltrasonicFlowmeter.to_liters_per_minute(cubic_meters_per_second)

# Demo-side (UltrasonicFlowmeter.Main)
create_2path_config(pipe_diameter)
create_4path_config(pipe_diameter)
simulate_measurements(config, true_flow_velocity)
```

`flow_meter_config/2` derives `num_paths` from the path list, so the count and
the list can never disagree. The two non-physical cases in
`calculate_path_velocity/2` are expressed as guard clauses — separate function
heads with `when t_up <= 0` and `when t_down <= 0` returning `0.0` — rather than
as `if` branches inside one body, which is what the C guards become when
translated into pattern matching. `calculate_flow_rate/2` raises
`ArgumentError` on an empty path list or a measurement-count mismatch, treating
those as caller bugs the way the C++ and Python versions do.

## Running

**Prerequisites:** Elixir 1.14+ and Erlang/OTP 25+. No external dependencies —
the maths comes from Erlang's built-in `:math` module.

```bash
mix run -e "UltrasonicFlowmeter.Main.main([])"   # Run the demo

mix escript.build && ./flowmeter                 # Or build a standalone binary

mix compile                                      # Compile only
iex -S mix                                       # Interactive shell
```

## Interactive Usage

The core module is usable on its own, which is the point of keeping it pure:

```elixir
$ iex -S mix

iex> alias UltrasonicFlowmeter, as: UF
iex> alias UltrasonicFlowmeter.Main

# Build a meter and simulate a 2 m/s flow
iex> config = Main.create_2path_config(0.1)
iex> measurements = Main.simulate_measurements(config, 2.0)

iex> result = UF.calculate_flow_rate(config, measurements)
%UltrasonicFlowmeter.Core.FlowResult{
  path_velocities: [4.000000000000001, 4.000000000000001],
  volumetric_flow: 0.031415926535897946
}

iex> UF.to_liters_per_minute(result.volumetric_flow)
1884.9555921538768

# A single path, solved directly
iex> path = UF.acoustic_path(0.25, :math.pi() / 4, 0.1414, 0.5)
iex> UF.calculate_path_velocity(path, UF.path_measurement(6.766e-5, 6.748e-5))

# The guard clauses in action
iex> UF.calculate_path_velocity(path, UF.path_measurement(0.0, 1.0))
0.0

# Try your own meter geometry
iex> wide = Main.create_4path_config(0.5)
iex> UF.calculate_flow_rate(wide, Main.simulate_measurements(wide, 2.0))
```

Recompile without leaving the shell with `recompile()`.

## File Descriptions

### `mix.exs`

Project `:ultrasonic_flowmeter`, version 1.0.0, no dependencies. Configures the
`escript` target so `mix escript.build` produces a standalone `flowmeter`
executable with `UltrasonicFlowmeter.Main` as its entry point.

### `lib/ultrasonic_flowmeter/core.ex`

The pure algorithm: the four nested struct modules, `calculate_path_velocity/2`,
`calculate_flow_rate/2`, the four constructor functions, and the two unit
converters. No `IO` call appears anywhere in this file.

### `lib/ultrasonic_flowmeter/main.ex`

The demo. Holds the configuration builders, the transit-time simulator (sound
speed 1480 m/s, water at 20°C), the formatting helpers, the printers, and
`main/1`. Following the C implementation, the configuration builders live here
rather than in the algorithm module.

### `lib/ultrasonic_flowmeter.ex`

A thin facade that `defdelegate`s the core's public functions up to the
top-level namespace — the same role `__init__.py` plays in the Python
implementation.

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
rather than `1.83e-7`: `:io_lib.format/2`'s `~e` emits a one-digit exponent, so
`format_scientific/1` in `main.ex` pads it to match C's `%.2e`.

Path velocity reads as 4.0 m/s for a true flow of 2.0 m/s because the demo's
`L = D / sin θ` leaves a `1 / sin²θ` factor in the recovered velocity — an
artifact of the simplified geometry, not a meter calibration. At 60° the same
factor gives 2.6667 m/s.

## Elixir Idioms Used

| Idiom | Where |
|-------|-------|
| Multiple function heads with guards | `calculate_path_velocity/2` returns `0.0` from dedicated heads `when t_up <= 0` |
| Pattern matching in the head | `def calculate_path_velocity(%AcousticPath{angle: angle, length: length}, measurement)` destructures on entry |
| `@enforce_keys` | Every struct rejects a partial construction |
| The pipe operator | `paths \|> Enum.zip(measurements) \|> Enum.map(...)` |
| `Enum.zip/2` + `Enum.sum/1` | The weighted sum, in place of an index loop |
| `Enum.with_index/2` | 1-based path numbering when printing, without a counter variable |
| `defdelegate` | The facade module re-exports the core without wrapper boilerplate |
| Typespecs | `@spec` on every public function, checkable with Dialyzer |
| Nested modules as types | `Core.AcousticPath` rather than a bare map with atom keys |

## Further Learning

### Concepts to Explore

- **Immutability** — `calculate_flow_rate/2` builds a new `%FlowResult{}`; nothing is mutated
- **Guards vs. `if`** — the two zero-checks become function heads, so the happy path has no branching
- **Structs are maps** — `%AcousticPath{}` is a map with a `__struct__` key, so `Map` functions still work
- **Erlang interop** — `:math.sin/1` and `:io_lib.format/2` are OTP functions called with no ceremony
- **Escripts** — how `mix escript.build` bundles BEAM bytecode into a single executable

### Suggested Modifications

1. Add a `test/ultrasonic_flowmeter_test.exs` with `assert_in_delta result.volumetric_flow, 0.031416, 1.0e-6`
2. Turn the doctest in `lib/ultrasonic_flowmeter.ex` into a running test with `doctest UltrasonicFlowmeter`
3. Return `{:ok, result} | {:error, reason}` instead of raising, and pattern match on it
4. Add measurement noise with `:rand.normal/2` and average over many samples
5. Wrap the meter in a `GenServer` that accumulates readings over time — the BEAM's actual home ground
6. Add 6-path and 8-path configurations with proper Gauss-Jacobi weights
7. Run `mix dialyzer` and see the `@spec` annotations checked

## License & Notes

MIT License — free to use and modify for educational purposes. See the
[top-level README](../README.md) for the cross-language comparison.


**Verified:** this implementation's output has been diffed against the C
reference binary and is byte-for-byte identical, via both `mix run` and the
built escript.
