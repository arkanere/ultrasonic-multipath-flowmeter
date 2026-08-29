'' flowmeter.bi -- data structures and core algorithm declarations
''
'' Declares the four data structures shared by every implementation in this
'' repository, plus the two solvers and the two unit converters. The bodies live
'' in flowmeter.bas; the simulation and printing live in main.bas.
''
'' FreeBASIC has no module system, so this header plays the same role as
'' flowmeter.h in the C implementation -- including the convention that the
'' configuration builders belong to the demo program, not to the algorithm.

#ifndef FLOWMETER_BI
#define FLOWMETER_BI

'' Pi, to the same precision as C's M_PI
Const PI As Double = 3.14159265358979323846

'' A single acoustic path across the pipe
Type AcousticPath
    position   As Double  '' Position on pipe diameter (normalized: -1 to 1)
    angle      As Double  '' Angle from pipe axis, in radians
    pathLength As Double  '' Acoustic path length, in meters
    weight     As Double  '' Gauss-Jacobi weighting coefficient
End Type

'' Meter configuration: the pipe plus its acoustic paths
Type FlowMeterConfig
    pipeDiameter As Double        '' Pipe diameter, in meters
    numPaths     As UInteger      '' Number of acoustic paths (2 or 4)
    paths(Any)   As AcousticPath  '' Acoustic path configurations
End Type

'' Transit times observed on one acoustic path
Type PathMeasurement
    tUpstream   As Double  '' Upstream transit time, in seconds
    tDownstream As Double  '' Downstream transit time, in seconds
End Type

'' Outcome of a flow calculation
Type FlowResult
    pathVelocities(Any) As Double  '' Velocity computed for each path (m/s)
    volumetricFlow      As Double  '' Total volumetric flow rate (m^3/s)
End Type

'' Calculate velocity from a single acoustic path measurement.
''
'' Uses the transit-time differential method:
''   v_path = (L / (2 * sin(theta))) * (dt / (t_up * t_down))
''
'' Returns 0.0 for a non-positive transit time or a zero-sine angle, matching the
'' guard clauses in the reference C implementation.
Declare Function CalculatePathVelocity( _
    ByRef path As AcousticPath, _
    ByRef measurement As PathMeasurement) As Double

'' Calculate the total volumetric flow rate from multiple path measurements.
''
'' Uses Gauss-Jacobi quadrature integration with a weighted sum:
''   Q = (pi * D^2 / 4) * sum(w_i * v_i)
''
'' Fills `result` and returns 0 on success, -1 on error -- the same return-code
'' convention the C implementation uses.
Declare Function CalculateFlowRate( _
    ByRef config As FlowMeterConfig, _
    measurements() As PathMeasurement, _
    ByRef result As FlowResult) As Integer

'' Convert m^3/s to L/s
Declare Function ToLitersPerSecond(ByVal cubicMetersPerSecond As Double) As Double

'' Convert m^3/s to L/min
Declare Function ToLitersPerMinute(ByVal cubicMetersPerSecond As Double) As Double

#endif '' FLOWMETER_BI
