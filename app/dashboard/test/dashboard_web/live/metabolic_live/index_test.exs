defmodule DashboardWeb.MetabolicLive.IndexTest do
  use DashboardWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  defmodule OrganismObservabilityStub do
    def report(_opts \\ []) do
      %{
        schema: "karyon.organism-observability.v1",
        overall: :ok,
        topology: %{layer_count: 3, layers: [%{layer: "working_graph", store: "memgraph", operation_count: 7}]},
        organism: %{active_cell_count: 5},
        graph: %{prediction_error_count: 2, consolidation_supernode_count: 1, workspace_coordination_count: 1},
        temporal: %{recent_execution_outcome_count: 4, sovereignty_event_count: 1},
        sovereignty: %{
          top_hard_mandate: %{name: "preserve_homeostasis", weight: 1.4},
          top_value: %{name: "safety", weight: 1.2},
          top_need: %{name: "continuity", weight: 1.1},
          top_objective: %{name: "repair", weight: 1.3}
        }
      }
    end
  end

  setup do
    original = Application.get_env(:dashboard, :organism_observability_module)
    Application.put_env(:dashboard, :organism_observability_module, OrganismObservabilityStub)

    on_exit(fn ->
      if original do
        Application.put_env(:dashboard, :organism_observability_module, original)
      else
        Application.delete_env(:dashboard, :organism_observability_module)
      end
    end)

    :ok
  end

  test "renders live metabolic updates from pubsub", %{conn: conn} do
    {:ok, view, html} = live(conn, ~p"/metabolism")

    assert html =~ "Karyon Homeostasis Monitor"
    assert html =~ "unavailable"
    assert html =~ "System Pressure: LOW"
    assert html =~ "Active Cells"
    assert html =~ "Prediction Errors"
    assert html =~ "preserve_homeostasis=1.40"

    Phoenix.PubSub.broadcast(
      Dashboard.PubSub,
      "metabolic_flux",
      {:metabolic_update,
       %{
         l3_misses: 9_999,
         run_queue: 7,
         iops: 1_234,
         pressure: :high,
         atp: 0.4,
         preflight_status: {:degraded, "memory topology unavailable"}
       }}
    )

    rendered = render(view)

    assert rendered =~ "9999"
    assert rendered =~ "7"
    assert rendered =~ "1234"
    assert rendered =~ "System Pressure: HIGH"
    assert rendered =~ "40%"
    assert rendered =~ "Sleep SuperNodes"
    assert rendered =~ "Recent execution outcomes: 4"
  end
end
