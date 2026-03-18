defmodule Dashboard.OperatorHealth do
  @moduledoc """
  Operator-facing health and readiness reporting for the running organism.
  """

  @service_health_module Core.ServiceHealth

  def live_report do
    report = %{
      status: :ok,
      release: release_metadata(),
      node: Atom.to_string(Node.self())
    }

    Map.put(report, :operator_brief, render_operator_brief(report))
  end

  def readiness_report(opts \\ []) do
    report = service_health_module().check_all(opts)

    report = %{
      status: if(report.overall == :ok, do: :ok, else: :degraded),
      release: release_metadata(),
      services: report.services
    }

    Map.put(report, :operator_brief, render_operator_brief(report))
  end

  def status_report(opts \\ []) do
    report = readiness_report(opts)

    enriched =
      Map.merge(report, %{
        runtime: %{
          beam_schedulers: :erlang.system_info(:schedulers_online),
          uptime_ms: :erlang.statistics(:wall_clock) |> elem(0),
          dashboard_server: dashboard_server_enabled?()
        }
      })

    Map.put(enriched, :operator_brief, render_operator_brief(enriched))
  end

  def ready?(report), do: report.status == :ok

  defp service_health_module do
    Application.get_env(:dashboard, :service_health_module, @service_health_module)
  end

  defp dashboard_server_enabled? do
    Application.get_env(:dashboard, DashboardWeb.Endpoint, [])
    |> Keyword.get(:server, false)
  end

  defp release_metadata do
    %{
      name: System.get_env("RELEASE_NAME") || "dev",
      version: System.get_env("RELEASE_VSN") || "dev",
      environment: config_env()
    }
  end

  defp config_env do
    Application.get_env(:dashboard, :env, System.get_env("MIX_ENV") || "prod")
    |> to_string()
  end

  defp render_operator_brief(report) do
    case Core.OperatorOutput.render_status_report(report) do
      {:ok, brief} -> brief
      {:error, _reason} -> fallback_operator_brief(report)
    end
  end

  defp fallback_operator_brief(report) do
    %{
      channel: "operator_brief",
      format: "karyon.operator-output.v1",
      severity: if(report.status == :ok, do: :ok, else: :degraded),
      headline: "Organism status unavailable",
      summary: "The operator-output layer could not classify the current report.",
      directives: ["Inspect the typed report payload before approving action."],
      facts: ["status=#{report.status}"]
    }
  end
end
