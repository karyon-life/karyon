defmodule App.MixProject do
  use Mix.Project

  def project do
    [
      apps_path: ".",
      apps: [:core, :nervous_system, :sandbox, :rhizome, :sensory, :dashboard],
      version: "0.1.0",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      releases: releases()
    ]
  end

  defp deps do
    [
      {:stream_data, "~> 1.0", only: :test},
      {:rustler, "~> 0.37.0", runtime: false}
    ]
  end

  defp releases do
    [
      karyon: [
        applications: [
          core: :permanent,
          nervous_system: :permanent,
          sandbox: :permanent,
          rhizome: :permanent,
          sensory: :permanent,
          dashboard: :permanent
        ]
      ]
    ]
  end
end
