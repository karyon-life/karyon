defmodule Rhizome.MixProject do
  use Mix.Project

  def project do
    [
      app: :rhizome,
      version: "0.1.0",
      build_path: "../_build",
      config_path: "../config/config.exs",
      deps_path: "../deps",
      lockfile: "../mix.lock",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Rhizome.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:rustler, "~> 0.34.0"} # To be added later in Phase 4
    ]
  end
end
