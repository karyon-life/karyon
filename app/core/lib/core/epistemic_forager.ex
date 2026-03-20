defmodule Core.EpistemicForager do
  @moduledoc """
  Bounded low-confidence probing path for idle-time epistemic foraging.
  """

  alias Core.ExecutionIntent
  alias Core.MetabolismPolicy
  alias Core.Plan
  alias Core.Plan.AbstractState
  alias Core.Plan.Attractor
  alias Core.Plan.Step

  @default_executor %{"module" => "Core.OperatorSandboxExecutor", "function" => "execute_plan"}

  def forage_idle(opts \\ []) do
    policy = Keyword.get(opts, :policy, MetabolismPolicy.current_policy())

    with :ok <- ensure_idle(policy),
         {:ok, candidate} <- next_candidate(opts),
         {:ok, plan} <- build_plan(candidate, policy),
         {:ok, intent} <- build_intent(plan, opts),
         {:ok, result} <- executor_module(opts).execute_plan(ExecutionIntent.to_map(intent)),
         {:ok, persisted} <- memory_module(opts).submit_epistemic_foraging_event(build_event(candidate, intent, result, plan)) do
      {:ok, %{candidate: candidate, intent: intent, result: result, persisted: persisted}}
    end
  end

  def next_candidate(opts \\ []) do
    query = %{
      label: Keyword.get(opts, :label, "SuperNode"),
      threshold: Keyword.get(opts, :threshold, 0.5),
      limit: Keyword.get(opts, :limit, 5)
    }

    case memory_module(opts).query_low_confidence_candidates(query) do
      {:ok, [candidate | _]} -> {:ok, candidate}
      {:ok, []} -> {:error, :no_low_confidence_candidates}
      {:error, reason} -> {:error, reason}
    end
  end

  def build_plan(candidate, policy \\ MetabolismPolicy.current_policy()) when is_map(candidate) do
    candidate_id = Map.get(candidate, "id", "unknown_candidate")
    confidence = normalize_float(Map.get(candidate, "confidence", 0.0))
    label = Map.get(candidate, "label", "SuperNode")
    summary = Map.get(candidate, "summary", "")

    plan =
      %Plan{
        attractor: %Attractor{
          id: "forage:#{candidate_id}",
          kind: "EpistemicForaging",
          properties: %{
            "candidate_id" => candidate_id,
            "candidate_label" => label,
            "source_confidence" => confidence,
            "mode" => "idle_probe"
          },
          target_state: %AbstractState{
            entity: candidate_id,
            phase: "explore",
            summary: if(summary == "", do: "probe:#{candidate_id}", else: summary),
            attributes: %{"candidate_label" => label, "source_confidence" => confidence},
            needs: %{"exploration" => 1.0},
            values: %{"learning" => 0.8},
            objective_priors: %{"refinement" => 0.7}
          },
          objective_priors: %{"refinement" => 0.7},
          needs: %{"exploration" => 1.0},
          values: %{"learning" => 0.8}
        },
        steps: [
          %Step{
            id: "probe:#{candidate_id}",
            action: "probe_low_confidence_edge",
            params: %{
              "candidate_id" => candidate_id,
              "candidate_label" => label,
              "source_confidence" => confidence,
              "probe_mode" => "idle_probe"
            },
            predicted_state: %AbstractState{
              entity: candidate_id,
              phase: "probe",
              summary: "confidence_update:#{candidate_id}",
              attributes: %{"candidate_label" => label},
              needs: %{"exploration" => 1.0},
              values: %{"learning" => 0.8},
              objective_priors: %{"refinement" => 0.7}
            }
          }
        ],
        transition_delta: %{
          foraging: %{
            "mode" => "idle_probe",
            "candidate_id" => candidate_id,
            "candidate_label" => label,
            "source_confidence" => confidence
          }
        },
        created_at: System.system_time(:second)
      }

    admission = MetabolismPolicy.plan_profile(plan, policy)

    if MetabolismPolicy.admitted?(admission) do
      {:ok,
       %Plan{
         plan
         | transition_delta:
             plan.transition_delta
             |> Map.put(:metabolism_policy, MetabolismPolicy.to_map(policy))
             |> Map.put(:metabolism_admission, admission)
             |> Map.put(:scheduling, %{"lane" => admission["lane"], "priority_score" => admission["priority_score"]})
       }}
    else
      {:error, :insufficient_atp_budget}
    end
  end

  def build_intent(%Plan{} = plan, opts \\ []) do
    ExecutionIntent.from_plan(
      plan,
      %{"cell_type" => "epistemic_forager", "id" => "epistemic_forager"},
      Keyword.get(opts, :executor_spec, @default_executor)
    )
  end

  defp ensure_idle(policy) do
    exploration_need = Map.get(policy.needs, "exploration", 0.0)

    cond do
      policy.pressure != :low -> {:error, :organism_not_idle}
      exploration_need < 0.5 -> {:error, :exploration_suppressed}
      true -> :ok
    end
  end

  defp build_event(candidate, intent, result, plan) do
    source_confidence = normalize_float(Map.get(candidate, "confidence", 0.0))
    confidence_delta = confidence_delta(result)
    updated_confidence = clamp_confidence(source_confidence + confidence_delta)

    %{
      "candidate_id" => Map.get(candidate, "id", "unknown_candidate"),
      "candidate_label" => Map.get(candidate, "label", "SuperNode"),
      "mode" => "idle_probe",
      "source_confidence" => source_confidence,
      "updated_confidence" => updated_confidence,
      "confidence_delta" => confidence_delta,
      "outcome_status" => outcome_status(result),
      "intent_id" => intent.id,
      "plan_attractor_id" => plan.attractor.id,
      "vm_id" => Map.get(result, :vm_id) || Map.get(result, "vm_id", "unknown_vm")
    }
  end

  defp confidence_delta(%{status: :exited, exit_code: 0}), do: 0.2
  defp confidence_delta(%{"status" => "exited", "exit_code" => 0}), do: 0.2
  defp confidence_delta(_result), do: -0.2

  defp outcome_status(%{status: status}) when is_atom(status), do: Atom.to_string(status)
  defp outcome_status(%{"status" => status}) when is_binary(status), do: status
  defp outcome_status(_result), do: "unknown"

  defp clamp_confidence(value), do: value |> max(0.0) |> min(1.0) |> Float.round(3)

  defp normalize_float(value) when is_float(value), do: value
  defp normalize_float(value) when is_integer(value), do: value * 1.0
  defp normalize_float(value) when is_binary(value) do
    case Float.parse(value) do
      {parsed, _} -> parsed
      :error -> 0.0
    end
  end

  defp normalize_float(_value), do: 0.0

  defp memory_module(opts), do: Keyword.get(opts, :memory_module, Rhizome.Memory)
  defp executor_module(opts), do: Keyword.get(opts, :executor_module, Core.OperatorSandboxExecutor)
end
