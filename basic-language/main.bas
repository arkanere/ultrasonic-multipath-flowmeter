'' main.bas -- demonstration program
''
'' Builds the 2-path and 4-path meters, simulates transit times for a known flow
'' velocity, solves for the flow rate, and prints the result.
''
'' Following the C implementation, the configuration builders live here rather
'' than in the algorithm file.

#include once "flowmeter.bi"
#include once "vbcompat.bi"   '' provides Format()

'' Speed of sound in water (approximation), m/s
Const SOUND_SPEED As Double = 1480.0

'' Demonstration parameters
Const DEMO_PIPE_DIAMETER As Double = 0.1   '' 100 mm
Const DEMO_FLOW_VELOCITY As Double = 2.0   '' m/s

'' ---------------------------------------------------------------------------
'' Configuration builders
'' ---------------------------------------------------------------------------

'' A 2-path configuration with 45-degree diagonal paths.
''
'' Typical quick-measurement layout: two paths at +/-0.25 D, averaged evenly.
Sub Create2PathConfig(ByRef config As FlowMeterConfig, ByVal pipeDiameter As Double)
    Dim As Double theta   = PI / 4.0            '' 45 degrees
    Dim As Double pathLen = pipeDiameter / Sin(theta)

    config.pipeDiameter = pipeDiameter
    config.numPaths     = 2
    ReDim config.paths(0 To 1)

    config.paths(0).position   =  0.25
    config.paths(0).angle      = theta
    config.paths(0).pathLength = pathLen
    config.paths(0).weight     = 0.5

    config.paths(1).position   = -0.25
    config.paths(1).angle      = theta
    config.paths(1).pathLength = pathLen
    config.paths(1).weight     = 0.5
End Sub

'' A 4-path configuration mixing 60-degree and 45-degree paths.
''
'' Two paths at 60 degrees (+/-0.35 D) sample near the pipe wall; two at 45
'' degrees (+/-0.15 D) sample near the center. Gauss-Jacobi weights of 0.25.
Sub Create4PathConfig(ByRef config As FlowMeterConfig, ByVal pipeDiameter As Double)
    Dim As Double theta60 = PI / 3.0            '' 60 degrees
    Dim As Double theta45 = PI / 4.0            '' 45 degrees
    Dim As Double len60   = pipeDiameter / Sin(theta60)
    Dim As Double len45   = pipeDiameter / Sin(theta45)

    config.pipeDiameter = pipeDiameter
    config.numPaths     = 4
    ReDim config.paths(0 To 3)

    config.paths(0).position   =  0.35
    config.paths(0).angle      = theta60
    config.paths(0).pathLength = len60
    config.paths(0).weight     = 0.25

    config.paths(1).position   = -0.35
    config.paths(1).angle      = theta60
    config.paths(1).pathLength = len60
    config.paths(1).weight     = 0.25

    config.paths(2).position   =  0.15
    config.paths(2).angle      = theta45
    config.paths(2).pathLength = len45
    config.paths(2).weight     = 0.25

    config.paths(3).position   = -0.15
    config.paths(3).angle      = theta45
    config.paths(3).pathLength = len45
    config.paths(3).weight     = 0.25
End Sub

'' ---------------------------------------------------------------------------
'' Simulation
'' ---------------------------------------------------------------------------

'' Synthesise upstream and downstream transit times from a known flow velocity.
''
'' The pulse travels the along-flow component L * sin(theta) at c - v going
'' upstream and c + v going downstream.
Sub SimulateMeasurements( _
        ByRef config As FlowMeterConfig, _
        measurements() As PathMeasurement, _
        ByVal trueFlowVelocity As Double)

    For i As Integer = 0 To config.numPaths - 1
        Dim As Double pathComponent = _
            config.paths(i).pathLength * Sin(config.paths(i).angle)

        measurements(i).tUpstream   = pathComponent / (SOUND_SPEED - trueFlowVelocity)
        measurements(i).tDownstream = pathComponent / (SOUND_SPEED + trueFlowVelocity)
    Next
End Sub

'' ---------------------------------------------------------------------------
'' Formatting helpers
'' ---------------------------------------------------------------------------

'' Fixed-point formatting with a given number of decimals.
''
'' FreeBASIC's PRINT USING is weaker than printf, so route every number through
'' Format() with an explicit picture string instead.
Function FormatFixed(ByVal value As Double, ByVal decimals As Integer) As String
    Dim As String picture = "0"

    If decimals > 0 Then
        picture += "."
        For i As Integer = 1 To decimals
            picture += "0"
        Next
    End If

    Return Format(value, picture)
End Function

