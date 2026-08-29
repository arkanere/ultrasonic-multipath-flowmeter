'' flowmeter.bas -- core algorithm
''
'' Pure computation only: no PRINT statements appear in this file. Simulation and
'' formatting live in main.bas, mirroring the core/main split used by every other
'' implementation in this repository.

#include once "flowmeter.bi"

'' Calculate velocity from a single acoustic path measurement
Function CalculatePathVelocity( _
        ByRef path As AcousticPath, _
        ByRef measurement As PathMeasurement) As Double

    Dim As Double tUp   = measurement.tUpstream
    Dim As Double tDown = measurement.tDownstream

    '' Avoid division by zero
    If tUp <= 0 OrElse tDown <= 0 Then
        Return 0.0
    End If

    Dim As Double deltaT   = tUp - tDown
    Dim As Double sinTheta = Sin(path.angle)

    '' Avoid division by zero if the angle is 0
    If sinTheta = 0 Then
        Return 0.0
    End If

    '' Apply the transit-time differential formula
    Return (path.pathLength / (2.0 * sinTheta)) * (deltaT / (tUp * tDown))
End Function

'' Calculate the total volumetric flow rate from multiple path measurements
Function CalculateFlowRate( _
        ByRef config As FlowMeterConfig, _
        measurements() As PathMeasurement, _
        ByRef result As FlowResult) As Integer

    Dim As Integer pathCount = UBound(config.paths) - LBound(config.paths) + 1
    Dim As Integer measCount = UBound(measurements) - LBound(measurements) + 1

    If pathCount <= 0 Then
        Return -1
    End If

    If pathCount <> measCount Then
        Return -1
    End If

    ReDim result.pathVelocities(0 To pathCount - 1)

    '' Calculate velocity for each path and accumulate the weighted sum
    Dim As Double weightedVelocitySum = 0.0
    For i As Integer = 0 To pathCount - 1
        result.pathVelocities(i) = _
            CalculatePathVelocity(config.paths(i), measurements(i))
        weightedVelocitySum += config.paths(i).weight * result.pathVelocities(i)
    Next

    '' Cross-sectional area: A = pi * (D/2)^2 = pi * D^2 / 4
    Dim As Double radius = config.pipeDiameter / 2.0
    Dim As Double area   = PI * radius * radius

    result.volumetricFlow = area * weightedVelocitySum

    Return 0
End Function

'' Convert m^3/s to L/s
Function ToLitersPerSecond(ByVal cubicMetersPerSecond As Double) As Double
    Return cubicMetersPerSecond * 1000.0
End Function

'' Convert m^3/s to L/min
Function ToLitersPerMinute(ByVal cubicMetersPerSecond As Double) As Double
    Return cubicMetersPerSecond * 60000.0
End Function
