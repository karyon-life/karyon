defmodule Core.TestSupport.ArchitectureRubric do
  @moduledoc false

  @repo_root Path.expand("../../../../", __DIR__)
  @forbidden_prompt_primitives ["run_prompt", "chat_completion", "completion", "prompt_response"]

  def invariants do
    [
      %{
        id: :planning_reads_graph_state,
        description: "planning remains graph-backed instead of prompt-driven",
        path: "app/core/lib/core/motor_driver.ex",
        required: ["def sequence_plan", "Rhizome.Native.memgraph_query", "fetch_causal_chain"],
        forbidden: @forbidden_prompt_primitives
      },
      %{
        id: :cells_retain_and_persist_local_state,
        description: "execution cells retain local expectations and persist outcomes",
        path: "app/core/lib/core/stem_cell.ex",
        required: ["expectations:", "beliefs:", "hydrate_state", "checkpoint_state", "persist_execution_outcome"],
        forbidden: @forbidden_prompt_primitives
      },
      %{
        id: :memory_projects_execution_outcomes,
        description: "execution outcomes flow into temporal and graph memory",
        path: "app/rhizome/lib/rhizome/memory.ex",
        required: ["def submit_execution_outcome", "submit_xtdb", "project_execution_outcome"],
        forbidden: ["binary_to_term(", "Process.get("]
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

  def format_failures([]), do: "all architecture invariants satisfied"

  def format_failures(results) do
    Enum.map_join(results, "\n", fn result ->
      missing =
        result.missing
        |> Enum.map_join(", ", &inspect/1)

      forbidden_hits =
        result.forbidden_hits
        |> Enum.map_join(", ", &inspect/1)

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