'' Scientific notation with two decimals and a two-digit exponent.
''
'' Built by hand so the output matches C's %.2e -- 1.83e-07, not 1.83e-7.
Function FormatScientific(ByVal value As Double) As String
    If value = 0 Then
        Return "0.00e+00"
    End If

    '' FreeBASIC's Int() floors (Fix() is the one that truncates toward zero),
    '' so this is the exponent of the leading digit for negative powers too.
    Dim As Integer exponent = Int(Log(Abs(value)) / Log(10.0))
    Dim As Double mantissa = value / (10.0 ^ exponent)

    '' Rounding the mantissa can carry it to 10.00 -- renormalize when it does.
    If Abs(Val(FormatFixed(mantissa, 2))) >= 10.0 Then
        mantissa /= 10.0
        exponent += 1
    End If

    Dim As String sign = "+"
    If exponent < 0 Then sign = "-"

    Dim As String digits = Str(Abs(exponent))
    If Len(digits) < 2 Then digits = "0" + digits

    Return FormatFixed(mantissa, 2) + "e" + sign + digits
End Function

Function RadiansToDegrees(ByVal radians As Double) As Double
    Return radians * 180.0 / PI
End Function

'' ---------------------------------------------------------------------------
'' Printing
'' ---------------------------------------------------------------------------

'' Print the meter configuration and its acoustic paths
Sub PrintConfig(ByRef config As FlowMeterConfig)
    Dim As Double radius = config.pipeDiameter / 2.0

    Print "Flow Meter Configuration:"
    Print "  Pipe diameter: " + FormatFixed(config.pipeDiameter, 3) + " m"
    Print "  Number of paths: " + Str(config.numPaths)
    Print "  Pipe area: " + FormatFixed(PI * radius * radius, 6) + " m²"
    Print ""
    Print "Acoustic Paths:"

    For i As Integer = 0 To config.numPaths - 1
        Print "  Path " + Str(i + 1) + ":"
        Print "    Position: " + FormatFixed(config.paths(i).position, 2) + " D"
        Print "    Angle: " + FormatFixed(RadiansToDegrees(config.paths(i).angle), 2) + _
              "° (" + FormatFixed(config.paths(i).angle, 4) + " rad)"
        Print "    Path length: " + FormatFixed(config.paths(i).pathLength, 4) + " m"
        Print "    Weight: " + FormatFixed(config.paths(i).weight, 3)
    Next
End Sub

'' Print the simulated transit times for each path
Sub PrintMeasurements( _
        measurements() As PathMeasurement, _
        ByVal numPaths As Integer, _
        ByVal trueFlowVelocity As Double)

    Print ""
    Print "Simulated Measurements (True flow velocity: " + _
          FormatFixed(trueFlowVelocity, 2) + " m/s):"

    For i As Integer = 0 To numPaths - 1
        Dim As Double deltaT = measurements(i).tUpstream - measurements(i).tDownstream

        Print "  Path " + Str(i + 1) + _
              ": t_upstream = " + FormatFixed(measurements(i).tUpstream, 8) + _
              " s, t_downstream = " + FormatFixed(measurements(i).tDownstream, 8) + _
              " s, Δt = " + FormatScientific(deltaT) + " s"
    Next
End Sub

'' Print the per-path velocities and the total volumetric flow rate
Sub PrintResults(ByRef result As FlowResult, ByVal numPaths As Integer)
    Print ""
    Print "Flow Calculation Results:"

    For i As Integer = 0 To numPaths - 1
        Print "  Path " + Str(i + 1) + " velocity: " + _
              FormatFixed(result.pathVelocities(i), 4) + " m/s"
    Next

    Print ""
    Print "Volumetric Flow Rate:"
    Print "  " + FormatFixed(result.volumetricFlow, 6) + " m³/s"
    Print "  " + FormatFixed(ToLitersPerMinute(result.volumetricFlow), 4) + " L/min"
    Print "  " + FormatFixed(ToLitersPerSecond(result.volumetricFlow), 2) + " L/s"
End Sub

'' ---------------------------------------------------------------------------
'' Entry point
'' ---------------------------------------------------------------------------

'' Run one configuration end to end: print it, simulate, solve, report
Sub RunDemo(ByRef config As FlowMeterConfig, ByVal trueFlowVelocity As Double)
    PrintConfig(config)

    Dim measurements() As PathMeasurement
    ReDim measurements(0 To config.numPaths - 1)
    SimulateMeasurements(config, measurements(), trueFlowVelocity)
    PrintMeasurements(measurements(), config.numPaths, trueFlowVelocity)

    Dim As FlowResult result
    If CalculateFlowRate(config, measurements(), result) <> 0 Then
        Print "Error: Failed to process flow measurements"
        End 1
    End If

    PrintResults(result, config.numPaths)
End Sub

Print "=== Ultrasonic Multipath Flow Meter ==="
Print ""

Print "### 2-PATH CONFIGURATION ###"
Print ""
Dim As FlowMeterConfig config2Path
Create2PathConfig(config2Path, DEMO_PIPE_DIAMETER)
RunDemo(config2Path, DEMO_FLOW_VELOCITY)

Print ""
Print ""
Print "### 4-PATH CONFIGURATION ###"
Print ""
Dim As FlowMeterConfig config4Path
Create4PathConfig(config4Path, DEMO_PIPE_DIAMETER)
RunDemo(config4Path, DEMO_FLOW_VELOCITY)

Print ""
Print "=== End of Demonstration ==="
