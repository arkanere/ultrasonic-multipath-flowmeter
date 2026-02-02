#include "flowmeter.h"
#include <stdio.h>
#include <stdlib.h>
#include <math.h>

/**
 * Initialize a 2-path flow meter configuration
 * Typical 45-degree diagonal paths for quick measurement
 */
FlowMeterConfig* create_2path_config(double pipe_diameter)
{
    FlowMeterConfig *config = malloc(sizeof(FlowMeterConfig));
    if (!config) return NULL;

    config->pipe_diameter = pipe_diameter;
    config->num_paths = 2;
    config->paths = malloc(2 * sizeof(AcousticPath));
    if (!config->paths) {
        free(config);
        return NULL;
    }

    /* Path 1: 45-degree angle from center, positive offset */
    config->paths[0].position = 0.25;
    config->paths[0].angle = M_PI / 4.0;  /* 45 degrees */
    config->paths[0].length = pipe_diameter / sin(M_PI / 4.0);
    config->paths[0].weight = 0.5;

    /* Path 2: 45-degree angle from center, negative offset (opposite side) */
    config->paths[1].position = -0.25;
    config->paths[1].angle = M_PI / 4.0;
    config->paths[1].length = pipe_diameter / sin(M_PI / 4.0);
    config->paths[1].weight = 0.5;

    return config;
}

/**
 * Initialize a 4-path flow meter configuration
 * Mix of 60-degree and 45-degree paths for improved accuracy
 */
FlowMeterConfig* create_4path_config(double pipe_diameter)
{
    FlowMeterConfig *config = malloc(sizeof(FlowMeterConfig));
    if (!config) return NULL;

    config->pipe_diameter = pipe_diameter;
    config->num_paths = 4;
    config->paths = malloc(4 * sizeof(AcousticPath));
    if (!config->paths) {
        free(config);
        return NULL;
    }

    /* Path 1: 60-degree angle, position 0.35D */
    config->paths[0].position = 0.35;
    config->paths[0].angle = M_PI / 3.0;  /* 60 degrees */
    config->paths[0].length = pipe_diameter / sin(M_PI / 3.0);
    config->paths[0].weight = 0.25;

    /* Path 2: 60-degree angle, position -0.35D (opposite side) */
    config->paths[1].position = -0.35;
    config->paths[1].angle = M_PI / 3.0;
    config->paths[1].length = pipe_diameter / sin(M_PI / 3.0);
    config->paths[1].weight = 0.25;

    /* Path 3: 45-degree angle, position 0.15D */
    config->paths[2].position = 0.15;
    config->paths[2].angle = M_PI / 4.0;  /* 45 degrees */
    config->paths[2].length = pipe_diameter / sin(M_PI / 4.0);
    config->paths[2].weight = 0.25;

    /* Path 4: 45-degree angle, position -0.15D (opposite side) */
    config->paths[3].position = -0.15;
    config->paths[3].angle = M_PI / 4.0;
    config->paths[3].length = pipe_diameter / sin(M_PI / 4.0);
    config->paths[3].weight = 0.25;

    return config;
}

/**
 * Free flow meter configuration
 */
void free_config(FlowMeterConfig *config)
{
    if (config) {
        if (config->paths) {
            free(config->paths);
        }
        free(config);
    }
}

/**
 * Print flow meter configuration details
 */
void print_config(const FlowMeterConfig *config)
{
    printf("Flow Meter Configuration:\n");
    printf("  Pipe diameter: %.3f m\n", config->pipe_diameter);
    printf("  Number of paths: %u\n", config->num_paths);
    printf("  Pipe area: %.6f m²\n",
           M_PI * (config->pipe_diameter / 2.0) * (config->pipe_diameter / 2.0));
    printf("\nAcoustic Paths:\n");

    for (uint32_t i = 0; i < config->num_paths; i++) {
        printf("  Path %u:\n", i + 1);
        printf("    Position: %.2f D\n", config->paths[i].position);
        printf("    Angle: %.2f° (%.4f rad)\n",
               config->paths[i].angle * 180.0 / M_PI, config->paths[i].angle);
        printf("    Path length: %.4f m\n", config->paths[i].length);
        printf("    Weight: %.3f\n", config->paths[i].weight);
    }
}

/**
 * Print flow calculation results
 */
void print_results(const FlowResult *result, const FlowMeterConfig *config)
{
    printf("\nFlow Calculation Results:\n");

    for (uint32_t i = 0; i < config->num_paths; i++) {
        printf("  Path %u velocity: %.4f m/s\n", i + 1, result->path_velocities[i]);
    }

    printf("\nVolumetric Flow Rate:\n");
    printf("  %.6f m³/s\n", result->volumetric_flow);
    printf("  %.4f L/min\n", result->volumetric_flow * 60000.0);
    printf("  %.2f L/s\n", result->volumetric_flow * 1000.0);
}

