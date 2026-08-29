#ifndef FLOWMETER_HPP
#define FLOWMETER_HPP

#include <vector>

namespace flowmeter {

/* A single acoustic path across the pipe */
struct AcousticPath {
    double position;  /* Position on pipe diameter (normalized: -1 to 1) */
    double angle;     /* Angle from pipe axis in radians */
    double length;    /* Acoustic path length in meters */
    double weight;    /* Gauss-Jacobi weighting coefficient */
};

/* Flow meter configuration: a pipe plus the paths crossing it */
struct FlowMeterConfig {
    double pipe_diameter;             /* Pipe diameter in meters */
    std::vector<AcousticPath> paths;  /* One entry per acoustic path */

    std::size_t num_paths() const { return paths.size(); }
    double pipe_area() const;
};

/* Upstream and downstream transit times for one path */
struct PathMeasurement {
    double t_upstream;    /* Upstream transit time in seconds */
    double t_downstream;  /* Downstream transit time in seconds */

    double delta_t() const { return t_upstream - t_downstream; }
};

/* Result of a flow calculation */
struct FlowResult {
    std::vector<double> path_velocities;  /* Velocity per path (m/s) */
    double volumetric_flow;               /* Total volumetric flow (m³/s) */
};

/**
 * Calculate velocity from a single acoustic path measurement.
 *
 * Transit-time differential method:
 *   v_path = (L / (2 * sin(θ))) * (Δt / (t_up * t_down))
 *
 * Returns 0.0 for non-physical measurements (zero/negative transit times)
 * or a degenerate path angle.
 */
double calculate_path_velocity(const AcousticPath &path,
                               const PathMeasurement &measurement);

/**
 * Calculate the total volumetric flow rate from per-path measurements.
 *
 * Gauss-Jacobi quadrature integration:
 *   Q = (π * D² / 4) * Σ(w_i * v_i)
 *
 * `measurements` must hold one entry per configured path.
 */
FlowResult calculate_flow_rate(const FlowMeterConfig &config,
                               const std::vector<PathMeasurement> &measurements);

/* Two 45° paths at ±0.25 D - quick, cost-effective measurement */
FlowMeterConfig create_2path_config(double pipe_diameter);

/* Two 60° paths at ±0.35 D plus two 45° paths at ±0.15 D - higher accuracy */
FlowMeterConfig create_4path_config(double pipe_diameter);

/* Unit conversions */
double cubic_meters_to_liters_per_second(double m3_per_s);
double cubic_meters_to_liters_per_minute(double m3_per_s);

}  /* namespace flowmeter */

#endif /* FLOWMETER_HPP */
