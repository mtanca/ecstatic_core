defmodule EcstaticCore.MixProject do
  use Mix.Project

  def project do
    [
      app: :ecstatic_core,
      version: "0.1.0",
      elixir: "~> 1.8",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [coveralls: :test]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:excoveralls, "~> 0.10", only: :test},
      {:typed_struct, "~> 0.1.4"},
      {:dialyxir, "~> 0.5", only: [:dev], runtime: false},
      {:credo, "~> 1.0.0", only: [:dev, :test], runtime: false},
      {:uuid, "~> 1.1"},
      {:faker, "~> 0.12", only: [:test, :dev]},
      {:swarm, "~> 3.4"},
      {:ecto_sql, "~> 3.1"},
      {:postgrex, ">= 0.0.0"}
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
    ]
  end
end
