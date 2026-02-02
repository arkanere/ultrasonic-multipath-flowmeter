#include "flowmeter.h"
#include <math.h>
#include <stdlib.h>
#include <string.h>

/**
 * Calculate velocity from a single acoustic path measurement
 *
 * Uses the transit-time differential method:
 * v_path = (L / (2 * sin(θ))) * (Δt / (t_up * t_down))
 *
 * Where:
 * - L is the acoustic path length
 * - θ is the angle between the acoustic path and pipe axis
 * - Δt = t_up - t_down (time difference)
 * - t_up and t_down are the upstream and downstream transit times
 */
double calculate_path_velocity(const AcousticPath *path,
                               const PathMeasurement *measurement)
{
    if (!path || !measurement) {
        return 0.0;
    }

    double t_up = measurement->t_upstream;
    double t_down = measurement->t_downstream;

    /* Avoid division by zero */
    if (t_up <= 0 || t_down <= 0) {
        return 0.0;
    }

    double delta_t = t_up - t_down;
    double sin_theta = sin(path->angle);

    /* Avoid division by zero if angle is 0 */
    if (sin_theta == 0) {
        return 0.0;
    }

    /* Apply the transit-time differential formula */
    double velocity = (path->length / (2.0 * sin_theta)) *
                      (delta_t / (t_up * t_down));

    return velocity;
}

/**
 * Calculate total volumetric flow rate from multiple path measurements
 *
 * Uses Gauss-Jacobi quadrature integration with weighted sum:
 * Q = (π * D² / 4) * Σ(w_i * v_i)
 *
 * Where:
 * - D is the pipe diameter
 * - w_i is the weighting coefficient for path i
 * - v_i is the velocity for path i
 */
int calculate_flow_rate(const FlowMeterConfig *config,
                        const PathMeasurement *measurements,
                        FlowResult *result)
{
    if (!config || !measurements || !result) {
        return -1;
    }

    if (config->num_paths == 0 || !config->paths) {
        return -1;
    }

    /* Allocate memory for path velocities */
    result->path_velocities = malloc(config->num_paths * sizeof(double));
    if (!result->path_velocities) {
        return -1;
    }

    /* Calculate velocity for each path */
    double weighted_velocity_sum = 0.0;
    for (uint32_t i = 0; i < config->num_paths; i++) {
        result->path_velocities[i] =
            calculate_path_velocity(&config->paths[i], &measurements[i]);
        weighted_velocity_sum += config->paths[i].weight *
                                 result->path_velocities[i];
    }

    /* Calculate cross-sectional area: A = π * (D/2)² = π * D² / 4 */
    double radius = config->pipe_diameter / 2.0;
    double area = M_PI * radius * radius;

    /* Calculate volumetric flow rate */
    result->volumetric_flow = area * weighted_velocity_sum;

    return 0;
}

/**
 * Main processing function for flow meter
 */
FlowResult* flowmeter_process(const FlowMeterConfig *config,
                              const PathMeasurement *measurements)
{
    if (!config || !measurements) {
        return NULL;
    }

    FlowResult *result = malloc(sizeof(FlowResult));
    if (!result) {
        return NULL;
    }

    if (calculate_flow_rate(config, measurements, result) != 0) {
        free(result);
        return NULL;
    }

    return result;
}

/**
 * Free allocated memory for FlowResult
 */
void flowmeter_result_free(FlowResult *result)
{
    if (result) {
        if (result->path_velocities) {
            free(result->path_velocities);
        }
        free(result);
    }
}
