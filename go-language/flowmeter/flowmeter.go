// Package flowmeter implements the core algorithm of a transit-time
// differential ultrasonic flow meter.
//
// An ultrasonic signal sent across a pipe travels faster with the flow than
// against it. Comparing the two transit times reveals the flow velocity
// without needing to know the speed of sound in the fluid.
//
// The package is pure: nothing here writes to stdout or touches the
// filesystem, so it can be imported by a simulation, a test, or real
// transducer firmware alike.
package flowmeter

import (
	"errors"
	"math"
)

// Errors returned by CalculateFlowRate.
var (
	// ErrNoPaths reports a configuration with no acoustic paths, which has no
	// cross-section to integrate over.
	ErrNoPaths = errors.New("flowmeter: configuration has no acoustic paths")

	// ErrMeasurementCount reports a measurement slice that does not line up
	// one-to-one with the configured paths.
	ErrMeasurementCount = errors.New("flowmeter: expected one measurement per acoustic path")
)

// An AcousticPath is a single ultrasonic beam crossing the pipe.
type AcousticPath struct {
	Position float64 // Position on the pipe diameter, normalized to -1..1.
	Angle    float64 // Angle from the pipe axis, in radians.
	Length   float64 // Acoustic path length, in meters: the chord D / sin(angle).
	Weight   float64 // Gauss-Jacobi weighting coefficient.
}

// NewAcousticPath builds a path across a pipe of the given diameter, deriving
// the path length from the chord D / sin(angle).
func NewAcousticPath(pipeDiameter, position, angle, weight float64) AcousticPath {
	return AcousticPath{
		Position: position,
		Angle:    angle,
		Length:   pipeDiameter / math.Sin(angle),
		Weight:   weight,
	}
}

// A PathMeasurement holds the upstream and downstream transit times for one
// path, in seconds. DeltaT is the difference the whole method rests on.
type PathMeasurement struct {
	TUpstream   float64
	TDownstream float64
	DeltaT      float64
}

// NewPathMeasurement records a pair of transit times and derives DeltaT once,
// so it can never fall out of sync with the times behind it.
func NewPathMeasurement(tUpstream, tDownstream float64) PathMeasurement {
	return PathMeasurement{
		TUpstream:   tUpstream,
		TDownstream: tDownstream,
		DeltaT:      tUpstream - tDownstream,
	}
}

// A Config bundles a pipe with the acoustic paths crossing it.
type Config struct {
	PipeDiameter float64
	Paths        []AcousticPath
}

// NewConfig bundles a pipe diameter with its paths, copying the slice so a
// later write by the caller cannot reach inside the configuration.
func NewConfig(pipeDiameter float64, paths []AcousticPath) Config {
	return Config{
		PipeDiameter: pipeDiameter,
		Paths:        append([]AcousticPath(nil), paths...),
	}
}

// NumPaths reports how many acoustic paths cross the pipe.
func (c Config) NumPaths() int { return len(c.Paths) }

// PipeArea returns the cross-sectional area of the pipe, pi (D/2)^2, in m².
func (c Config) PipeArea() float64 {
	radius := c.PipeDiameter / 2.0
	return math.Pi * radius * radius
}

// A Result is one solved measurement cycle.
type Result struct {
	PathVelocities []float64 // Recovered axial velocity per path, in m/s.
	VolumetricFlow float64   // Integrated flow rate, in m³/s.
}

// CalculatePathVelocity returns the velocity along the pipe axis implied by one
// path measurement, in m/s.
//
// Transit-time differential method:
//
//	v_path = (L / (2 sin(theta))) * (deltaT / (t_up * t_down))
//
// It returns 0 for non-physical transit times or a degenerate path angle,
// matching the C reference implementation.
func CalculatePathVelocity(path AcousticPath, m PathMeasurement) float64 {
	if m.TUpstream <= 0 || m.TDownstream <= 0 {
		return 0.0
	}

	sinTheta := math.Sin(path.Angle)

	// A path along the pipe axis carries no flow information.
	if sinTheta == 0 {
		return 0.0
	}

	return (path.Length / (2.0 * sinTheta)) *
		(m.DeltaT / (m.TUpstream * m.TDownstream))
}

// CalculateFlowRate integrates the per-path velocities into a volumetric flow
// rate by Gauss-Jacobi quadrature: Q = (pi D^2 / 4) * sum(w_i v_i).
func CalculateFlowRate(config Config, measurements []PathMeasurement) (Result, error) {
	if len(config.Paths) == 0 {
		return Result{}, ErrNoPaths
	}
	if len(measurements) != len(config.Paths) {
		return Result{}, ErrMeasurementCount
	}

	velocities := make([]float64, len(config.Paths))
	weightedVelocitySum := 0.0
	for i, path := range config.Paths {
		velocities[i] = CalculatePathVelocity(path, measurements[i])
		weightedVelocitySum += path.Weight * velocities[i]
	}

	return Result{
		PathVelocities: velocities,
		VolumetricFlow: config.PipeArea() * weightedVelocitySum,
	}, nil
}

// New2PathConfig builds two 45° paths at ±0.25 D: quick, cost-effective
// measurement.
func New2PathConfig(pipeDiameter float64) Config {
	angle := math.Pi / 4.0
	return NewConfig(pipeDiameter, []AcousticPath{
		NewAcousticPath(pipeDiameter, 0.25, angle, 0.5),
		NewAcousticPath(pipeDiameter, -0.25, angle, 0.5),
	})
}

// New4PathConfig builds two 60° paths near the wall plus two 45° paths near the
// center. Sampling the velocity profile at four heights integrates it more
// accurately than a single pair of paths.
func New4PathConfig(pipeDiameter float64) Config {
	outerAngle := math.Pi / 3.0
	innerAngle := math.Pi / 4.0
	return NewConfig(pipeDiameter, []AcousticPath{
		NewAcousticPath(pipeDiameter, 0.35, outerAngle, 0.25),
		NewAcousticPath(pipeDiameter, -0.35, outerAngle, 0.25),
		NewAcousticPath(pipeDiameter, 0.15, innerAngle, 0.25),
		NewAcousticPath(pipeDiameter, -0.15, innerAngle, 0.25),
	})
}

// CubicMetersToLitersPerSecond converts m³/s to L/s.
func CubicMetersToLitersPerSecond(m3PerS float64) float64 { return m3PerS * 1000.0 }

// CubicMetersToLitersPerMinute converts m³/s to L/min.
func CubicMetersToLitersPerMinute(m3PerS float64) float64 { return m3PerS * 60000.0 }
