defmodule Dashboard.OrganismObservabilityTest do
  use ExUnit.Case, async: true

  alias Dashboard.OrganismObservability

  defmodule MemoryStub do
    def topology_contract do
      %{
        working_graph: %{layer: :working_graph, store: "memgraph", access: :read_write, purpose: "live graph", operations: [:query_working_memory]},
        temporal_archive: %{layer: :temporal_archive, store: "xtdb", access: :read_write, purpose: "archive", operations: [:query_archive]}
      }
    end

    def query_working_memory(%{label: "PredictionError"}), do: {:ok, [%{"id" => "pe-1"}, %{"id" => "pe-2"}]}
    def query_working_memory(%{label: "SleepSuperNode"}), do: {:ok, [%{"id" => "sleep-1"}]}
    def query_working_memory(%{label: "CrossWorkspaceCoordination"}), do: {:ok, [%{"id" => "coord-1"}]}
    def query_working_memory(%{label: "ObjectiveProjection"}), do: {:ok, [%{"id" => "obj-1"}]}

    def query_archive(%{"query" => %{"where" => [["?e", "status", "success"]]}}), do: {:ok, [%{"xt/id" => "a"}, %{"xt/id" => "b"}]}
    def query_archive(%{"query" => %{"where" => [["?e", "decision", "refuse"]]}}), do: {:ok, [%{"xt/id" => "c"}]}
  end

  test "report/1 surfaces topology, graph, temporal, organism, and sovereign state" do
    report =
      OrganismObservability.report(
        memory_module: MemoryStub,
        active_cells_fun: fn -> [] end,
        sovereignty_fun: fn ->
          %{
            schema: "karyon.sovereignty.v1",
            hard_mandates: %{"preserve_homeostasis" => 1.4},
            soft_values: %{"safety" => 1.2},
            evolving_needs: %{"continuity" => 1.1},
            objective_priors: %{"repair" => 1.3}
          }
        end
      )

    assert report.schema == "karyon.organism-observability.v1"
    assert report.topology.layer_count == 2
    assert report.graph.prediction_error_count == 2
    assert report.graph.consolidation_supernode_count == 1
    assert report.temporal.recent_execution_outcome_count == 2
    assert report.temporal.sovereignty_event_count == 1
    assert report.organism.active_cell_count == 0
    assert report.sovereignty.top_hard_mandate.name == "preserve_homeostasis"
  end
end
