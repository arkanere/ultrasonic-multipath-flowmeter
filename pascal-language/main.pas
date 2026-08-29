{ Demonstration program: builds the 2-path and 4-path meters, simulates transit
  times for a known flow velocity, solves for the flow rate, and prints the
  result.

  Everything that touches the console lives here, leaving the FlowMeter unit
  pure. }

{$mode objfpc}{$H+}{$codepage UTF8}

program FlowMeterDemo;

uses
  SysUtils, Math, FlowMeter;

const
  { Speed of sound in water (approximation), m/s }
  SOUND_SPEED = 1480.0;

  { Demonstration parameters }
  DEMO_PIPE_DIAMETER = 0.1;   { 100 mm }
  DEMO_FLOW_VELOCITY = 2.0;   { m/s }

{ ---------------------------------------------------------------------------
  Configuration builders
  --------------------------------------------------------------------------- }

{ A 2-path configuration with 45-degree diagonal paths.

  Typical quick-measurement layout: two paths at +/-0.25 D, averaged evenly. }
function Create2PathConfig(APipeDiameter: Double): TFlowMeterConfig;
var
  Paths: TAcousticPathArray;
  Theta, PathLen: Double;
begin
  Theta   := Pi / 4.0;                  { 45 degrees }
  PathLen := APipeDiameter / Sin(Theta);

  SetLength(Paths, 2);
  Paths[0] := MakeAcousticPath( 0.25, Theta, PathLen, 0.5);
  Paths[1] := MakeAcousticPath(-0.25, Theta, PathLen, 0.5);

  Result := MakeFlowMeterConfig(APipeDiameter, Paths);
end;

{ A 4-path configuration mixing 60-degree and 45-degree paths.

  Two paths at 60 degrees (+/-0.35 D) sample near the pipe wall; two at 45
  degrees (+/-0.15 D) sample near the center. Gauss-Jacobi weights of 0.25. }
function Create4PathConfig(APipeDiameter: Double): TFlowMeterConfig;
var
  Paths: TAcousticPathArray;
  Theta60, Theta45, Len60, Len45: Double;
begin
  Theta60 := Pi / 3.0;                  { 60 degrees }
  Theta45 := Pi / 4.0;                  { 45 degrees }
  Len60   := APipeDiameter / Sin(Theta60);
  Len45   := APipeDiameter / Sin(Theta45);

  SetLength(Paths, 4);
  Paths[0] := MakeAcousticPath( 0.35, Theta60, Len60, 0.25);
  Paths[1] := MakeAcousticPath(-0.35, Theta60, Len60, 0.25);
  Paths[2] := MakeAcousticPath( 0.15, Theta45, Len45, 0.25);
  Paths[3] := MakeAcousticPath(-0.15, Theta45, Len45, 0.25);

  Result := MakeFlowMeterConfig(APipeDiameter, Paths);
end;

{ ---------------------------------------------------------------------------
  Simulation
  --------------------------------------------------------------------------- }

{ Synthesise upstream and downstream transit times from a known flow velocity.

  The pulse travels the along-flow component L * sin(theta) at c - v going
  upstream and c + v going downstream. }
function SimulateMeasurements(const AConfig: TFlowMeterConfig;
                              ATrueFlowVelocity: Double): TPathMeasurementArray;
var
  I: Integer;
  PathComponent: Double;
begin
  SetLength(Result, System.Length(AConfig.Paths));

  for I := 0 to System.Length(AConfig.Paths) - 1 do
  begin
    PathComponent := AConfig.Paths[I].PathLength * Sin(AConfig.Paths[I].Angle);

    Result[I] := MakePathMeasurement(
      PathComponent / (SOUND_SPEED - ATrueFlowVelocity),
      PathComponent / (SOUND_SPEED + ATrueFlowVelocity));
  end;
end;

{ ---------------------------------------------------------------------------
  Formatting helpers
  --------------------------------------------------------------------------- }

{ Format in scientific notation with a two-digit exponent.

  Free Pascal's Format('%e', ...) yields 1.83E+007, whereas C's %.2e yields
  1.83e-07. Building the string by hand keeps this implementation byte-identical
  with the C output. }
function FormatScientific(AValue: Double): String;
var
  Exponent: Integer;
  Mantissa: Double;
  Sign: String;
begin
  if AValue = 0 then
    Exit('0.00e+00');

  Exponent := Floor(Log10(Abs(AValue)));
  Mantissa := AValue / Power(10.0, Exponent);

  { Rounding the mantissa can carry it to 10.00 - renormalize when it does. }
  if Abs(RoundTo(Mantissa, -2)) >= 10.0 then
  begin
    Mantissa := Mantissa / 10.0;
    Inc(Exponent);
  end;

  if Exponent < 0 then
    Sign := '-'
  else
    Sign := '+';

  { For integers a Delphi/FPC precision specifier means "at least N digits",
    zero-padded - so %.2d turns 7 into 07. }
  Result := Format('%.2f', [Mantissa]) + 'e' + Sign +
            Format('%.2d', [Abs(Exponent)]);
