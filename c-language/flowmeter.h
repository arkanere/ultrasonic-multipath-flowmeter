#ifndef FLOWMETER_H
#define FLOWMETER_H

#include <stdint.h>

/* Structure to represent a single acoustic path */
typedef struct {
    double position;        /* Position on pipe diameter (normalized: -1 to 1) */
    double angle;          /* Angle from pipe axis in radians */
    double length;         /* Acoustic path length in meters */
    double weight;         /* Gauss-Jacobi weighting coefficient */
} AcousticPath;

/* Structure for flow meter configuration */
typedef struct {
    double pipe_diameter;  /* Pipe diameter in meters */
    uint32_t num_paths;    /* Number of acoustic paths (2 or 4) */
    AcousticPath *paths;   /* Array of acoustic path configurations */
} FlowMeterConfig;

/* Structure for a single path measurement */
typedef struct {
    double t_upstream;     /* Upstream transit time in seconds */
    double t_downstream;   /* Downstream transit time in seconds */
} PathMeasurement;

/* Structure for flow calculation results */
typedef struct {
    double *path_velocities;  /* Velocity calculated for each path (m/s) */
    double volumetric_flow;   /* Total volumetric flow rate (m³/s) */
} FlowResult;

/* Function declarations */

/**
 * Calculate velocity from a single acoustic path measurement
 *
 * @param path Configuration for the acoustic path
 * @param measurement Upstream and downstream transit times
 * @return Calculated velocity for this path (m/s)
 */
double calculate_path_velocity(const AcousticPath *path,
                               const PathMeasurement *measurement);

/**
 * Calculate total volumetric flow rate from multiple path measurements
 *
 * @param config Flow meter configuration
 * @param measurements Array of measurements (one per path)
 * @param result Output structure for flow calculation results
 * @return 0 on success, -1 on error
 */
int calculate_flow_rate(const FlowMeterConfig *config,
                        const PathMeasurement *measurements,
                        FlowResult *result);

/**
 * Main processing function for flow meter
 *
 * @param config Flow meter configuration
 * @param measurements Array of measurements
 * @return Pointer to FlowResult (must be freed by caller), NULL on error
 */
FlowResult* flowmeter_process(const FlowMeterConfig *config,
                              const PathMeasurement *measurements);

/**
 * Free allocated memory for FlowResult
 *
 * @param result Pointer to FlowResult to free
 */
void flowmeter_result_free(FlowResult *result);

#endif /* FLOWMETER_H */
