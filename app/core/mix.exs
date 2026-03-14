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
      compilers: (if Mix.env() == :test, do: [], else: [:rustler]) ++ Mix.compilers(),
      rustler_crates: [
        metabolic_nif: [
          path: "native/metabolic_nif",
          mode: (if Mix.env() == :prod, do: :release, else: :debug)
        ]
      ],
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Core.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # process grouping relies on the built-in :pg module from Erlang.
      {:yaml_elixir, "~> 2.9"},
      {:rustler, "~> 0.34.0", runtime: false}
    ]
  end
end