end;

function RadiansToDegrees(ARadians: Double): Double;
begin
  Result := ARadians * 180.0 / Pi;
end;

{ ---------------------------------------------------------------------------
  Printing
  --------------------------------------------------------------------------- }

{ Print the meter configuration and its acoustic paths. }
procedure PrintConfig(const AConfig: TFlowMeterConfig);
var
  I: Integer;
  Radius: Double;
begin
  Radius := AConfig.PipeDiameter / 2.0;

  WriteLn('Flow Meter Configuration:');
  WriteLn(Format('  Pipe diameter: %.3f m', [AConfig.PipeDiameter]));
  WriteLn(Format('  Number of paths: %d', [Integer(AConfig.NumPaths)]));
  WriteLn(Format('  Pipe area: %.6f m²', [Pi * Radius * Radius]));
  WriteLn('');
  WriteLn('Acoustic Paths:');

  for I := 0 to System.Length(AConfig.Paths) - 1 do
  begin
    WriteLn(Format('  Path %d:', [I + 1]));
    WriteLn(Format('    Position: %.2f D', [AConfig.Paths[I].Position]));
    WriteLn(Format('    Angle: %.2f° (%.4f rad)',
                   [RadiansToDegrees(AConfig.Paths[I].Angle), AConfig.Paths[I].Angle]));
    WriteLn(Format('    Path length: %.4f m', [AConfig.Paths[I].PathLength]));
    WriteLn(Format('    Weight: %.3f', [AConfig.Paths[I].Weight]));
  end;
end;

{ Print the simulated transit times for each path. }
procedure PrintMeasurements(const AMeasurements: TPathMeasurementArray;
                            ATrueFlowVelocity: Double);
var
  I: Integer;
  DeltaT: Double;
begin
  WriteLn('');
  WriteLn(Format('Simulated Measurements (True flow velocity: %.2f m/s):',
                 [ATrueFlowVelocity]));

  for I := 0 to System.Length(AMeasurements) - 1 do
  begin
    DeltaT := AMeasurements[I].TUpstream - AMeasurements[I].TDownstream;

    WriteLn(Format('  Path %d: t_upstream = %.8f s, t_downstream = %.8f s, Δt = %s s',
                   [I + 1,
                    AMeasurements[I].TUpstream,
                    AMeasurements[I].TDownstream,
                    FormatScientific(DeltaT)]));
  end;
end;

{ Print the per-path velocities and the total volumetric flow rate. }
procedure PrintResults(const AResult: TFlowResult);
var
  I: Integer;
begin
  WriteLn('');
  WriteLn('Flow Calculation Results:');

  for I := 0 to System.Length(AResult.PathVelocities) - 1 do
    WriteLn(Format('  Path %d velocity: %.4f m/s', [I + 1, AResult.PathVelocities[I]]));

  WriteLn('');
  WriteLn('Volumetric Flow Rate:');
  WriteLn(Format('  %.6f m³/s', [AResult.VolumetricFlow]));
  WriteLn(Format('  %.4f L/min', [ToLitersPerMinute(AResult.VolumetricFlow)]));
  WriteLn(Format('  %.2f L/s', [ToLitersPerSecond(AResult.VolumetricFlow)]));
end;

{ ---------------------------------------------------------------------------
  Entry point
  --------------------------------------------------------------------------- }

{ Run one configuration end to end: print it, simulate, solve, report. }
procedure RunDemo(const AConfig: TFlowMeterConfig; ATrueFlowVelocity: Double);
var
  Measurements: TPathMeasurementArray;
begin
  PrintConfig(AConfig);

  Measurements := SimulateMeasurements(AConfig, ATrueFlowVelocity);
  PrintMeasurements(Measurements, ATrueFlowVelocity);

  PrintResults(CalculateFlowRate(AConfig, Measurements));
end;

begin
  { Format() honours the locale decimal separator; pin it so the output is the
    same on every machine. }
  DefaultFormatSettings.DecimalSeparator := '.';

  WriteLn('=== Ultrasonic Multipath Flow Meter ===');
  WriteLn('');

  WriteLn('### 2-PATH CONFIGURATION ###');
  WriteLn('');
  RunDemo(Create2PathConfig(DEMO_PIPE_DIAMETER), DEMO_FLOW_VELOCITY);

  WriteLn('');
  WriteLn('');
  WriteLn('### 4-PATH CONFIGURATION ###');
  WriteLn('');
  RunDemo(Create4PathConfig(DEMO_PIPE_DIAMETER), DEMO_FLOW_VELOCITY);

  WriteLn('');
  WriteLn('=== End of Demonstration ===');
end.
