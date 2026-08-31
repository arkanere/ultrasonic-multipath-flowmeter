// Command flowmeter demonstrates the ultrasonic multipath flow meter.
//
// It synthesizes transit times for a known flow velocity, then runs them back
// through the solver to recover the volumetric flow rate. This is the only
// package that writes to stdout; the algorithm itself lives in the flowmeter
// package.
package main

import (
	"fmt"
	"math"
	"os"

	"github.com/arkanere/ultrasonic-multipath-flowmeter/go-language/flowmeter"
)

// soundSpeed is the speed of sound in water at 20°C, in m/s.
const soundSpeed = 1480.0

func radiansToDegrees(radians float64) float64 { return radians * 180.0 / math.Pi }

// simulateMeasurements generates synthetic transit times for a known flow
// velocity.
//
// The acoustic path component along the flow direction is L sin(theta), and the
// signal effectively travels at c - v upstream and c + v downstream.
func simulateMeasurements(config flowmeter.Config, trueFlowVelocity float64) []flowmeter.PathMeasurement {
	measurements := make([]flowmeter.PathMeasurement, len(config.Paths))
	for i, path := range config.Paths {
		pathComponent := path.Length * math.Sin(path.Angle)
		measurements[i] = flowmeter.NewPathMeasurement(
			pathComponent/(soundSpeed-trueFlowVelocity),
			pathComponent/(soundSpeed+trueFlowVelocity),
		)
	}
	return measurements
}

func printConfig(config flowmeter.Config) {
	fmt.Println("Flow Meter Configuration:")
	fmt.Printf("  Pipe diameter: %.3f m\n", config.PipeDiameter)
	fmt.Printf("  Number of paths: %d\n", config.NumPaths())
	fmt.Printf("  Pipe area: %.6f m²\n", config.PipeArea())
	fmt.Println("\nAcoustic Paths:")

	for i, path := range config.Paths {
		fmt.Printf("  Path %d:\n", i+1)
		fmt.Printf("    Position: %.2f D\n", path.Position)
		fmt.Printf("    Angle: %.2f° (%.4f rad)\n", radiansToDegrees(path.Angle), path.Angle)
		fmt.Printf("    Path length: %.4f m\n", path.Length)
		fmt.Printf("    Weight: %.3f\n", path.Weight)
	}
}

func printMeasurements(measurements []flowmeter.PathMeasurement, trueFlowVelocity float64) {
	fmt.Printf("\nSimulated Measurements (True flow velocity: %.2f m/s):\n", trueFlowVelocity)

	for i, m := range measurements {
		fmt.Printf("  Path %d: t_upstream = %.8f s, t_downstream = %.8f s, Δt = %.2e s\n",
			i+1, m.TUpstream, m.TDownstream, m.DeltaT)
	}
}

func printResults(result flowmeter.Result) {
	fmt.Println("\nFlow Calculation Results:")

	for i, velocity := range result.PathVelocities {
		fmt.Printf("  Path %d velocity: %.4f m/s\n", i+1, velocity)
	}

	fmt.Println("\nVolumetric Flow Rate:")
	fmt.Printf("  %.6f m³/s\n", result.VolumetricFlow)
	fmt.Printf("  %.4f L/min\n", flowmeter.CubicMetersToLitersPerMinute(result.VolumetricFlow))
	fmt.Printf("  %.2f L/s\n", flowmeter.CubicMetersToLitersPerSecond(result.VolumetricFlow))
}

// runDemo runs one configuration end to end: describe it, simulate it, solve it.
func runDemo(title string, config flowmeter.Config, trueFlowVelocity float64) error {
	fmt.Printf("### %s ###\n\n", title)

	printConfig(config)

	measurements := simulateMeasurements(config, trueFlowVelocity)
	printMeasurements(measurements, trueFlowVelocity)

	result, err := flowmeter.CalculateFlowRate(config, measurements)
	if err != nil {
		return err
	}

	printResults(result)
	return nil
}

func run() error {
	const (
		pipeDiameter     = 0.1 // 100 mm
		trueFlowVelocity = 2.0 // 2 m/s
	)

	fmt.Println("=== Ultrasonic Multipath Flow Meter ===")
	fmt.Println()

	if err := runDemo("2-PATH CONFIGURATION", flowmeter.New2PathConfig(pipeDiameter), trueFlowVelocity); err != nil {
		return err
	}

	fmt.Print("\n\n")

	if err := runDemo("4-PATH CONFIGURATION", flowmeter.New4PathConfig(pipeDiameter), trueFlowVelocity); err != nil {
		return err
	}

	fmt.Println("\n=== End of Demonstration ===")
	return nil
}

func main() {
	if err := run(); err != nil {
		fmt.Fprintln(os.Stderr, "Error:", err)
		os.Exit(1)
	}
}
