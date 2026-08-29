"""Demonstration of the ultrasonic multipath flow meter.

Synthesizes transit times for a known flow velocity, then runs them back
through the solver to recover the volumetric flow rate.
"""

from __future__ import annotations

import math
from collections.abc import Sequence

from ultrasonic_flowmeter.core import (
    FlowMeterConfig,
    FlowResult,
    PathMeasurement,
    calculate_flow_rate,
    create_2path_config,
    create_4path_config,
    cubic_meters_to_liters_per_minute,
    cubic_meters_to_liters_per_second,
)

SOUND_SPEED = 1480.0  # Speed of sound in water at 20°C, in m/s


def simulate_measurements(
    config: FlowMeterConfig, true_flow_velocity: float
) -> tuple[PathMeasurement, ...]:
    """Generate synthetic transit times for a known flow velocity.

    The acoustic path component along the flow direction is ``L sin(theta)``,
    and the signal effectively travels at ``c - v`` upstream and ``c + v``
    downstream.
    """
    measurements = []
    for path in config.paths:
        path_component = path.length * math.sin(path.angle)
        measurements.append(
            PathMeasurement(
                path_component / (SOUND_SPEED - true_flow_velocity),
                path_component / (SOUND_SPEED + true_flow_velocity),
            )
        )
    return tuple(measurements)


def print_config(config: FlowMeterConfig) -> None:
    print("Flow Meter Configuration:")
    print(f"  Pipe diameter: {config.pipe_diameter:.3f} m")
    print(f"  Number of paths: {config.num_paths}")
    print(f"  Pipe area: {config.pipe_area:.6f} m²")
    print("\nAcoustic Paths:")

    for i, path in enumerate(config.paths, start=1):
        print(f"  Path {i}:")
        print(f"    Position: {path.position:.2f} D")
        print(f"    Angle: {math.degrees(path.angle):.2f}° ({path.angle:.4f} rad)")
        print(f"    Path length: {path.length:.4f} m")
        print(f"    Weight: {path.weight:.3f}")


def print_measurements(
    measurements: Sequence[PathMeasurement], true_flow_velocity: float
) -> None:
    print(
        f"\nSimulated Measurements (True flow velocity: {true_flow_velocity:.2f} m/s):"
    )

    for i, m in enumerate(measurements, start=1):
        print(
            f"  Path {i}: t_upstream = {m.t_upstream:.8f} s, "
            f"t_downstream = {m.t_downstream:.8f} s, Δt = {m.delta_t:.2e} s"
        )


def print_results(result: FlowResult) -> None:
    print("\nFlow Calculation Results:")

    for i, velocity in enumerate(result.path_velocities, start=1):
        print(f"  Path {i} velocity: {velocity:.4f} m/s")

    print("\nVolumetric Flow Rate:")
    print(f"  {result.volumetric_flow:.6f} m³/s")
    print(f"  {cubic_meters_to_liters_per_minute(result.volumetric_flow):.4f} L/min")
    print(f"  {cubic_meters_to_liters_per_second(result.volumetric_flow):.2f} L/s")


def run_demo(title: str, config: FlowMeterConfig, true_flow_velocity: float) -> None:
    """Run one configuration end to end: describe it, simulate it, solve it."""
    print(f"### {title} ###\n")

    print_config(config)

    measurements = simulate_measurements(config, true_flow_velocity)
    print_measurements(measurements, true_flow_velocity)

    print_results(calculate_flow_rate(config, measurements))


def main() -> None:
    pipe_diameter = 0.1  # 100 mm
    true_flow_velocity = 2.0  # 2 m/s

    print("=== Ultrasonic Multipath Flow Meter ===\n")

    run_demo(
        "2-PATH CONFIGURATION", create_2path_config(pipe_diameter), true_flow_velocity
    )

    print("\n")

    run_demo(
        "4-PATH CONFIGURATION", create_4path_config(pipe_diameter), true_flow_velocity
    )

    print("\n=== End of Demonstration ===")
