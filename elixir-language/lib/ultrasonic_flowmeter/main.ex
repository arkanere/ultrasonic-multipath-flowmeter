defmodule UltrasonicFlowmeter.Main do
  @moduledoc """
  Demonstration program: builds the 2-path and 4-path meters, simulates transit
  times for a known flow velocity, solves for the flow rate, and prints the
  result.

  Everything impure lives here — the configuration builders, the simulator, the
  printers, and the entry point — leaving `UltrasonicFlowmeter.Core` pure.
  """

  alias UltrasonicFlowmeter.Core
  alias UltrasonicFlowmeter.Core.{FlowMeterConfig, FlowResult, PathMeasurement}

  # Speed of sound in water (approximation), m/s
  @sound_speed 1480.0

  # Demonstration parameters
  @pipe_diameter 0.1
  @true_flow_velocity 2.0

  ## Configuration builders

  @doc """
  Build a 2-path configuration with 45-degree diagonal paths.

  Typical quick-measurement layout: two paths at ±0.25 D, averaged evenly.
  """
  @spec create_2path_config(float()) :: FlowMeterConfig.t()
  def create_2path_config(pipe_diameter) do
    angle = :math.pi() / 4.0
    path_length = pipe_diameter / :math.sin(angle)

    Core.flow_meter_config(pipe_diameter, [
      Core.acoustic_path(0.25, angle, path_length, 0.5),
      Core.acoustic_path(-0.25, angle, path_length, 0.5)
    ])
  end

  @doc """
  Build a 4-path configuration mixing 60-degree and 45-degree paths.

  Two paths at 60° (±0.35 D) sample near the pipe wall; two at 45° (±0.15 D)
  sample near the center. Gauss-Jacobi weights of 0.25 each.
  """
  @spec create_4path_config(float()) :: FlowMeterConfig.t()
  def create_4path_config(pipe_diameter) do
    angle_60 = :math.pi() / 3.0
    angle_45 = :math.pi() / 4.0
    length_60 = pipe_diameter / :math.sin(angle_60)
    length_45 = pipe_diameter / :math.sin(angle_45)

    Core.flow_meter_config(pipe_diameter, [
      Core.acoustic_path(0.35, angle_60, length_60, 0.25),
      Core.acoustic_path(-0.35, angle_60, length_60, 0.25),
      Core.acoustic_path(0.15, angle_45, length_45, 0.25),
      Core.acoustic_path(-0.15, angle_45, length_45, 0.25)
    ])
  end

  ## Simulation

  @doc """
  Simulate measurement data for demonstration.

  Synthesises upstream and downstream transit times from a known flow velocity:
  the acoustic pulse travels the along-flow component `L * sin(θ)` at `c - v`
  going upstream and `c + v` going downstream.
  """
  @spec simulate_measurements(FlowMeterConfig.t(), float()) :: [PathMeasurement.t()]
  def simulate_measurements(%FlowMeterConfig{paths: paths}, true_flow_velocity) do
    Enum.map(paths, fn path ->
      path_component = path.length * :math.sin(path.angle)

      Core.path_measurement(
        path_component / (@sound_speed - true_flow_velocity),
        path_component / (@sound_speed + true_flow_velocity)
      )
    end)
  end

  ## Formatting helpers

  # `:io_lib.format/2` is Erlang's printf. Wrapping it keeps the call sites
  # readable and returns a binary rather than an iolist.
  defp fmt(format, args), do: format |> :io_lib.format(args) |> IO.iodata_to_binary()

  # Erlang's ~e prints `1.83e-7`; C's `%.2e` prints `1.83e-07`. Pad the exponent
  # to two digits so this implementation stays byte-identical with the C output.
  defp fmt_scientific(value) when value == 0.0, do: "0.00e+00"

  defp fmt_scientific(value) do
    exponent = floor(:math.log10(abs(value)))
    mantissa = value / :math.pow(10, exponent)

    # Rounding the mantissa can carry it to 10.00 — renormalize when it does.
    {mantissa, exponent} =
      if abs(Float.round(mantissa, 2)) >= 10.0,
        do: {mantissa / 10.0, exponent + 1},
        else: {mantissa, exponent}

    sign = if exponent < 0, do: "-", else: "+"
    digits = exponent |> abs() |> Integer.to_string() |> String.pad_leading(2, "0")

    fmt("~.2f", [mantissa]) <> "e" <> sign <> digits
  end

  defp radians_to_degrees(radians), do: radians * 180.0 / :math.pi()

  ## Printing

  @doc "Print the meter configuration and its acoustic paths."
  @spec print_config(FlowMeterConfig.t()) :: :ok
  def print_config(%FlowMeterConfig{} = config) do
    radius = config.pipe_diameter / 2.0

    IO.puts("Flow Meter Configuration:")
    IO.puts(fmt("  Pipe diameter: ~.3f m", [config.pipe_diameter]))
    IO.puts("  Number of paths: #{config.num_paths}")
    IO.puts(fmt("  Pipe area: ~.6f m²", [:math.pi() * radius * radius]))
    IO.puts("")
    IO.puts("Acoustic Paths:")

    config.paths
    |> Enum.with_index(1)
    |> Enum.each(fn {path, index} ->
      IO.puts("  Path #{index}:")
      IO.puts(fmt("    Position: ~.2f D", [path.position]))
      IO.puts(fmt("    Angle: ~.2f° (~.4f rad)", [radians_to_degrees(path.angle), path.angle]))
      IO.puts(fmt("    Path length: ~.4f m", [path.length]))
      IO.puts(fmt("    Weight: ~.3f", [path.weight]))
    end)
  end

  @doc "Print the simulated transit times for each path."
  @spec print_measurements([PathMeasurement.t()], float()) :: :ok
  def print_measurements(measurements, true_flow_velocity) do
    IO.puts("")
    IO.puts(fmt("Simulated Measurements (True flow velocity: ~.2f m/s):", [true_flow_velocity]))

    measurements
    |> Enum.with_index(1)
    |> Enum.each(fn {measurement, index} ->
      delta_t = measurement.t_upstream - measurement.t_downstream

      IO.puts(
        fmt("  Path ~b: t_upstream = ~.8f s, t_downstream = ~.8f s, ", [
          index,
          measurement.t_upstream,
          measurement.t_downstream
        ]) <> "Δt = " <> fmt_scientific(delta_t) <> " s"
      )
    end)
  end

  @doc "Print the per-path velocities and the total volumetric flow rate."
  @spec print_results(FlowResult.t()) :: :ok
  def print_results(%FlowResult{} = result) do
    IO.puts("")
    IO.puts("Flow Calculation Results:")

    result.path_velocities
    |> Enum.with_index(1)
    |> Enum.each(fn {velocity, index} ->
      IO.puts(fmt("  Path ~b velocity: ~.4f m/s", [index, velocity]))
    end)

    IO.puts("")
    IO.puts("Volumetric Flow Rate:")
    IO.puts(fmt("  ~.6f m³/s", [result.volumetric_flow]))
    IO.puts(fmt("  ~.4f L/min", [Core.to_liters_per_minute(result.volumetric_flow)]))
    IO.puts(fmt("  ~.2f L/s", [Core.to_liters_per_second(result.volumetric_flow)]))
  end

  ## Entry point

  @doc "Run one configuration end to end: print it, simulate, solve, report."
  @spec run_demo(FlowMeterConfig.t(), float()) :: :ok
  def run_demo(config, true_flow_velocity) do
    print_config(config)

    measurements = simulate_measurements(config, true_flow_velocity)
    print_measurements(measurements, true_flow_velocity)

    config
    |> Core.calculate_flow_rate(measurements)
    |> print_results()
  end

  @doc "Program entry point — runs the 2-path and 4-path demonstrations."
  @spec main([String.t()]) :: :ok
  def main(_args \\ []) do
    IO.puts("=== Ultrasonic Multipath Flow Meter ===")
    IO.puts("")

    IO.puts("### 2-PATH CONFIGURATION ###")
    IO.puts("")
    run_demo(create_2path_config(@pipe_diameter), @true_flow_velocity)

    IO.puts("")
    IO.puts("")
    IO.puts("### 4-PATH CONFIGURATION ###")
    IO.puts("")
    run_demo(create_4path_config(@pipe_diameter), @true_flow_velocity)

    IO.puts("")
    IO.puts("=== End of Demonstration ===")
  end
end
