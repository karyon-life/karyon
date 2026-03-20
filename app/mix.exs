defmodule App.MixProject do
  use Mix.Project

  def project do
    [
      apps_path: ".",
      apps: [:core, :nervous_system, :operator_environment, :rhizome, :sensory, :dashboard],
      version: "0.1.0",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      releases: releases(),
      aliases: aliases()
    ]
  end

  def cli do
    [
      preferred_envs: [
        "chapter12.conformance": :test,
        "chapter11.conformance": :test,
        "chapter1.conformance": :test,
        "biology.invariants": :test,
        "chapter10.conformance": :test,
        "chapter9.conformance": :test,
        "chapter2.conformance": :test,
        "chapter8.conformance": :test,
        "chapter7.conformance": :test,
        "chapter6.conformance": :test,
        "chapter5.conformance": :test,
        "chapter4.conformance": :test,
        "chapter3.conformance": :test,
        "subsystem.contracts": :test
      ]
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
          operator_environment: :permanent,
          rhizome: :permanent,
          sensory: :permanent,
          dashboard: :permanent
        ]
      ]
    ]
  end

  defp aliases do
    [
      "chapter12.conformance": ["run --no-start test/chapter12_conformance_runner.exs"],
      "chapter11.conformance": ["run --no-start test/chapter11_conformance_runner.exs"],
      "chapter1.conformance": ["run --no-start test/chapter1_conformance_runner.exs"],
      "biology.invariants": ["run --no-start test/biology_first_invariants_runner.exs"],
      "chapter10.conformance": ["run --no-start test/chapter10_conformance_runner.exs"],
      "chapter9.conformance": ["run --no-start test/chapter9_conformance_runner.exs"],
      "chapter2.conformance": ["run --no-start test/chapter2_conformance_runner.exs"],
      "chapter8.conformance": ["run --no-start test/chapter8_conformance_runner.exs"],
      "chapter7.conformance": ["run --no-start test/chapter7_conformance_runner.exs"],
      "chapter6.conformance": ["run --no-start test/chapter6_conformance_runner.exs"],
      "chapter5.conformance": ["run --no-start test/chapter5_conformance_runner.exs"],
      "chapter4.conformance": ["run --no-start test/chapter4_conformance_runner.exs"],
      "chapter3.conformance": ["run --no-start test/chapter3_conformance_runner.exs"],
      "subsystem.contracts": ["run --no-start test/subsystem_contracts_runner.exs"]
    ]
  end

end
