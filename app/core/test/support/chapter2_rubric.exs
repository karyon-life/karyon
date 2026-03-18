defmodule Core.TestSupport.Chapter2Rubric do
  @moduledoc false

  @repo_root Path.expand("../../../../", __DIR__)

  def invariants do
    [
      %{
        id: :cellular_discovery_uses_structured_pg_topics,
        path: "app/core/lib/core/stem_cell.ex",
        required: ["routing_topics(", "role_members(", "sense_gradient(", ":pg.join"],
        forbidden: ["create_pointer(", "weaken_edge("]
      },
      %{
        id: :predictive_processing_uses_weighted_expectations,
        path: "app/core/lib/core/stem_cell.ex",
        required: ["objective_weight", "expectation_lineage", "calculate_variational_free_energy", "prediction_error_signal("],
        forbidden: ["acc + (p * 1.0)"]
      },
      %{
        id: :planning_uses_typed_abstract_states,
        path: "app/core/lib/core/plan.ex",
        required: ["defmodule AbstractState", "target_state", "objective_priors", "predicted_state"],
        forbidden: []
      },
      %{
        id: :pain_receptor_filters_recursion_and_enriches_metadata,
        path: "app/nervous_system/lib/nervous_system/pain_receptor.ex",
        required: ["duplicate_fingerprint?(", "event_fingerprint", "event_source", "trace_id"],
        forbidden: []
      },
      %{
        id: :plasticity_uses_real_pathway_mutations,
        path: "app/rhizome/lib/rhizome/native.ex",
        required: ["def reinforce_pathway", "def prune_pathway", "MERGE (from)-[r:", "weight_delta"],
        forbidden: []
      }
    ]
  end

  def evaluate do
    Enum.map(invariants(), &evaluate_invariant/1)
  end

  def failures do
    evaluate()
    |> Enum.reject(& &1.pass?)
  end

  def format_failures([]), do: "all chapter 2 invariants satisfied"

  def format_failures(results) do
    Enum.map_join(results, "\n", fn result ->
      missing = Enum.map_join(result.missing, ", ", &inspect/1)
      forbidden_hits = Enum.map_join(result.forbidden_hits, ", ", &inspect/1)
      "#{result.id} failed in #{result.path}; missing=#{missing}; forbidden_hits=#{forbidden_hits}"
    end)
  end

  defp evaluate_invariant(invariant) do
    source = source_for(invariant.path)
    missing = Enum.reject(invariant.required, &String.contains?(source, &1))
    forbidden_hits = Enum.filter(invariant.forbidden, &String.contains?(source, &1))

    Map.merge(invariant, %{
      missing: missing,
      forbidden_hits: forbidden_hits,
      pass?: missing == [] and forbidden_hits == []
    })
  end

  defp source_for(path) do
    path
    |> Path.expand(@repo_root)
    |> File.read!()
  end
end
