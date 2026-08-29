#include "flowmeter.hpp"

#include <cmath>
#include <numeric>
#include <stdexcept>

namespace flowmeter {

namespace {

constexpr double kPi = 3.14159265358979323846;

/* Build one path; the acoustic length is the chord D / sin(θ) */
AcousticPath make_path(double pipe_diameter, double position, double angle,
                       double weight)
{
    return AcousticPath{position, angle, pipe_diameter / std::sin(angle), weight};
}

}  /* namespace */

double FlowMeterConfig::pipe_area() const
{
    const double radius = pipe_diameter / 2.0;
    return kPi * radius * radius;
}

double calculate_path_velocity(const AcousticPath &path,
                               const PathMeasurement &measurement)
{
    /* Avoid division by zero on non-physical transit times */
    if (measurement.t_upstream <= 0.0 || measurement.t_downstream <= 0.0) {
        return 0.0;
    }

    const double sin_theta = std::sin(path.angle);

    /* A path along the pipe axis carries no flow information */
    if (sin_theta == 0.0) {
        return 0.0;
    }

    return (path.length / (2.0 * sin_theta)) *
           (measurement.delta_t() /
            (measurement.t_upstream * measurement.t_downstream));
}

FlowResult calculate_flow_rate(const FlowMeterConfig &config,
                               const std::vector<PathMeasurement> &measurements)
{
    if (config.paths.empty()) {
        throw std::invalid_argument("flow meter configuration has no paths");
    }
    if (measurements.size() != config.paths.size()) {
        throw std::invalid_argument("expected one measurement per acoustic path");
    }

    FlowResult result;
    result.path_velocities.reserve(config.paths.size());

    double weighted_velocity_sum = 0.0;
    for (std::size_t i = 0; i < config.paths.size(); ++i) {
        const double velocity =
            calculate_path_velocity(config.paths[i], measurements[i]);
        result.path_velocities.push_back(velocity);
        weighted_velocity_sum += config.paths[i].weight * velocity;
    }

    result.volumetric_flow = config.pipe_area() * weighted_velocity_sum;
    return result;
}

FlowMeterConfig create_2path_config(double pipe_diameter)
{
    const double angle = kPi / 4.0;  /* 45 degrees */
    return FlowMeterConfig{
        pipe_diameter,
        {
            make_path(pipe_diameter, 0.25, angle, 0.5),
            make_path(pipe_diameter, -0.25, angle, 0.5),
        }};
}

FlowMeterConfig create_4path_config(double pipe_diameter)
{
    const double outer_angle = kPi / 3.0;  /* 60 degrees, near the pipe wall */
    const double inner_angle = kPi / 4.0;  /* 45 degrees, near the center */
    return FlowMeterConfig{
        pipe_diameter,
        {
            make_path(pipe_diameter, 0.35, outer_angle, 0.25),
            make_path(pipe_diameter, -0.35, outer_angle, 0.25),
            make_path(pipe_diameter, 0.15, inner_angle, 0.25),
            make_path(pipe_diameter, -0.15, inner_angle, 0.25),
        }};
}

double cubic_meters_to_liters_per_second(double m3_per_s)
{
    return m3_per_s * 1000.0;
}

double cubic_meters_to_liters_per_minute(double m3_per_s)
{
    return m3_per_s * 60000.0;
}

}  /* namespace flowmeter */
