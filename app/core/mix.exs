defmodule Core.MixProject do
  use Mix.Project

  def project do
    [
      app: :core,
      version: "0.1.0",
      build_path: "../_build",
      config_path: "../config/config.exs",
      deps_path: "../deps",
      lockfile: "../mix.lock",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      compilers: Mix.compilers(),
      rustler_crates: [
        metabolic_nif: [
          path: "native/metabolic_nif",
          mode: (if Mix.env() == :prod, do: :release, else: :debug),
          crate: :metabolic_nif
        ]
      ],
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Core.Application, []}
    ]
  end

  defp deps do
    [
      {:yaml_elixir, "~> 2.9"},
      {:rustler, "~> 0.37.0", runtime: false}
    ]
  end
end
