defmodule Sandbox.MixProject do
  use Mix.Project

  def project do
    [
      app: :sandbox,
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
      mod: {Sandbox.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # Dependencies for communicating with firectl or unix sockets (Phase 5)
    ]
  end
end