/**
 * Simulate measurement data for demonstration
 * Creates synthetic upstream/downstream transit times based on flow velocity
 */
void simulate_measurements(PathMeasurement *measurements,
                           const FlowMeterConfig *config,
                           double true_flow_velocity)
{
    for (uint32_t i = 0; i < config->num_paths; i++) {
        AcousticPath *path = &config->paths[i];

        /* Sound speed in water (approximation) */
        double sound_speed = 1480.0;  /* m/s */

        /* Acoustic path component along flow direction: L * sin(θ) */
        double path_component = path->length * sin(path->angle);

        /* Calculate time with and against flow */
        double v_acoustic_up = sound_speed - true_flow_velocity;
        double v_acoustic_down = sound_speed + true_flow_velocity;

        measurements[i].t_upstream = path_component / v_acoustic_up;
        measurements[i].t_downstream = path_component / v_acoustic_down;
    }
}

/**
 * Main demonstration program
 */
int main(void)
{
    printf("=== Ultrasonic Multipath Flow Meter ===\n\n");

    /* Pipe parameters */
    double pipe_diameter = 0.1;  /* 100 mm */
    double true_flow_velocity = 2.0;  /* 2 m/s */

    /* ========== 2-Path Configuration ========== */
    printf("### 2-PATH CONFIGURATION ###\n\n");

    FlowMeterConfig *config_2path = create_2path_config(pipe_diameter);
    if (!config_2path) {
        fprintf(stderr, "Error: Failed to create 2-path configuration\n");
        return 1;
    }

    print_config(config_2path);

    /* Generate simulated measurements */
    PathMeasurement *measurements_2path = malloc(2 * sizeof(PathMeasurement));
    if (!measurements_2path) {
        fprintf(stderr, "Error: Failed to allocate measurements\n");
        free_config(config_2path);
        return 1;
    }

    simulate_measurements(measurements_2path, config_2path, true_flow_velocity);

    printf("\nSimulated Measurements (True flow velocity: %.2f m/s):\n", true_flow_velocity);
    for (uint32_t i = 0; i < 2; i++) {
        double delta_t = measurements_2path[i].t_upstream -
                        measurements_2path[i].t_downstream;
        printf("  Path %u: t_upstream = %.8f s, t_downstream = %.8f s, Δt = %.2e s\n",
               i + 1,
               measurements_2path[i].t_upstream,
               measurements_2path[i].t_downstream,
               delta_t);
    }

    /* Calculate flow rate */
    FlowResult *result_2path = flowmeter_process(config_2path, measurements_2path);
    if (!result_2path) {
        fprintf(stderr, "Error: Failed to process flow measurements\n");
        free(measurements_2path);
        free_config(config_2path);
        return 1;
    }

    print_results(result_2path, config_2path);

    /* Cleanup 2-path */
    flowmeter_result_free(result_2path);
    free(measurements_2path);
    free_config(config_2path);

    /* ========== 4-Path Configuration ========== */
    printf("\n\n### 4-PATH CONFIGURATION ###\n\n");

    FlowMeterConfig *config_4path = create_4path_config(pipe_diameter);
    if (!config_4path) {
        fprintf(stderr, "Error: Failed to create 4-path configuration\n");
        return 1;
    }

    print_config(config_4path);

    /* Generate simulated measurements */
    PathMeasurement *measurements_4path = malloc(4 * sizeof(PathMeasurement));
    if (!measurements_4path) {
        fprintf(stderr, "Error: Failed to allocate measurements\n");
        free_config(config_4path);
        return 1;
    }

    simulate_measurements(measurements_4path, config_4path, true_flow_velocity);

    printf("\nSimulated Measurements (True flow velocity: %.2f m/s):\n", true_flow_velocity);
    for (uint32_t i = 0; i < 4; i++) {
        double delta_t = measurements_4path[i].t_upstream -
                        measurements_4path[i].t_downstream;
        printf("  Path %u: t_upstream = %.8f s, t_downstream = %.8f s, Δt = %.2e s\n",
               i + 1,
               measurements_4path[i].t_upstream,
               measurements_4path[i].t_downstream,
               delta_t);
    }

    /* Calculate flow rate */
    FlowResult *result_4path = flowmeter_process(config_4path, measurements_4path);
    if (!result_4path) {
        fprintf(stderr, "Error: Failed to process flow measurements\n");
        free(measurements_4path);
        free_config(config_4path);
        return 1;
    }

    print_results(result_4path, config_4path);

    /* Cleanup 4-path */
    flowmeter_result_free(result_4path);
    free(measurements_4path);
    free_config(config_4path);

    printf("\n=== End of Demonstration ===\n");

    return 0;
}
