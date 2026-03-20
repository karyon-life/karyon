defmodule Core.OperationalMaturityTest do
  use ExUnit.Case, async: true

  alias Core.OperationalMaturity

  test "report/1 makes build, deploy, observe, and grounding targets explicit" do
    dna_root = Path.join(System.tmp_dir!(), "karyon_operational_maturity/dna")
    File.mkdir_p!(dna_root)

    Enum.each([
      "sensory_pooler_cell.yml",
      "motor_babble_cell.yml",
      "tabula_rasa_stem_cell.yml"
    ], fn file ->
      File.write!(Path.join(dna_root, file), "cell_type: placeholder\n")
    end)

    on_exit(fn -> File.rm_rf(Path.join(System.tmp_dir!(), "karyon_operational_maturity")) end)

    report =
      OperationalMaturity.report(
        service_report: %{
          overall: :ok,
          services: %{
            memgraph: %{status: :up, detail: :ok},
            xtdb: %{status: :up, detail: :ok},
            nats: %{status: :up, detail: :ok}
          },
          runtime: %{
            metabolism: %{"pressure" => "low"},
            admission: %{"spawn_budget" => 1.0, "pressure" => "low"},
            preflight_status: :ok,
            calibrated: true,
            strict_preflight: true
          }
        },
        dashboard_server: true,
        dna_root: dna_root,
        release: %{name: "karyon", version: "1.0.0", environment: "test"}
      )

    assert report.schema == "karyon.operational-maturity.v2"
    assert report.overall == :ok
    assert report.targets.build.status == :ok
    assert report.targets.deploy.status == :ok
    assert report.targets.observe.status == :ok
    assert report.targets.distribute.status == :ok
    assert report.targets.build.validation =~ "mix compile"
    assert report.targets.distribute.evidence.dna_root_exists
    assert report.targets.distribute.evidence.baseline_dna_missing == []
  end

  test "report/1 surfaces blockers when boot and grounding evidence are missing" do
    report =
      OperationalMaturity.report(
        service_report: %{
          overall: :degraded,
          services: %{
            memgraph: %{status: :up, detail: :ok},
            xtdb: %{status: :down, detail: :timeout},
            nats: %{status: :up, detail: :ok}
          },
          runtime: %{
            metabolism: %{"pressure" => "medium"},
            admission: %{"spawn_budget" => 0.7, "pressure" => "medium"},
            preflight_status: {:degraded, "numa drift"},
            calibrated: false,
            strict_preflight: false
          }
        },
        dashboard_server: false,
        dna_root: Path.join(System.tmp_dir!(), "karyon_operational_maturity/missing"),
        release: %{name: "dev", version: "dev", environment: "test"}
      )

    assert report.overall == :degraded
    assert report.targets.build.status == :degraded
    assert "stabilize preflight invariants before promoting release candidates" in report.targets.build.blockers
    assert report.targets.deploy.status == :degraded
    assert "service down=xtdb" in report.targets.deploy.blockers
    assert report.targets.distribute.status == :degraded
    assert Enum.any?(report.targets.distribute.blockers, &String.contains?(&1, "canonical DNA surface"))
  end
end
