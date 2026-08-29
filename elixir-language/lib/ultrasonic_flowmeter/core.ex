defmodule UltrasonicFlowmeter.Core do
  @moduledoc """
  Core algorithm for the ultrasonic multipath flow meter.

  This module is pure: it holds the four data structures and the two solver
  functions, and it never prints. Simulation and formatting live in
  `UltrasonicFlowmeter.Main`, mirroring the `core` / `main` split used by every
  other implementation in this repository.
  """

  defmodule AcousticPath do
    @moduledoc """
    A single acoustic path across the pipe.

      * `position` — position on the pipe diameter (normalized: -1 to 1)
      * `angle`    — angle from the pipe axis, in radians
      * `length`   — acoustic path length, in meters
      * `weight`   — Gauss-Jacobi weighting coefficient
    """
    @enforce_keys [:position, :angle, :length, :weight]
    defstruct [:position, :angle, :length, :weight]

    @type t :: %__MODULE__{
            position: float(),
            angle: float(),
            length: float(),
            weight: float()
          }
  end

  defmodule FlowMeterConfig do
    @moduledoc """
    Meter configuration: the pipe plus its acoustic paths.

      * `pipe_diameter` — pipe diameter, in meters
      * `num_paths`     — number of acoustic paths (2 or 4)
      * `paths`         — list of `AcousticPath` structs
    """
    @enforce_keys [:pipe_diameter, :num_paths, :paths]
    defstruct [:pipe_diameter, :num_paths, :paths]

    @type t :: %__MODULE__{
            pipe_diameter: float(),
            num_paths: non_neg_integer(),
            paths: [AcousticPath.t()]
          }
  end

  defmodule PathMeasurement do
    @moduledoc """
    Transit times observed on one acoustic path.

      * `t_upstream`   — upstream transit time, in seconds
      * `t_downstream` — downstream transit time, in seconds
    """
    @enforce_keys [:t_upstream, :t_downstream]
    defstruct [:t_upstream, :t_downstream]

    @type t :: %__MODULE__{t_upstream: float(), t_downstream: float()}
  end

  defmodule FlowResult do
    @moduledoc """
    Outcome of a flow calculation.

      * `path_velocities` — velocity computed for each path (m/s)
      * `volumetric_flow` — total volumetric flow rate (m³/s)
    """
    @enforce_keys [:path_velocities, :volumetric_flow]
    defstruct [:path_velocities, :volumetric_flow]

    @type t :: %__MODULE__{path_velocities: [float()], volumetric_flow: float()}
  end

  alias UltrasonicFlowmeter.Core.{
    AcousticPath,
    FlowMeterConfig,
    FlowResult,
    PathMeasurement
  }

  ## Data structure helpers

  @doc "Build an acoustic path configuration."
  @spec acoustic_path(float(), float(), float(), float()) :: AcousticPath.t()
  def acoustic_path(position, angle, length, weight) do
    %AcousticPath{position: position, angle: angle, length: length, weight: weight}
  end

  @doc "Build a flow meter configuration from a list of paths."
  @spec flow_meter_config(float(), [AcousticPath.t()]) :: FlowMeterConfig.t()
  def flow_meter_config(pipe_diameter, paths) do
    %FlowMeterConfig{
      pipe_diameter: pipe_diameter,
      num_paths: length(paths),
      paths: paths
    }
  end

  @doc "Build a measurement from a single acoustic path."
  @spec path_measurement(float(), float()) :: PathMeasurement.t()
  def path_measurement(t_upstream, t_downstream) do
    %PathMeasurement{t_upstream: t_upstream, t_downstream: t_downstream}
  end

  @doc "Build a flow result from per-path velocities and a total flow rate."
  @spec flow_result([float()], float()) :: FlowResult.t()
  def flow_result(path_velocities, volumetric_flow) do
    %FlowResult{path_velocities: path_velocities, volumetric_flow: volumetric_flow}
  end

  ## Core algorithm

  @doc """
  Calculate velocity from a single acoustic path measurement.

  Uses the transit-time differential method:

      v_path = (L / (2 * sin(θ))) * (Δt / (t_up * t_down))

  Returns `0.0` for a non-positive transit time or a zero-sine angle, matching
  the guard clauses in the reference C implementation.
  """
  @spec calculate_path_velocity(AcousticPath.t(), PathMeasurement.t()) :: float()
  def calculate_path_velocity(%AcousticPath{}, %PathMeasurement{t_upstream: t_up})
      when t_up <= 0,
      do: 0.0

  def calculate_path_velocity(%AcousticPath{}, %PathMeasurement{t_downstream: t_down})
      when t_down <= 0,
      do: 0.0

  def calculate_path_velocity(%AcousticPath{angle: angle, length: length}, measurement) do
    %PathMeasurement{t_upstream: t_up, t_downstream: t_down} = measurement

    delta_t = t_up - t_down
    sin_theta = :math.sin(angle)

    if sin_theta == 0.0 do
      0.0
    else
      length / (2.0 * sin_theta) * (delta_t / (t_up * t_down))
    end
  end

  @doc """
  Calculate the total volumetric flow rate from multiple path measurements.

  Uses Gauss-Jacobi quadrature integration with a weighted sum:

      Q = (π * D² / 4) * Σ(w_i * v_i)
  """
  @spec calculate_flow_rate(FlowMeterConfig.t(), [PathMeasurement.t()]) :: FlowResult.t()
  def calculate_flow_rate(%FlowMeterConfig{paths: []}, _measurements) do
    raise ArgumentError, "configuration must contain at least one acoustic path"
  end

  def calculate_flow_rate(%FlowMeterConfig{pipe_diameter: diameter, paths: paths}, measurements)
      when length(paths) != length(measurements) do
    raise ArgumentError,
          "expected #{length(paths)} measurements for a #{diameter} m meter, " <>
            "got #{length(measurements)}"
  end

  def calculate_flow_rate(%FlowMeterConfig{pipe_diameter: pipe_diameter, paths: paths}, measurements) do
    velocities =
      paths
      |> Enum.zip(measurements)
      |> Enum.map(fn {path, measurement} -> calculate_path_velocity(path, measurement) end)

    weighted_sum =
      paths
      |> Enum.zip(velocities)
      |> Enum.map(fn {path, velocity} -> path.weight * velocity end)
      |> Enum.sum()

    # Cross-sectional area: A = π * (D/2)² = π * D² / 4
    radius = pipe_diameter / 2.0
    area = :math.pi() * radius * radius

    flow_result(velocities, area * weighted_sum)
  end

  ## Unit conversion helpers

  @doc "Convert m³/s to L/s."
  @spec to_liters_per_second(float()) :: float()
  def to_liters_per_second(cubic_meters_per_second), do: cubic_meters_per_second * 1000.0

  @doc "Convert m³/s to L/min."
  @spec to_liters_per_minute(float()) :: float()
  def to_liters_per_minute(cubic_meters_per_second), do: cubic_meters_per_second * 60000.0
end
