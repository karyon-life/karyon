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

  defmodule OperationalMaturityStub do
    def report(_opts \\ []) do
      %{
        schema: "karyon.operational-maturity.v1",
        overall: :ok,
        targets: %{
          build: %{status: :ok},
          deploy: %{status: :ok},
          observe: %{status: :ok},
          distribute: %{status: :degraded}
        }
      }
    end
  end

  defmodule OrganismObservabilityStub do
    def report(_opts \\ []) do
      %{
        schema: "karyon.organism-observability.v1",
        overall: :ok,
        topology: %{layer_count: 3},
        organism: %{active_cell_count: 5},
        graph: %{prediction_error_count: 2, consolidation_supernode_count: 1, workspace_coordination_count: 1},
        temporal: %{recent_execution_outcome_count: 4, sovereignty_event_count: 1},
        sovereignty: %{schema: "karyon.sovereignty.v1"}
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
    original_maturity = Application.get_env(:dashboard, :operational_maturity_module)
    original_observability = Application.get_env(:dashboard, :organism_observability_module)
    Application.put_env(:dashboard, :service_health_module, ServiceHealthUp)
    Application.put_env(:dashboard, :operational_maturity_module, OperationalMaturityStub)
    Application.put_env(:dashboard, :organism_observability_module, OrganismObservabilityStub)

    on_exit(fn ->
      if original do
        Application.put_env(:dashboard, :service_health_module, original)
      else
        Application.delete_env(:dashboard, :service_health_module)
      end

      if original_maturity do
        Application.put_env(:dashboard, :operational_maturity_module, original_maturity)
      else
        Application.delete_env(:dashboard, :operational_maturity_module)
      end

      if original_observability do
        Application.put_env(:dashboard, :organism_observability_module, original_observability)
      else
        Application.delete_env(:dashboard, :organism_observability_module)
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

    assert %{"status" => "ok", "services" => services, "maturity" => maturity, "observability" => observability, "operator_brief" => brief} = json_response(conn, 200)
    assert services["xtdb"]["status"] == "up"
    assert maturity["schema"] == "karyon.operational-maturity.v1"
    assert maturity["targets"]["build"]["status"] == "ok"
    assert observability["schema"] == "karyon.organism-observability.v1"
    assert observability["organism"]["active_cell_count"] == 5
    assert brief["summary"] == "All required services report healthy status across 3 dependency checks."
  end

  test "GET /health/status returns 503 when dependencies are degraded", %{conn: conn} do
    Application.put_env(:dashboard, :service_health_module, ServiceHealthDegraded)

    conn = get(conn, ~p"/health/status")

    assert %{
             "status" => "degraded",
             "services" => services,
             "maturity" => maturity,
             "observability" => observability,
             "runtime" => runtime,
             "release" => release,
             "operator_brief" => brief
           } = json_response(conn, 503)

    assert services["xtdb"]["status"] == "down"
    assert maturity["targets"]["distribute"]["status"] == "degraded"
    assert observability["graph"]["prediction_error_count"] == 2
    assert is_integer(runtime["beam_schedulers"])
    assert is_boolean(runtime["dashboard_server"])
    assert release["environment"] in ["test", "prod", "dev"]
    assert brief["headline"] == "Organism degraded"
    assert "Investigate xtdb before resuming plan-driven execution." in brief["directives"]
  end
end
