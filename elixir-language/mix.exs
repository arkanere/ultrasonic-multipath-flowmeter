defmodule UltrasonicFlowmeter.MixProject do
  use Mix.Project

  def project do
    [
      app: :ultrasonic_flowmeter,
      version: "1.0.0",
      elixir: "~> 1.14",
      description: "Ultrasonic multipath flow meter — transit-time differential method",
      start_permanent: Mix.env() == :prod,
      escript: [main_module: UltrasonicFlowmeter.Main, name: "flowmeter"],
      deps: deps()
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

  # No external dependencies — :math is part of Erlang/OTP.
  defp deps, do: []
end
