/**
 * Core algorithm for a transit-time differential ultrasonic flow meter.
 *
 * An ultrasonic signal sent across a pipe travels faster with the flow than
 * against it. Comparing the two transit times reveals the flow velocity
 * without needing to know the speed of sound in the fluid.
 *
 * The types carry the invariants the JavaScript version enforces at runtime
 * with `Object.freeze`: every field is `readonly`, so the compiler rejects a
 * mutation instead of the engine throwing on one.
 */

/** A single ultrasonic beam crossing the pipe. */
export interface AcousticPath {
  /** Position on the pipe diameter, normalized to -1..1. */
  readonly position: number;
  /** Angle from the pipe axis, in radians. */
  readonly angle: number;
  /** Acoustic path length in meters: the chord `D / sin(angle)`. */
  readonly length: number;
  /** Gauss-Jacobi weighting coefficient. */
  readonly weight: number;
}

/** Upstream and downstream transit times for one path, in seconds. */
export interface PathMeasurement {
  readonly tUpstream: number;
  readonly tDownstream: number;
  /** `tUpstream - tDownstream`: the difference the whole method rests on. */
  readonly deltaT: number;
}

/** A pipe bundled with the acoustic paths crossing it. */
export interface FlowMeterConfig {
  /** Pipe diameter, in meters. */
  readonly pipeDiameter: number;
  readonly paths: readonly AcousticPath[];
  readonly numPaths: number;
}

/** One solved measurement cycle. */
export interface FlowResult {
  /** Recovered axial velocity per path, in m/s. */
  readonly pathVelocities: readonly number[];
  /** Integrated flow rate, in m³/s. */
  readonly volumetricFlow: number;
}

/**
 * Build a single acoustic path crossing the pipe, deriving its length from the
 * chord `D / sin(theta)`.
 */
export function acousticPath(
  pipeDiameter: number,
  position: number,
  angle: number,
  weight: number,
): AcousticPath {
  return {
    position,
    angle,
    length: pipeDiameter / Math.sin(angle),
    weight,
  };
}

/**
 * Record a pair of transit times.
 *
 * `deltaT` is computed once at construction rather than on every read — the
 * fields are `readonly`, so it can never fall out of sync with the times it was
 * derived from.
 */
export function pathMeasurement(tUpstream: number, tDownstream: number): PathMeasurement {
  return {
    tUpstream,
    tDownstream,
    deltaT: tUpstream - tDownstream,
  };
}

/** Bundle a pipe with the acoustic paths crossing it. */
export function flowMeterConfig(
  pipeDiameter: number,
  paths: readonly AcousticPath[],
): FlowMeterConfig {
  return {
    pipeDiameter,
    paths: [...paths],
    numPaths: paths.length,
  };
}

/** Cross-sectional area of the pipe, `pi (D/2)^2`, in m². */
export function pipeArea(config: FlowMeterConfig): number {
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
export function calculatePathVelocity(
  path: AcousticPath,
  measurement: PathMeasurement,
): number {
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
 */
export function calculateFlowRate(
  config: FlowMeterConfig,
  measurements: readonly PathMeasurement[],
): FlowResult {
  if (config.paths.length === 0) {
    throw new Error('flow meter configuration has no paths');
  }
  if (measurements.length !== config.paths.length) {
    throw new Error('expected one measurement per acoustic path');
  }

  // Where JavaScript zips the two sequences with `map` and `reduce`, TypeScript
  // under `noUncheckedIndexedAccess` types `measurements[i]` as possibly
  // undefined. Walking both in one loop narrows it once and keeps the weighted
  // sum in step with the velocity it weights.
  const pathVelocities: number[] = [];
  let weightedVelocitySum = 0.0;

  for (const [i, path] of config.paths.entries()) {
    const measurement = measurements[i];
    if (measurement === undefined) {
      throw new Error('expected one measurement per acoustic path');
    }

    const velocity = calculatePathVelocity(path, measurement);
    pathVelocities.push(velocity);
    weightedVelocitySum += path.weight * velocity;
  }

  return {
    pathVelocities,
    volumetricFlow: pipeArea(config) * weightedVelocitySum,
  };
}

/** Two 45° paths at ±0.25 D: quick, cost-effective measurement. */
export function create2PathConfig(pipeDiameter: number): FlowMeterConfig {
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
export function create4PathConfig(pipeDiameter: number): FlowMeterConfig {
  const outerAngle = Math.PI / 3.0;
  const innerAngle = Math.PI / 4.0;
  return flowMeterConfig(pipeDiameter, [
    acousticPath(pipeDiameter, 0.35, outerAngle, 0.25),
    acousticPath(pipeDiameter, -0.35, outerAngle, 0.25),
    acousticPath(pipeDiameter, 0.15, innerAngle, 0.25),
    acousticPath(pipeDiameter, -0.15, innerAngle, 0.25),
  ]);
}

export const cubicMetersToLitersPerSecond = (m3PerS: number): number => m3PerS * 1000.0;

export const cubicMetersToLitersPerMinute = (m3PerS: number): number => m3PerS * 60000.0;
