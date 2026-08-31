/**
 * Demonstration of the ultrasonic multipath flow meter.
 *
 * Synthesizes transit times for a known flow velocity, then runs them back
 * through the solver to recover the volumetric flow rate.
 */

import {
  calculateFlowRate,
  create2PathConfig,
  create4PathConfig,
  cubicMetersToLitersPerMinute,
  cubicMetersToLitersPerSecond,
  pathMeasurement,
  pipeArea,
} from './core.js';
import type { FlowMeterConfig, FlowResult, PathMeasurement } from './core.js';

/** Speed of sound in water at 20°C, in m/s. */
const SOUND_SPEED = 1480.0;

const radiansToDegrees = (radians: number): number => (radians * 180.0) / Math.PI;

/**
 * Generate synthetic transit times for a known flow velocity.
 *
 * The acoustic path component along the flow direction is `L sin(theta)`, and
 * the signal effectively travels at `c - v` upstream and `c + v` downstream.
 */
function simulateMeasurements(
  config: FlowMeterConfig,
  trueFlowVelocity: number,
): PathMeasurement[] {
  return config.paths.map((path) => {
    const pathComponent = path.length * Math.sin(path.angle);
    return pathMeasurement(
      pathComponent / (SOUND_SPEED - trueFlowVelocity),
      pathComponent / (SOUND_SPEED + trueFlowVelocity),
    );
  });
}

function printConfig(config: FlowMeterConfig): void {
  console.log('Flow Meter Configuration:');
  console.log(`  Pipe diameter: ${config.pipeDiameter.toFixed(3)} m`);
  console.log(`  Number of paths: ${config.numPaths}`);
  console.log(`  Pipe area: ${pipeArea(config).toFixed(6)} m²`);
  console.log('\nAcoustic Paths:');

  config.paths.forEach((path, i) => {
    console.log(`  Path ${i + 1}:`);
    console.log(`    Position: ${path.position.toFixed(2)} D`);
    console.log(
      `    Angle: ${radiansToDegrees(path.angle).toFixed(2)}° ` +
        `(${path.angle.toFixed(4)} rad)`,
    );
    console.log(`    Path length: ${path.length.toFixed(4)} m`);
    console.log(`    Weight: ${path.weight.toFixed(3)}`);
  });
}

function printMeasurements(
  measurements: readonly PathMeasurement[],
  trueFlowVelocity: number,
): void {
  console.log(
    `\nSimulated Measurements (True flow velocity: ` +
      `${trueFlowVelocity.toFixed(2)} m/s):`,
  );

  measurements.forEach((m, i) => {
    console.log(
      `  Path ${i + 1}: t_upstream = ${m.tUpstream.toFixed(8)} s, ` +
        `t_downstream = ${m.tDownstream.toFixed(8)} s, ` +
        `Δt = ${m.deltaT.toExponential(2)} s`,
    );
  });
}

function printResults(result: FlowResult): void {
  console.log('\nFlow Calculation Results:');

  result.pathVelocities.forEach((velocity, i) => {
    console.log(`  Path ${i + 1} velocity: ${velocity.toFixed(4)} m/s`);
  });

  console.log('\nVolumetric Flow Rate:');
  console.log(`  ${result.volumetricFlow.toFixed(6)} m³/s`);
  console.log(
    `  ${cubicMetersToLitersPerMinute(result.volumetricFlow).toFixed(4)} L/min`,
  );
  console.log(
    `  ${cubicMetersToLitersPerSecond(result.volumetricFlow).toFixed(2)} L/s`,
  );
}

/** Run one configuration end to end: describe it, simulate it, solve it. */
function runDemo(title: string, config: FlowMeterConfig, trueFlowVelocity: number): void {
  console.log(`### ${title} ###\n`);

  printConfig(config);

  const measurements = simulateMeasurements(config, trueFlowVelocity);
  printMeasurements(measurements, trueFlowVelocity);

  printResults(calculateFlowRate(config, measurements));
}

function main(): void {
  const pipeDiameter = 0.1; // 100 mm
  const trueFlowVelocity = 2.0; // 2 m/s

  console.log('=== Ultrasonic Multipath Flow Meter ===\n');

  runDemo('2-PATH CONFIGURATION', create2PathConfig(pipeDiameter), trueFlowVelocity);

  console.log('\n');

  runDemo('4-PATH CONFIGURATION', create4PathConfig(pipeDiameter), trueFlowVelocity);

  console.log('\n=== End of Demonstration ===');
}

main();
