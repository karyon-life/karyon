defmodule Dashboard.OperatorHealth do
  @moduledoc """
  Operator-facing health and readiness reporting for the running organism.
  """

  @service_health_module Core.ServiceHealth

  def live_report do
    %{
      status: :ok,
      release: release_metadata(),
      node: Atom.to_string(Node.self())
    }
  end

  def readiness_report(opts \\ []) do
    report = service_health_module().check_all(opts)

    %{
      status: if(report.overall == :ok, do: :ok, else: :degraded),
      release: release_metadata(),
      services: report.services
    }
  end

  def status_report(opts \\ []) do
    report = readiness_report(opts)

    Map.merge(report, %{
      runtime: %{
        beam_schedulers: :erlang.system_info(:schedulers_online),
        uptime_ms: :erlang.statistics(:wall_clock) |> elem(0),
        dashboard_server: dashboard_server_enabled?()
      }
    })
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
end
