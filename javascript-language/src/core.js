/**
 * Core algorithm for a transit-time differential ultrasonic flow meter.
 *
 * An ultrasonic signal sent across a pipe travels faster with the flow than
 * against it. Comparing the two transit times reveals the flow velocity
 * without needing to know the speed of sound in the fluid.
 */

/**
 * Build a single acoustic path crossing the pipe.
 *
 * @param {number} pipeDiameter Pipe diameter, in meters.
 * @param {number} position Position on the pipe diameter, normalized to -1..1.
 * @param {number} angle Angle from the pipe axis, in radians.
 * @param {number} weight Gauss-Jacobi weighting coefficient.
 * @returns {{position: number, angle: number, length: number, weight: number}}
 *   The path, whose length is the chord `D / sin(theta)`.
 */
export function acousticPath(pipeDiameter, position, angle, weight) {
  return Object.freeze({
    position,
    angle,
    length: pipeDiameter / Math.sin(angle),
    weight,
  });
}

/**
 * Bundle a pipe with the acoustic paths crossing it.
 *
 * @param {number} pipeDiameter Pipe diameter, in meters.
 * @param {ReadonlyArray<object>} paths One entry per acoustic path.
 */
export function flowMeterConfig(pipeDiameter, paths) {
  return Object.freeze({
    pipeDiameter,
    paths: Object.freeze([...paths]),
    numPaths: paths.length,
  });
}

/**
 * Upstream and downstream transit times for one path, in seconds.
 *
 * `deltaT` is the difference the whole method rests on.
 */
export function pathMeasurement(tUpstream, tDownstream) {
  return Object.freeze({
    tUpstream,
    tDownstream,
    deltaT: tUpstream - tDownstream,
  });
}

/** Cross-sectional area of the pipe, `pi (D/2)^2`, in m². */
export function pipeArea(config) {
  const radius = config.pipeDiameter / 2.0;
  return Math.PI * radius * radius;
}

/**
 * Velocity along the pipe axis implied by one path measurement, in m/s.
 *
 * Transit-time differential method:
 *
 *     v_path = (L / (2 sin(theta))) * (deltaT / (t_up * t_down))
 *
 * Returns 0 for non-physical transit times or a degenerate path angle.
 */
export function calculatePathVelocity(path, measurement) {
  if (measurement.tUpstream <= 0 || measurement.tDownstream <= 0) {
    return 0.0;
  }

  const sinTheta = Math.sin(path.angle);

  // A path along the pipe axis carries no flow information.
  if (sinTheta === 0) {
    return 0.0;
  }

  return (
    (path.length / (2.0 * sinTheta)) *
    (measurement.deltaT / (measurement.tUpstream * measurement.tDownstream))
  );
}

/**
 * Integrate the per-path velocities into a volumetric flow rate.
 *
 * Gauss-Jacobi quadrature: `Q = (pi D^2 / 4) * sum(w_i v_i)`.
 *
 * @returns {{pathVelocities: number[], volumetricFlow: number}}
 */
export function calculateFlowRate(config, measurements) {
  if (config.paths.length === 0) {
    throw new Error('flow meter configuration has no paths');
  }
  if (measurements.length !== config.paths.length) {
    throw new Error('expected one measurement per acoustic path');
  }

  const pathVelocities = config.paths.map((path, i) =>
    calculatePathVelocity(path, measurements[i]),
  );
  const weightedVelocitySum = config.paths.reduce(
    (sum, path, i) => sum + path.weight * pathVelocities[i],
    0.0,
  );

  return Object.freeze({
    pathVelocities,
    volumetricFlow: pipeArea(config) * weightedVelocitySum,
  });
}

/** Two 45° paths at ±0.25 D: quick, cost-effective measurement. */
export function create2PathConfig(pipeDiameter) {
  const angle = Math.PI / 4.0;
  return flowMeterConfig(pipeDiameter, [
    acousticPath(pipeDiameter, 0.25, angle, 0.5),
    acousticPath(pipeDiameter, -0.25, angle, 0.5),
  ]);
}

/**
 * Two 60° paths near the wall plus two 45° paths near the center.
 *
 * Sampling the velocity profile at four heights integrates it more accurately
 * than a single pair of paths.
 */
export function create4PathConfig(pipeDiameter) {
  const outerAngle = Math.PI / 3.0;
  const innerAngle = Math.PI / 4.0;
  return flowMeterConfig(pipeDiameter, [
    acousticPath(pipeDiameter, 0.35, outerAngle, 0.25),
    acousticPath(pipeDiameter, -0.35, outerAngle, 0.25),
    acousticPath(pipeDiameter, 0.15, innerAngle, 0.25),
    acousticPath(pipeDiameter, -0.15, innerAngle, 0.25),
  ]);
}

export const cubicMetersToLitersPerSecond = (m3PerS) => m3PerS * 1000.0;

export const cubicMetersToLitersPerMinute = (m3PerS) => m3PerS * 60000.0;
