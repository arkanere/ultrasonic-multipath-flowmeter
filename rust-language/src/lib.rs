//! Transit-time differential ultrasonic multipath flow meter.
//!
//! An ultrasonic signal sent across a pipe travels faster with the flow than
//! against it. Comparing the two transit times reveals the flow velocity
//! without needing to know the speed of sound in the fluid.

use std::f64::consts::PI;

/// A single acoustic path crossing the pipe.
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct AcousticPath {
    /// Position on the pipe diameter, normalized to -1.0..=1.0.
    pub position: f64,
    /// Angle from the pipe axis, in radians.
    pub angle: f64,
    /// Acoustic path length, in meters.
    pub length: f64,
    /// Gauss-Jacobi weighting coefficient.
    pub weight: f64,
}

impl AcousticPath {
    /// Build a path across a pipe of the given diameter.
    ///
    /// The acoustic length is the chord `D / sin(θ)`.
    pub fn new(pipe_diameter: f64, position: f64, angle: f64, weight: f64) -> Self {
        Self {
            position,
            angle,
            length: pipe_diameter / angle.sin(),
            weight,
        }
    }

    /// Velocity along the pipe axis implied by one measurement, in m/s.
    ///
    /// ```text
    /// v_path = (L / (2 sin θ)) * (Δt / (t_up * t_down))
    /// ```
    ///
    /// Returns `0.0` for non-physical transit times or a degenerate angle.
    pub fn velocity(&self, measurement: &PathMeasurement) -> f64 {
        if measurement.t_upstream <= 0.0 || measurement.t_downstream <= 0.0 {
            return 0.0;
        }

        let sin_theta = self.angle.sin();

        // A path along the pipe axis carries no flow information.
        if sin_theta == 0.0 {
            return 0.0;
        }

        (self.length / (2.0 * sin_theta))
            * (measurement.delta_t() / (measurement.t_upstream * measurement.t_downstream))
    }
}

/// Upstream and downstream transit times for one path, in seconds.
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct PathMeasurement {
    pub t_upstream: f64,
    pub t_downstream: f64,
}

impl PathMeasurement {
    pub fn new(t_upstream: f64, t_downstream: f64) -> Self {
        Self {
            t_upstream,
            t_downstream,
        }
    }

    /// The transit-time difference the whole method rests on.
    pub fn delta_t(&self) -> f64 {
        self.t_upstream - self.t_downstream
    }
}

/// Per-path velocities plus the integrated volumetric flow rate.
#[derive(Debug, Clone, PartialEq)]
pub struct FlowResult {
    /// Velocity measured on each path, in m/s.
    pub path_velocities: Vec<f64>,
    /// Total volumetric flow rate, in m³/s.
    pub volumetric_flow: f64,
}

impl FlowResult {
    /// Volumetric flow rate in liters per second.
    pub fn liters_per_second(&self) -> f64 {
        self.volumetric_flow * 1000.0
    }

    /// Volumetric flow rate in liters per minute.
    pub fn liters_per_minute(&self) -> f64 {
        self.volumetric_flow * 60_000.0
    }
}

/// A pipe and the acoustic paths crossing it.
#[derive(Debug, Clone, PartialEq)]
pub struct FlowMeterConfig {
    /// Pipe diameter, in meters.
    pub pipe_diameter: f64,
    pub paths: Vec<AcousticPath>,
}

impl FlowMeterConfig {
    /// Two 45° paths at ±0.25 D: quick, cost-effective measurement.
    pub fn two_path(pipe_diameter: f64) -> Self {
        let angle = PI / 4.0;
        Self {
            pipe_diameter,
            paths: vec![
                AcousticPath::new(pipe_diameter, 0.25, angle, 0.5),
                AcousticPath::new(pipe_diameter, -0.25, angle, 0.5),
            ],
        }
    }

    /// Two 60° paths near the wall plus two 45° paths near the center.
    ///
    /// Sampling the velocity profile at four heights integrates it more
    /// accurately than a single pair of paths.
    pub fn four_path(pipe_diameter: f64) -> Self {
        let outer_angle = PI / 3.0;
        let inner_angle = PI / 4.0;
        Self {
            pipe_diameter,
            paths: vec![
                AcousticPath::new(pipe_diameter, 0.35, outer_angle, 0.25),
                AcousticPath::new(pipe_diameter, -0.35, outer_angle, 0.25),
                AcousticPath::new(pipe_diameter, 0.15, inner_angle, 0.25),
                AcousticPath::new(pipe_diameter, -0.15, inner_angle, 0.25),
            ],
        }
    }

    /// Cross-sectional area of the pipe, `π (D/2)²`, in m².
    pub fn pipe_area(&self) -> f64 {
        let radius = self.pipe_diameter / 2.0;
        PI * radius * radius
    }

    /// Integrate the per-path velocities into a volumetric flow rate.
    ///
    /// Gauss-Jacobi quadrature: `Q = (π D² / 4) * Σ(w_i v_i)`.
    ///
    /// # Panics
    ///
    /// Panics if the configuration has no paths, or if `measurements` does not
    /// hold exactly one entry per path.
    pub fn calculate_flow_rate(&self, measurements: &[PathMeasurement]) -> FlowResult {
        assert!(
            !self.paths.is_empty(),
            "flow meter configuration has no paths"
        );
        assert_eq!(
            measurements.len(),
            self.paths.len(),
            "expected one measurement per acoustic path"
        );

        let path_velocities: Vec<f64> = self
            .paths
            .iter()
            .zip(measurements)
            .map(|(path, measurement)| path.velocity(measurement))
            .collect();

        let weighted_velocity_sum: f64 = self
            .paths
            .iter()
            .zip(&path_velocities)
            .map(|(path, velocity)| path.weight * velocity)
            .sum();

        FlowResult {
            volumetric_flow: self.pipe_area() * weighted_velocity_sum,
            path_velocities,
        }
    }
}
