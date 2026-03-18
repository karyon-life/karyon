defmodule Sensory.MixProject do
  use Mix.Project

  def project do
    [
      app: :sensory,
      version: "0.1.0",
      build_path: "../_build",
      config_path: "../config/config.exs",
      deps_path: "../deps",
      lockfile: "../mix.lock",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      compilers: Mix.compilers(),
      rustler_crates: [
        sensory_nif: [
          path: "native/sensory_nif",
          mode: (if Mix.env() == :prod, do: :release, else: :debug),
          crate: :sensory_nif
        ]
      ],
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Sensory.Application, []}
    ]
  end

  defp deps do
    [
      {:jason, "~> 1.4"},
      {:rustler, "~> 0.37.0", runtime: false},
      {:rhizome, in_umbrella: true}
    ]
  end
end
