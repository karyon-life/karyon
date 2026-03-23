defmodule NervousSystem.MixProject do
  use Mix.Project

  def project do
    [
      app: :nervous_system,
      version: "0.1.0",
      build_path: "../_build",
      config_path: "../config/config.exs",
      deps_path: "../deps",
      lockfile: "../mix.lock",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      compilers: Mix.compilers(),
      rustler_crates: [],
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :telemetry],
      mod: {NervousSystem.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:chumak, "~> 1.4"},
      {:gnat, "~> 1.6"},
      {:protox, "~> 1.7"},
      {:telemetry, "~> 1.0"},
      {:phoenix_pubsub, "~> 2.1"},
      {:jason, "~> 1.4"},
      {:rustler, "~> 0.37.0", runtime: false},
      {:stream_data, "~> 1.0", only: :test}
    ]
  end
end
