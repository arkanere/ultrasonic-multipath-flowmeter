//! Demonstration of the ultrasonic multipath flow meter.
//!
//! Synthesizes transit times for a known flow velocity, then runs them back
//! through the solver to recover the volumetric flow rate.

use std::f64::consts::PI;

use ultrasonic_flowmeter::{FlowMeterConfig, FlowResult, PathMeasurement};

/// Speed of sound in water at 20°C, in m/s.
const SOUND_SPEED: f64 = 1480.0;

fn radians_to_degrees(radians: f64) -> f64 {
    radians * 180.0 / PI
}

/// Generate synthetic transit times for a known flow velocity.
///
/// The acoustic path component along the flow direction is `L sin(θ)`, and the
/// signal effectively travels at `c - v` upstream and `c + v` downstream.
fn simulate_measurements(config: &FlowMeterConfig, true_flow_velocity: f64) -> Vec<PathMeasurement> {
    config
        .paths
        .iter()
        .map(|path| {
            let path_component = path.length * path.angle.sin();
            PathMeasurement::new(
                path_component / (SOUND_SPEED - true_flow_velocity),
                path_component / (SOUND_SPEED + true_flow_velocity),
            )
        })
        .collect()
}

fn print_config(config: &FlowMeterConfig) {
    println!("Flow Meter Configuration:");
    println!("  Pipe diameter: {:.3} m", config.pipe_diameter);
    println!("  Number of paths: {}", config.paths.len());
    println!("  Pipe area: {:.6} m²", config.pipe_area());
    println!("\nAcoustic Paths:");

    for (i, path) in config.paths.iter().enumerate() {
        println!("  Path {}:", i + 1);
        println!("    Position: {:.2} D", path.position);
        println!(
            "    Angle: {:.2}° ({:.4} rad)",
            radians_to_degrees(path.angle),
            path.angle
        );
        println!("    Path length: {:.4} m", path.length);
        println!("    Weight: {:.3}", path.weight);
    }
}

fn print_measurements(measurements: &[PathMeasurement], true_flow_velocity: f64) {
    println!("\nSimulated Measurements (True flow velocity: {true_flow_velocity:.2} m/s):");

    for (i, m) in measurements.iter().enumerate() {
        println!(
            "  Path {}: t_upstream = {:.8} s, t_downstream = {:.8} s, Δt = {:.2e} s",
            i + 1,
            m.t_upstream,
            m.t_downstream,
            m.delta_t()
        );
    }
}

fn print_results(result: &FlowResult) {
    println!("\nFlow Calculation Results:");

    for (i, velocity) in result.path_velocities.iter().enumerate() {
        println!("  Path {} velocity: {velocity:.4} m/s", i + 1);
    }

    println!("\nVolumetric Flow Rate:");
    println!("  {:.6} m³/s", result.volumetric_flow);
    println!("  {:.4} L/min", result.liters_per_minute());
    println!("  {:.2} L/s", result.liters_per_second());
}

/// Run one configuration end to end: describe it, simulate it, solve it.
fn run_demo(title: &str, config: &FlowMeterConfig, true_flow_velocity: f64) {
    println!("### {title} ###\n");

    print_config(config);

    let measurements = simulate_measurements(config, true_flow_velocity);
    print_measurements(&measurements, true_flow_velocity);

    print_results(&config.calculate_flow_rate(&measurements));
}

fn main() {
    let pipe_diameter = 0.1; // 100 mm
    let true_flow_velocity = 2.0; // 2 m/s

    println!("=== Ultrasonic Multipath Flow Meter ===\n");

    run_demo(
        "2-PATH CONFIGURATION",
        &FlowMeterConfig::two_path(pipe_diameter),
        true_flow_velocity,
    );

    println!("\n");

    run_demo(
        "4-PATH CONFIGURATION",
        &FlowMeterConfig::four_path(pipe_diameter),
        true_flow_velocity,
    );

    println!("\n=== End of Demonstration ===");
}
