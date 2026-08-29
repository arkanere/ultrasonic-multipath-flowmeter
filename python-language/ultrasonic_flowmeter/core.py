"""Core algorithm for a transit-time differential ultrasonic flow meter.

An ultrasonic signal sent across a pipe travels faster with the flow than
against it.  Comparing the two transit times reveals the flow velocity without
needing to know the speed of sound in the fluid.
"""

from __future__ import annotations

import math
from collections.abc import Sequence
from dataclasses import dataclass


@dataclass(frozen=True)
class AcousticPath:
    """A single acoustic path crossing the pipe."""

    position: float  # Position on the pipe diameter, normalized to -1.0..1.0
    angle: float  # Angle from the pipe axis, in radians
    length: float  # Acoustic path length, in meters
    weight: float  # Gauss-Jacobi weighting coefficient

    @classmethod
    def across(
        cls, pipe_diameter: float, position: float, angle: float, weight: float
    ) -> AcousticPath:
        """Build a path across a pipe; its length is the chord ``D / sin(theta)``."""
        return cls(position, angle, pipe_diameter / math.sin(angle), weight)


@dataclass(frozen=True)
class PathMeasurement:
    """Upstream and downstream transit times for one path, in seconds."""

    t_upstream: float
    t_downstream: float

    @property
    def delta_t(self) -> float:
        """The transit-time difference the whole method rests on."""
        return self.t_upstream - self.t_downstream


@dataclass(frozen=True)
class FlowMeterConfig:
    """A pipe and the acoustic paths crossing it."""

    pipe_diameter: float  # Pipe diameter, in meters
    paths: tuple[AcousticPath, ...]

    @property
    def num_paths(self) -> int:
        return len(self.paths)

    @property
    def pipe_area(self) -> float:
        """Cross-sectional area of the pipe, ``pi (D/2)**2``, in m²."""
        radius = self.pipe_diameter / 2.0
        return math.pi * radius * radius


@dataclass(frozen=True)
class FlowResult:
    """Per-path velocities plus the integrated volumetric flow rate."""

    path_velocities: tuple[float, ...]  # Velocity per path, in m/s
    volumetric_flow: float  # Total volumetric flow rate, in m³/s


def calculate_path_velocity(path: AcousticPath, measurement: PathMeasurement) -> float:
    """Velocity along the pipe axis implied by one path measurement, in m/s.

    Transit-time differential method::

        v_path = (L / (2 sin(theta))) * (delta_t / (t_up * t_down))

    Returns 0.0 for non-physical transit times or a degenerate path angle.
    """
    if measurement.t_upstream <= 0 or measurement.t_downstream <= 0:
        return 0.0

    sin_theta = math.sin(path.angle)

    # A path along the pipe axis carries no flow information.
    if sin_theta == 0:
        return 0.0

    return (path.length / (2.0 * sin_theta)) * (
        measurement.delta_t / (measurement.t_upstream * measurement.t_downstream)
    )


def calculate_flow_rate(
    config: FlowMeterConfig, measurements: Sequence[PathMeasurement]
) -> FlowResult:
    """Integrate the per-path velocities into a volumetric flow rate.

    Gauss-Jacobi quadrature::

        Q = (pi * D**2 / 4) * sum(w_i * v_i)
    """
    if not config.paths:
        raise ValueError("flow meter configuration has no paths")
    if len(measurements) != len(config.paths):
        raise ValueError("expected one measurement per acoustic path")

    velocities = tuple(
        calculate_path_velocity(path, measurement)
        for path, measurement in zip(config.paths, measurements)
    )
    weighted_velocity_sum = sum(
        path.weight * velocity for path, velocity in zip(config.paths, velocities)
    )

    return FlowResult(velocities, config.pipe_area * weighted_velocity_sum)


def create_2path_config(pipe_diameter: float) -> FlowMeterConfig:
    """Two 45° paths at ±0.25 D: quick, cost-effective measurement."""
    angle = math.pi / 4.0
    return FlowMeterConfig(
        pipe_diameter,
        (
            AcousticPath.across(pipe_diameter, 0.25, angle, 0.5),
            AcousticPath.across(pipe_diameter, -0.25, angle, 0.5),
        ),
    )


def create_4path_config(pipe_diameter: float) -> FlowMeterConfig:
    """Two 60° paths near the wall plus two 45° paths near the center.

    Sampling the velocity profile at four heights integrates it more accurately
    than a single pair of paths.
    """
    outer_angle = math.pi / 3.0
    inner_angle = math.pi / 4.0
    return FlowMeterConfig(
        pipe_diameter,
        (
            AcousticPath.across(pipe_diameter, 0.35, outer_angle, 0.25),
            AcousticPath.across(pipe_diameter, -0.35, outer_angle, 0.25),
            AcousticPath.across(pipe_diameter, 0.15, inner_angle, 0.25),
            AcousticPath.across(pipe_diameter, -0.15, inner_angle, 0.25),
        ),
    )


def cubic_meters_to_liters_per_second(m3_per_s: float) -> float:
    return m3_per_s * 1000.0


def cubic_meters_to_liters_per_minute(m3_per_s: float) -> float:
    return m3_per_s * 60000.0
