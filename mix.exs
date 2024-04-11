defmodule CacheAPI.MixProject do
  use Mix.Project

  def project do
    [
      app: :cache_api,
      version: "0.1.0",
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {CacheAPI.Application, []},
      releases: [
        CacheAPI: [
          version: "1.0.0",
          applications: [opentelemetry_exporter: :permanent, opentelemetry: :temporary]
        ]
      ]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:plug, "== 1.15.3"},
      {:poison, "~> 5.0"},
      {:plug_cowboy, "~> 2.7.0"},
      {:httpoison, "~> 2.0"},
      {:broadway_kafka, "~> 0.4.0"},
      {:credo, "~> 1.7.4", only: [:dev, :test], runtime: false},
      {:opentelemetry_api, "1.2.2"},
      {:opentelemetry, "1.3.1"},
      {:opentelemetry_exporter, "1.6.0"},
      {:jason, "~> 1.4"},
      {:jose, "~> 1.11"}
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"},
    ]
  end
end
