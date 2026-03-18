defmodule Core.SimulationDaemon do
  @moduledoc """
  Dream-state daemon that replays recent successful execution telemetry as
  bounded architectural permutations inside isolated sandboxes.
  """

  use GenServer
  require Logger

  alias Core.ExecutionIntent
  alias Core.MetabolismPolicy
  alias Core.Plan
  alias Core.Plan.AbstractState
  alias Core.Plan.Attractor
  alias Core.Plan.Step

  @sleep_cycle_interval_ms 60_000
  @default_executor %{"module" => "Sandbox.Executor", "function" => "execute_plan"}

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :name, __MODULE__))
  end

  def run_once(opts \\ []) do
    perform_dream_cycle(opts)
  end

  @impl true
  def init(opts) do
    Logger.info("[SimulationDaemon] Dream-state daemon initialized.")
    schedule_next_check(Keyword.get(opts, :interval_ms, @sleep_cycle_interval_ms))
    {:ok, %{opts: opts}}
  end

  @impl true
  def handle_info(:run_dream_cycle, state) do
    perform_dream_cycle(state.opts)
    schedule_next_check(Keyword.get(state.opts, :interval_ms, @sleep_cycle_interval_ms))
    {:noreply, state}
  end

  defp schedule_next_check(interval_ms) do
    Process.send_after(self(), :run_dream_cycle, interval_ms)
  end

  defp perform_dream_cycle(opts) do
    policy = Keyword.get(opts, :policy, MetabolismPolicy.current_policy())

    with :ok <- ensure_dream_window(policy),
         {:ok, outcomes} <- fetch_recent_outcomes(opts),
         {:ok, source_outcome} <- select_source_outcome(outcomes),
         {:ok, plan} <- build_permutation_plan(source_outcome, policy),
         {:ok, intent} <- build_dream_intent(plan, opts),
         {:ok, result} <- executor_module(opts).execute_plan(ExecutionIntent.to_map(intent)),
         {:ok, persisted} <-
           memory_module(opts).submit_simulation_daemon_event(build_simulation_event(source_outcome, plan, intent, result)) do
      {:ok,
       %{
         source_outcome: source_outcome,
         plan: plan,
         intent: intent,
         result: result,
         persisted: persisted
       }}
    end
  end

  defp ensure_dream_window(policy) do
    exploration_need = Map.get(policy.needs, "exploration", 0.0)

    cond do
      policy.pressure != :low -> {:error, :organism_not_idle}
      exploration_need < 0.5 -> {:error, :dreaming_suppressed}
      true -> :ok
    end
  end

  defp fetch_recent_outcomes(opts) do
    memory_module(opts).query_recent_execution_outcomes(%{limit: Keyword.get(opts, :limit, 5)})
  end

  defp select_source_outcome([row | _rows]) when is_map(row), do: {:ok, normalize_outcome(row)}
  defp select_source_outcome([]), do: {:error, :no_simulation_source_outcomes}
  defp select_source_outcome(_rows), do: {:error, :invalid_simulation_source_outcomes}

  defp build_permutation_plan(source_outcome, policy) do
    source_outcome_id = Map.get(source_outcome, "xt/id", Map.get(source_outcome, "id", "execution_outcome:unknown"))
    attractor_id = "dream:#{source_outcome_id}"
    action = Map.get(source_outcome, "action", "execute_plan")
    source_attractor = Map.get(source_outcome, "plan_attractor_id", "unknown_attractor")
    permutation_mode = permutation_mode(source_outcome)
    source_step_ids = List.wrap(Map.get(source_outcome, "plan_step_ids", []))

    plan =
      %Plan{
        attractor: %Attractor{
          id: attractor_id,
          kind: "SimulationPermutation",
          properties: %{
            "source_outcome_id" => source_outcome_id,
            "source_attractor_id" => source_attractor,
            "permutation_mode" => permutation_mode
          },
          target_state: %AbstractState{
            entity: attractor_id,
            phase: "dream",
            summary: "dream_state:#{source_attractor}",
            attributes: %{
              "source_action" => action,
              "source_step_ids" => source_step_ids,
              "permutation_mode" => permutation_mode
            },
            needs: %{"exploration" => 0.9},
            values: %{"learning" => 0.8},
            objective_priors: %{"refinement" => 0.8}
          },
          objective_priors: %{"refinement" => 0.8},
          needs: %{"exploration" => 0.9},
          values: %{"learning" => 0.8}
        },
        steps: [
          %Step{
            id: "dream-step:#{source_outcome_id}",
            action: "simulate_permutation",
            params: %{
              "source_outcome_id" => source_outcome_id,
              "source_attractor_id" => source_attractor,
              "source_step_ids" => source_step_ids,
              "permutation_mode" => permutation_mode,
              "source_result" => Map.get(source_outcome, "result", %{})
            },
            predicted_state: %AbstractState{
              entity: source_outcome_id,
              phase: "dream",
              summary: "simulated:#{action}",
              attributes: %{"permutation_mode" => permutation_mode},
              needs: %{"exploration" => 0.9},
              values: %{"learning" => 0.8},
              objective_priors: %{"refinement" => 0.8}
            }
          }
        ],
        transition_delta: %{
          simulation: %{
            "source_outcome_id" => source_outcome_id,
            "permutation_mode" => permutation_mode,
            "source_attractor_id" => source_attractor
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

  defp build_dream_intent(%Plan{} = plan, opts) do
    ExecutionIntent.from_plan(
      plan,
      %{"cell_type" => "simulation_daemon", "id" => "simulation_daemon"},
      Keyword.get(opts, :executor_spec, @default_executor)
    )
  end

  defp build_simulation_event(source_outcome, plan, intent, result) do
    source_outcome_id = Map.get(source_outcome, "xt/id", Map.get(source_outcome, "id", "execution_outcome:unknown"))
    permutation = plan.transition_delta[:simulation] || %{}

    %{
      "source_outcome_id" => source_outcome_id,
      "source_attractor_id" => Map.get(source_outcome, "plan_attractor_id", "unknown_attractor"),
      "permutation_id" => plan.attractor.id,
      "permutation_mode" => Map.get(permutation, "permutation_mode", "dream"),
      "intent_id" => intent.id,
      "vm_id" => Map.get(result, :vm_id) || Map.get(result, "vm_id", "unknown_vm"),
      "outcome_status" => outcome_status(result),
      "result" => normalize_nested(Map.get(result, :telemetry) || Map.get(result, "telemetry") || %{})
    }
  end

  defp permutation_mode(source_outcome) do
    case List.wrap(Map.get(source_outcome, "plan_step_ids", [])) do
      [_single] -> "mutate_single_path"
      [_ | _] -> "reorder_step_sequence"
      [] -> "replay_outcome"
    end
  end

  defp normalize_outcome(%{"xt/id" => _} = outcome), do: outcome
  defp normalize_outcome(%{"node" => node}) when is_map(node), do: node
  defp normalize_outcome(outcome), do: outcome

  defp outcome_status(%{status: status}) when is_atom(status), do: Atom.to_string(status)
  defp outcome_status(%{"status" => status}) when is_binary(status), do: status
  defp outcome_status(_result), do: "unknown"

  defp normalize_nested(value) when is_map(value) do
    Map.new(value, fn {key, nested} -> {to_string(key), normalize_nested(nested)} end)
  end

  defp normalize_nested(value) when is_list(value), do: Enum.map(value, &normalize_nested/1)
  defp normalize_nested(value), do: value

  defp memory_module(opts), do: Keyword.get(opts, :memory_module, Rhizome.Memory)
  defp executor_module(opts), do: Keyword.get(opts, :executor_module, Sandbox.Executor)
end
