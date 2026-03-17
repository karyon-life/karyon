defmodule Core.MotorDriver do
  @moduledoc """
  The Motor Planning Driver.
  Translates bitemporal graph attractors into concrete sequential execution plans.
  Implements token-free Active Inference for architectural modification.
  """
  require Logger

  @doc """
  Generates a sequential plan (.yml) based on predicted state transitions.
  Traverses the Rhizome to identify the path with minimum expected free energy.
  """
  def sequence_plan(target_concept) do
    Logger.info("[MotorDriver] Sequencing plan for attractor: #{target_concept}")

    with {:ok, _} <- Rhizome.Native.memgraph_query("MATCH (s:SuperNode {id: '#{target_concept}'}) RETURN s"),
         {:ok, dependencies} <- fetch_causal_chain(target_concept) do
      plan = %{
        "attractor" => target_concept,
        "steps" => dependencies,
        "timestamp" => System.system_time(:second)
      }

      {:ok, plan}
    else
      {:error, reason} -> {:error, reason}
      _ -> {:error, :attractor_not_found}
    end
  end

  @doc """
  Dispatches a plan to a specialized motor cell.
  """
  def dispatch_plan(plan, cell_pid) do
    Logger.info("[MotorDriver] Dispatching plan to motor cell: #{inspect(cell_pid)}")
    
    # Each step in the plan becomes an execution expectation
    Enum.each(plan["steps"], fn step ->
      GenServer.call(cell_pid, {:form_expectation, step["id"], step["predicted_outcome"], 0.9})
    end)

    GenServer.call(cell_pid, {:execute, "execute_plan", plan})
  end

  defp fetch_causal_chain(_super_node_id) do
    {:error, :graph_planning_not_ready}
  end
end
