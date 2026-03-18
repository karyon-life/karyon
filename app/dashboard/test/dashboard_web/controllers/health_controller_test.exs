defmodule DashboardWeb.HealthControllerTest do
  use DashboardWeb.ConnCase, async: true

  defmodule ServiceHealthUp do
    def check_all(_opts \\ []) do
      %{
        overall: :ok,
        services: %{
          memgraph: %{status: :up, detail: :ok},
          xtdb: %{status: :up, detail: :ok},
          nats: %{status: :up, detail: :ok}
        }
      }
    end
  end

  defmodule ServiceHealthDegraded do
    def check_all(_opts \\ []) do
      %{
        overall: :degraded,
        services: %{
          memgraph: %{status: :up, detail: :ok},
          xtdb: %{status: :down, detail: :timeout},
          nats: %{status: :up, detail: :ok}
        }
      }
    end
  end

  setup do
    original = Application.get_env(:dashboard, :service_health_module)
    Application.put_env(:dashboard, :service_health_module, ServiceHealthUp)

    on_exit(fn ->
      if original do
        Application.put_env(:dashboard, :service_health_module, original)
      else
        Application.delete_env(:dashboard, :service_health_module)
      end
    end)

    :ok
  end

  test "GET /health/live returns liveness metadata", %{conn: conn} do
    conn = get(conn, ~p"/health/live")

    assert %{"status" => "ok", "release" => release, "node" => _node, "operator_brief" => brief} = json_response(conn, 200)
    assert is_map(release)
    assert brief["headline"] == "Organism ready"
    assert brief["format"] == "karyon.operator-output.v1"
  end

  test "GET /health/ready returns 200 when dependencies are up", %{conn: conn} do
    conn = get(conn, ~p"/health/ready")

    assert %{"status" => "ok", "services" => services, "operator_brief" => brief} = json_response(conn, 200)
    assert services["xtdb"]["status"] == "up"
    assert brief["summary"] == "All required services report healthy status across 3 dependency checks."
  end

  test "GET /health/status returns 503 when dependencies are degraded", %{conn: conn} do
    Application.put_env(:dashboard, :service_health_module, ServiceHealthDegraded)

    conn = get(conn, ~p"/health/status")

    assert %{
             "status" => "degraded",
             "services" => services,
             "runtime" => runtime,
             "release" => release,
             "operator_brief" => brief
           } = json_response(conn, 503)

    assert services["xtdb"]["status"] == "down"
    assert is_integer(runtime["beam_schedulers"])
    assert is_boolean(runtime["dashboard_server"])
    assert release["environment"] in ["test", "prod", "dev"]
    assert brief["headline"] == "Organism degraded"
    assert "Investigate xtdb before resuming plan-driven execution." in brief["directives"]
  end
end
