defmodule Core.TestSupport.Chapter3Rubric do
  @moduledoc false

  @repo_root Path.expand("../../../../", __DIR__)

  def invariants do
    [
      %{
        id: :stem_cell_uses_declarative_executor_contracts,
        path: "app/core/lib/core/stem_cell.ex",
        required: ["resolve_executor(", "invoke_executor(", "executor_payload(", "executor_spec"],
        forbidden: ["Sandbox.Provisioner.capture_output", "\"firecracker_python\"", "\"error_test\""]
      },
      %{
        id: :sandbox_owns_firecracker_execution_adapter,
        path: "app/sandbox/lib/sandbox/executor.ex",
        required: ["def capture_output", "Sandbox.Provisioner.capture_output"],
        forbidden: ["Core.MotorDriver", "Core.StemCell"]
      },
      %{
        id: :dna_carries_executor_configuration,
        path: "app/core/priv/dna/motor_firecracker.yml",
        required: ["executor:", "module:", "function:"],
        forbidden: ["motor_executor:"]
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
