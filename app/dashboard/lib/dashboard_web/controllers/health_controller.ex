defmodule DashboardWeb.HealthController do
  use DashboardWeb, :controller

  alias Dashboard.OperatorHealth

  def live(conn, _params) do
    json(conn, OperatorHealth.live_report())
  end

  def ready(conn, _params) do
    report = OperatorHealth.readiness_report()
    conn = maybe_mark_unavailable(conn, OperatorHealth.ready?(report))
    json(conn, report)
  end

  def status(conn, _params) do
    report = OperatorHealth.status_report()
    conn = maybe_mark_unavailable(conn, OperatorHealth.ready?(report))
    json(conn, report)
  end

  defp maybe_mark_unavailable(conn, true), do: conn
  defp maybe_mark_unavailable(conn, false), do: put_status(conn, :service_unavailable)
end
