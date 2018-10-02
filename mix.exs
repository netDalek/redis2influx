defmodule Redis2influx.MixProject do
  use Mix.Project

  @url_github "https://github.com/netDalek/redis2influx"

  def project do
    [
      app: :redis2influx,
      version: "0.1.0",
      elixir: "~> 1.7",
      elixirc_paths: elixirc_paths(Mix.env),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      docs: docs()
    ]
  end

  defp elixirc_paths(:test), do: ["lib","test/support"]
  defp elixirc_paths(_), do: ["lib"]

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
      {:eredis, "~> 1.0.8" },
      {:excoveralls, "~> 0.5", only: :test},
      {:dialyxir, "~> 0.5", only: [:dev], runtime: false},
      {:earmark, "~> 1.1", only: :dev},
      {:ex_doc, "~> 0.11", only: :dev},
      {:inch_ex, "~> 0.5.6", only: :docs},
      {:credo, "~> 0.8", only: [:dev, :test], runtime: false}
    ]
  end

  defp docs do
 [
      extras: ["CHANGELOG.md", "README.md"],
      main: "readme",
      source_ref: "master",
      source_url: @url_github
]
  end

defp package do
    %{
      files: [".formatter.exs", "CHANGELOG.md", "mix.exs", "README.md", "lib"],
      licenses: ["Apache 2.0"],
      links: %{"GitHub" => @url_github},
      maintainers: ["Denis Kirichenko"]
    }
end
end
