defmodule Core.OperationalMaturity do
  @moduledoc """
  Typed operational maturity contract for Chapter 11 bootstrapping targets.

  This makes the organism's build, deploy, observe, and grounding targets
  explicit so later Chapter 11 and 12 work can validate against one shared
  maturity surface instead of scattering implicit assumptions.
  """

  alias Core.OperatorOutput
  alias Core.ServiceHealth

  @schema "karyon.operational-maturity.v2"
  @build_validation "cd /home/adrian/Projects/nexical/karyon/app && mix compile"
  @deploy_validation "cd /home/adrian/Projects/nexical/karyon/app && mix chapter10.conformance"
  @observe_validation "curl -i --max-time 5 http://127.0.0.1:3000/health/status"
  @ground_validation "cd /home/adrian/Projects/nexical/karyon/app && mix test test/core/operational_maturity_test.exs test/core/maturation_lifecycle_test.exs"

  def report(opts \\ []) do
    release = Keyword.get(opts, :release, release_metadata())
    dashboard_server = Keyword.get(opts, :dashboard_server, false)
    service_report = Keyword.get_lazy(opts, :service_report, fn -> ServiceHealth.check_all() end)
    dna_root = Keyword.get(opts, :dna_root, dna_root())

    targets = %{
      build: build_target(service_report, release),
      deploy: deploy_target(service_report, release),
      observe: observe_target(service_report, dashboard_server),
      distribute: grounding_target(dna_root)
    }

    %{
      schema: @schema,
      overall: overall_status(targets),
      release: release,
      targets: targets
    }
  end

  defp dna_root do
    Application.get_env(:core, :dna_root, Path.expand("../../../../priv/dna", __DIR__))
  end

  defp build_target(service_report, release) do
    preflight_status = get_in(service_report, [:runtime, :preflight_status]) || :unknown
    strict_preflight = get_in(service_report, [:runtime, :strict_preflight]) || false
    calibrated = get_in(service_report, [:runtime, :calibrated]) || false

    blockers =
      []
      |> maybe_add(match?({:degraded, _}, preflight_status), "stabilize preflight invariants before promoting release candidates")
      |> maybe_add(preflight_status == :unknown, "connect the metabolic daemon so boot evidence is visible in the maturity surface")
      |> maybe_add(not calibrated, "allow the metabolic daemon to calibrate hardware baselines before treating the organism as bootstrapped")

    %{
      status: status_from_blockers(blockers),
      objective: "Compile and boot the sterile engine with explicit preflight evidence.",
      validation: @build_validation,
      next_phase: "C11-S02",
      blockers: blockers,
      evidence: %{
        preflight_status: format_preflight(preflight_status),
        strict_preflight: strict_preflight,
        calibrated: calibrated,
        release_environment: Map.get(release, :environment, "unknown")
      }
    }
  end

  defp deploy_target(service_report, release) do
    overall = Map.get(service_report, :overall, :degraded)
    down_services =
      service_report
      |> Map.get(:services, %{})
      |> Enum.filter(fn {_name, %{status: status}} -> status != :up end)
      |> Enum.map(fn {name, _} -> to_string(name) end)

    blockers =
      []
      |> maybe_add(overall != :ok, "restore dependency readiness before treating the organism as deployable")
      |> Enum.concat(Enum.map(down_services, &"service down=#{&1}"))

    %{
      status: status_from_blockers(blockers),
      objective: "Keep release, dependency, and ATP admission state aligned for deployable runtime behavior.",
      validation: @deploy_validation,
      next_phase: "C11-S03",
      blockers: blockers,
      evidence: %{
        service_overall: to_string(overall),
        service_count: map_size(Map.get(service_report, :services, %{})),
        release_name: Map.get(release, :name, "dev"),
        release_version: Map.get(release, :version, "dev")
      }
    }
  end

  defp observe_target(service_report, dashboard_server) do
    operator_surface_ready? =
      match?(
        {:ok, brief} when is_map(brief),
        OperatorOutput.render_status_report(%{
          status: if(Map.get(service_report, :overall, :degraded) == :ok, do: :ok, else: :degraded),
          services: Map.get(service_report, :services, %{}),
          runtime: %{beam_schedulers: :erlang.system_info(:schedulers_online), dashboard_server: dashboard_server}
        })
      )

    blockers =
      []
      |> maybe_add(not operator_surface_ready?, "repair the bounded operator output surface before relying on health observability")

    %{
      status: status_from_blockers(blockers),
      objective: "Expose a bounded operator-visible health and observability surface.",
      validation: @observe_validation,
      next_phase: "C11-S03",
      blockers: blockers,
      evidence: %{
        operator_surface_ready: operator_surface_ready?,
        dashboard_server: dashboard_server,
        telemetry_runtime_visible: Map.has_key?(Map.get(service_report, :runtime, %{}), :metabolism)
      }
    }
  end

  defp grounding_target(dna_root) do
    expanded_root = Path.expand(dna_root)
    required = [
      "sensory_pooler_cell.yml",
      "motor_babble_cell.yml",
      "tabula_rasa_stem_cell.yml"
    ]

    forbidden = [
      "python_executor.yml",
      "rust_architect.yml",
      "architect_planner.yml",
      "eye_python.yml"
    ]

    missing_required = Enum.reject(required, &(File.exists?(Path.join(expanded_root, &1))))
    lingering_engineering_dna = Enum.filter(forbidden, &(File.exists?(Path.join(expanded_root, &1))))

    blockers =
      []
      |> maybe_add(not File.dir?(expanded_root), "create #{expanded_root} so the grounding baseline has a canonical DNA surface")
      |> maybe_add(missing_required != [], "add the baseline linguistic DNA set before claiming grounding readiness")
      |> maybe_add(lingering_engineering_dna != [], "purge engineering DNA from the canonical grounding surface before claiming sterilization")

    %{
      status: status_from_blockers(blockers),
      objective: "Expose a sterilized linguistic grounding baseline instead of a software distribution blueprint.",
      validation: @ground_validation,
      next_phase: "C11-S04",
      blockers: blockers,
      evidence: %{
        dna_root: expanded_root,
        dna_root_exists: File.dir?(expanded_root),
        baseline_dna_missing: missing_required,
        forbidden_engineering_dna: lingering_engineering_dna
      }
    }
  end

  defp overall_status(targets) do
    if Enum.all?(targets, fn {_name, target} -> target.status == :ok end) do
      :ok
    else
      :degraded
    end
  end

  defp release_metadata do
    %{
      name: System.get_env("RELEASE_NAME") || "dev",
      version: System.get_env("RELEASE_VSN") || "dev",
      environment: Application.get_env(:dashboard, :env, System.get_env("MIX_ENV") || "prod") |> to_string()
    }
  end

  defp status_from_blockers([]), do: :ok
  defp status_from_blockers(_), do: :degraded

  defp format_preflight(:ok), do: "ok"
  defp format_preflight(:unknown), do: "unknown"
  defp format_preflight({:degraded, reason}), do: "degraded:#{reason}"
  defp format_preflight(other), do: to_string(other)

  defp maybe_add(list, true, entry), do: list ++ [entry]
  defp maybe_add(list, false, _entry), do: list
end
