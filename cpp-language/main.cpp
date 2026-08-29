#include "flowmeter.hpp"

#include <cmath>
#include <cstdio>
#include <exception>
#include <vector>

namespace {

using flowmeter::AcousticPath;
using flowmeter::FlowMeterConfig;
using flowmeter::FlowResult;
using flowmeter::PathMeasurement;

constexpr double kPi = 3.14159265358979323846;
constexpr double kSoundSpeed = 1480.0;  /* Sound speed in water at 20°C (m/s) */

double radians_to_degrees(double radians)
{
    return radians * 180.0 / kPi;
}

/**
 * Generate synthetic transit times for a known flow velocity.
 *
 * The acoustic path component along the flow direction is L * sin(θ), and the
 * signal effectively travels at (c - v) upstream and (c + v) downstream.
 */
std::vector<PathMeasurement> simulate_measurements(const FlowMeterConfig &config,
                                                   double true_flow_velocity)
{
    std::vector<PathMeasurement> measurements;
    measurements.reserve(config.paths.size());

    for (const AcousticPath &path : config.paths) {
        const double path_component = path.length * std::sin(path.angle);
        measurements.push_back(
            PathMeasurement{path_component / (kSoundSpeed - true_flow_velocity),
                            path_component / (kSoundSpeed + true_flow_velocity)});
    }

    return measurements;
}

void print_config(const FlowMeterConfig &config)
{
    std::printf("Flow Meter Configuration:\n");
    std::printf("  Pipe diameter: %.3f m\n", config.pipe_diameter);
    std::printf("  Number of paths: %zu\n", config.num_paths());
    std::printf("  Pipe area: %.6f m²\n", config.pipe_area());
    std::printf("\nAcoustic Paths:\n");

    for (std::size_t i = 0; i < config.paths.size(); ++i) {
        const AcousticPath &path = config.paths[i];
        std::printf("  Path %zu:\n", i + 1);
        std::printf("    Position: %.2f D\n", path.position);
        std::printf("    Angle: %.2f° (%.4f rad)\n", radians_to_degrees(path.angle),
                    path.angle);
        std::printf("    Path length: %.4f m\n", path.length);
        std::printf("    Weight: %.3f\n", path.weight);
    }
}

void print_measurements(const std::vector<PathMeasurement> &measurements,
                        double true_flow_velocity)
{
    std::printf("\nSimulated Measurements (True flow velocity: %.2f m/s):\n",
                true_flow_velocity);

    for (std::size_t i = 0; i < measurements.size(); ++i) {
        const PathMeasurement &m = measurements[i];
        std::printf(
            "  Path %zu: t_upstream = %.8f s, t_downstream = %.8f s, Δt = %.2e s\n",
            i + 1, m.t_upstream, m.t_downstream, m.delta_t());
    }
}

void print_results(const FlowResult &result)
{
    std::printf("\nFlow Calculation Results:\n");

    for (std::size_t i = 0; i < result.path_velocities.size(); ++i) {
        std::printf("  Path %zu velocity: %.4f m/s\n", i + 1,
                    result.path_velocities[i]);
    }

    std::printf("\nVolumetric Flow Rate:\n");
    std::printf("  %.6f m³/s\n", result.volumetric_flow);
    std::printf("  %.4f L/min\n",
                flowmeter::cubic_meters_to_liters_per_minute(result.volumetric_flow));
    std::printf("  %.2f L/s\n",
                flowmeter::cubic_meters_to_liters_per_second(result.volumetric_flow));
}

/* Run one configuration end to end: describe it, simulate it, solve it */
void run_demo(const char *title, const FlowMeterConfig &config,
              double true_flow_velocity)
{
    std::printf("### %s ###\n\n", title);

    print_config(config);

    const std::vector<PathMeasurement> measurements =
        simulate_measurements(config, true_flow_velocity);
    print_measurements(measurements, true_flow_velocity);

    print_results(flowmeter::calculate_flow_rate(config, measurements));
}

}  /* namespace */

int main()
{
    const double pipe_diameter = 0.1;       /* 100 mm */
    const double true_flow_velocity = 2.0;  /* 2 m/s */

    try {
        std::printf("=== Ultrasonic Multipath Flow Meter ===\n\n");

        run_demo("2-PATH CONFIGURATION",
                 flowmeter::create_2path_config(pipe_diameter), true_flow_velocity);

        std::printf("\n\n");

        run_demo("4-PATH CONFIGURATION",
                 flowmeter::create_4path_config(pipe_diameter), true_flow_velocity);

        std::printf("\n=== End of Demonstration ===\n");
    } catch (const std::exception &e) {
        std::fprintf(stderr, "Error: %s\n", e.what());
        return 1;
    }

    return 0;
}
