defmodule Redis2influx.MixProject do
  use Mix.Project

  def project do
    [
      app: :redis2influx,
      version: "0.1.0",
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Redis2influx.Application, []}
    ]
  end

  defp deps do
    [
      {:breaky, github: "mmzeeman/breaky"},
      {:instream, "~> 0.15" },
      {:eredis, "~> 1.0.8" }
    ]
  end
end
