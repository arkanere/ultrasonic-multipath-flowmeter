{ Core algorithm for the ultrasonic multipath flow meter.

  This unit is pure: it declares the four data structures, the two solvers, and
  the two unit converters, and it never writes to the console. Simulation and
  printing live in main.pas, mirroring the core/main split used by every other
  implementation in this repository. }

{$mode objfpc}{$H+}{$codepage UTF8}

unit FlowMeter;

interface

type
  { A single acoustic path across the pipe. }
  TAcousticPath = record
    Position:   Double;  { Position on pipe diameter (normalized: -1 to 1) }
    Angle:      Double;  { Angle from pipe axis, in radians }
    PathLength: Double;  { Acoustic path length, in meters }
    Weight:     Double;  { Gauss-Jacobi weighting coefficient }
  end;

  TAcousticPathArray = array of TAcousticPath;
  TDoubleArray = array of Double;

  { Meter configuration: the pipe plus its acoustic paths. }
  TFlowMeterConfig = record
    PipeDiameter: Double;              { Pipe diameter, in meters }
    NumPaths:     LongWord;            { Number of acoustic paths (2 or 4) }
    Paths:        TAcousticPathArray;  { Acoustic path configurations }
  end;

  { Transit times observed on one acoustic path. }
  TPathMeasurement = record
    TUpstream:   Double;  { Upstream transit time, in seconds }
    TDownstream: Double;  { Downstream transit time, in seconds }
  end;

  TPathMeasurementArray = array of TPathMeasurement;

  { Outcome of a flow calculation. }
  TFlowResult = record
    PathVelocities: TDoubleArray;  { Velocity computed for each path (m/s) }
    VolumetricFlow: Double;        { Total volumetric flow rate (m³/s) }
  end;

{ Build an acoustic path configuration. }
function MakeAcousticPath(APosition, AAngle, APathLength, AWeight: Double): TAcousticPath;

{ Build a flow meter configuration, deriving NumPaths from the path array so the
  two can never disagree. }
function MakeFlowMeterConfig(APipeDiameter: Double;
                             const APaths: TAcousticPathArray): TFlowMeterConfig;

{ Build a measurement from a single acoustic path. }
function MakePathMeasurement(ATUpstream, ATDownstream: Double): TPathMeasurement;

{ Calculate velocity from a single acoustic path measurement.

  Uses the transit-time differential method:
    v_path = (L / (2 * sin(theta))) * (dt / (t_up * t_down))

  Returns 0.0 for a non-positive transit time or a zero-sine angle, matching the
  guard clauses in the reference C implementation. }
function CalculatePathVelocity(const APath: TAcousticPath;
                               const AMeasurement: TPathMeasurement): Double;

{ Calculate the total volumetric flow rate from multiple path measurements.

  Uses Gauss-Jacobi quadrature integration with a weighted sum:
    Q = (pi * D^2 / 4) * sum(w_i * v_i)

  Raises an exception when the configuration has no paths, or when the number of
  measurements does not match the number of paths. }
function CalculateFlowRate(const AConfig: TFlowMeterConfig;
                           const AMeasurements: TPathMeasurementArray): TFlowResult;

{ Convert m³/s to L/s. }
function ToLitersPerSecond(ACubicMetersPerSecond: Double): Double;

{ Convert m³/s to L/min. }
function ToLitersPerMinute(ACubicMetersPerSecond: Double): Double;

implementation

uses
  SysUtils, Math;

function MakeAcousticPath(APosition, AAngle, APathLength, AWeight: Double): TAcousticPath;
begin
  Result.Position   := APosition;
  Result.Angle      := AAngle;
  Result.PathLength := APathLength;
  Result.Weight     := AWeight;
end;

function MakeFlowMeterConfig(APipeDiameter: Double;
                             const APaths: TAcousticPathArray): TFlowMeterConfig;
begin
  Result.PipeDiameter := APipeDiameter;
  Result.NumPaths     := System.Length(APaths);
  Result.Paths        := APaths;
end;

function MakePathMeasurement(ATUpstream, ATDownstream: Double): TPathMeasurement;
begin
  Result.TUpstream   := ATUpstream;
  Result.TDownstream := ATDownstream;
end;

function CalculatePathVelocity(const APath: TAcousticPath;
                               const AMeasurement: TPathMeasurement): Double;
var
  TUp, TDown, DeltaT, SinTheta: Double;
begin
  TUp   := AMeasurement.TUpstream;
  TDown := AMeasurement.TDownstream;

  { Avoid division by zero }
  if (TUp <= 0) or (TDown <= 0) then
    Exit(0.0);

  DeltaT   := TUp - TDown;
  SinTheta := Sin(APath.Angle);

  { Avoid division by zero if the angle is 0 }
  if SinTheta = 0 then
    Exit(0.0);

  { Apply the transit-time differential formula }
  Result := (APath.PathLength / (2.0 * SinTheta)) * (DeltaT / (TUp * TDown));
end;

function CalculateFlowRate(const AConfig: TFlowMeterConfig;
                           const AMeasurements: TPathMeasurementArray): TFlowResult;
var
  I: Integer;
  WeightedVelocitySum, Radius, Area: Double;
begin
  if System.Length(AConfig.Paths) = 0 then
    raise Exception.Create('CalculateFlowRate: configuration must contain at least one acoustic path');

  if System.Length(AConfig.Paths) <> System.Length(AMeasurements) then
    raise Exception.CreateFmt('CalculateFlowRate: expected %d measurements, got %d',
                              [System.Length(AConfig.Paths), System.Length(AMeasurements)]);

  SetLength(Result.PathVelocities, System.Length(AConfig.Paths));

  { Calculate velocity for each path and accumulate the weighted sum }
  WeightedVelocitySum := 0.0;
  for I := 0 to System.Length(AConfig.Paths) - 1 do
  begin
    Result.PathVelocities[I] := CalculatePathVelocity(AConfig.Paths[I], AMeasurements[I]);
    WeightedVelocitySum := WeightedVelocitySum +
                           AConfig.Paths[I].Weight * Result.PathVelocities[I];
  end;

  { Cross-sectional area: A = pi * (D/2)^2 = pi * D^2 / 4 }
  Radius := AConfig.PipeDiameter / 2.0;
  Area   := Pi * Radius * Radius;

  Result.VolumetricFlow := Area * WeightedVelocitySum;
end;

function ToLitersPerSecond(ACubicMetersPerSecond: Double): Double;
begin
  Result := ACubicMetersPerSecond * 1000.0;
end;

function ToLitersPerMinute(ACubicMetersPerSecond: Double): Double;
begin
  Result := ACubicMetersPerSecond * 60000.0;
end;

end.
