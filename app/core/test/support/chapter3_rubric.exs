defmodule Core.TestSupport.Chapter3Rubric do
  @moduledoc false

  @repo_root Path.expand("../../../../", __DIR__)

  def invariants do
    [
      %{
        id: :stem_cell_uses_declarative_executor_contracts,
        path: "app/core/lib/core/stem_cell.ex",
        required: ["resolve_executor(", "invoke_executor(", "ExecutionIntent.from_action(", "executor_spec"],
        forbidden: ["\"error_test\""]
      },

      %{
        id: :tabula_rasa_baseline_is_linguistic,
        path: "priv/dna/tabula_rasa_stem_cell.yml",
        required: ["cell_type:", "subscriptions:", "utility_threshold:"],
        forbidden: ["compile", "patch_codebase", "executor:", "ast_parser:"]
      },
      %{
        id: :motor_babble_baseline_is_non_engineering,
        path: "priv/dna/motor_babble_cell.yml",
        required: ["cell_type:", "allowed_actions:", "babble"],
        forbidden: ["compile", "patch_codebase", "execute_plan", "executor:"]
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

  def format_failures([]), do: "all chapter 3 invariants satisfied"

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
