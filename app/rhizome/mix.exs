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
      compilers: Mix.compilers(),
      rustler_crates: [
        rhizome_nif: [
          path: "native/rhizome_nif",
          mode: (if Mix.env() == :prod, do: :release, else: :debug),
          crate: :rhizome_nif
        ]
      ],
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Rhizome.Application, []}
    ]
  end

  defp deps do
    [
      {:rustler, "~> 0.37.0", runtime: false}
    ]
  end
end
