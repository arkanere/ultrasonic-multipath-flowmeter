defmodule UltrasonicFlowmeter do
  @moduledoc """
  Ultrasonic multipath flow meter.

  Computes volumetric flow rate from ultrasonic transit-time measurements taken
  across multiple acoustic paths, using the transit-time differential method and
  Gauss-Jacobi quadrature integration.

  This module re-exports the public surface of `UltrasonicFlowmeter.Core` so the
  common entry points are reachable without reaching into a nested module — the
  same role `__init__.py` plays in the Python implementation.

      iex> config = UltrasonicFlowmeter.Main.create_2path_config(0.1)
      iex> measurements = UltrasonicFlowmeter.Main.simulate_measurements(config, 2.0)
      iex> result = UltrasonicFlowmeter.calculate_flow_rate(config, measurements)
      iex> Float.round(result.volumetric_flow, 6)
      0.031416
  """

  alias UltrasonicFlowmeter.Core

  defdelegate acoustic_path(position, angle, length, weight), to: Core
  defdelegate flow_meter_config(pipe_diameter, paths), to: Core
  defdelegate path_measurement(t_upstream, t_downstream), to: Core
  defdelegate flow_result(path_velocities, volumetric_flow), to: Core

  defdelegate calculate_path_velocity(path, measurement), to: Core
  defdelegate calculate_flow_rate(config, measurements), to: Core

  defdelegate to_liters_per_second(cubic_meters_per_second), to: Core
  defdelegate to_liters_per_minute(cubic_meters_per_second), to: Core
end
