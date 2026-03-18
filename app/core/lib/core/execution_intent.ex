defmodule Core.ExecutionIntent do
  @moduledoc """
  Typed planning-to-action membrane contract for motor execution.
  """

  alias Core.Plan
  alias Core.Plan.AbstractState

  @enforce_keys [:id, :action, :cell_type, :params, :default_args, :executor, :created_at]
  defstruct [
    :id,
    :action,
    :cell_type,
    :params,
    :default_args,
    :executor,
    :created_at,
    :plan_attractor_id,
    :plan_step_ids,
    :target_state,
    :transition_delta,
    :metadata
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          action: String.t(),
          cell_type: String.t(),
          params: map(),
          default_args: map(),
          executor: map(),
          created_at: non_neg_integer(),
          plan_attractor_id: String.t() | nil,
          plan_step_ids: [String.t()],
          target_state: AbstractState.t() | nil,
          transition_delta: map(),
          metadata: map()
        }

  def new(attrs) when is_map(attrs) do
    with {:ok, id} <- required_binary(attrs, :id),
         {:ok, action} <- required_binary(attrs, :action),
         {:ok, cell_type} <- required_binary(attrs, :cell_type),
         {:ok, params} <- required_map(attrs, :params),
         {:ok, default_args} <- required_map(attrs, :default_args),
         {:ok, executor} <- required_map(attrs, :executor),
         {:ok, created_at} <- required_integer(attrs, :created_at) do
      {:ok,
       %__MODULE__{
         id: id,
         action: action,
         cell_type: cell_type,
         params: stringify_nested(params),
         default_args: stringify_nested(default_args),
         executor: stringify_nested(executor),
         created_at: created_at,
         plan_attractor_id: optional_binary(attrs, :plan_attractor_id),
         plan_step_ids: optional_string_list(attrs, :plan_step_ids),
         target_state: optional_abstract_state(attrs, :target_state),
         transition_delta: optional_map(attrs, :transition_delta),
         metadata: optional_map(attrs, :metadata)
       }}
    end
  end

  def from_action(dna_spec, action, params, executor_spec, attrs \\ %{}) do
    new(%{
      id:
        Map.get(attrs, :id) ||
          Map.get(attrs, "id") ||
          "intent:#{Map.get(dna_spec, "cell_type", "cell")}:#{action}:#{System.unique_integer([:positive])}",
      action: action,
      cell_type: dna_spec |> Map.get("cell_type", "unknown_cell") |> to_string(),
      params: normalize_execution_params(params),
      default_args: Map.get(executor_spec, "default_args") || Map.get(executor_spec, :default_args) || %{},
      executor: normalize_executor(executor_spec),
      created_at:
        Map.get(attrs, :created_at) || Map.get(attrs, "created_at") || System.system_time(:second),
      plan_attractor_id: Map.get(attrs, :plan_attractor_id) || Map.get(attrs, "plan_attractor_id"),
      plan_step_ids: Map.get(attrs, :plan_step_ids) || Map.get(attrs, "plan_step_ids") || [],
      target_state: Map.get(attrs, :target_state) || Map.get(attrs, "target_state"),
      transition_delta: Map.get(attrs, :transition_delta) || Map.get(attrs, "transition_delta") || %{},
      metadata: Map.get(attrs, :metadata) || Map.get(attrs, "metadata") || %{}
    })
  end

  def from_plan(%Plan{} = plan, dna_spec, executor_spec) do
    from_action(dna_spec, "execute_plan", Plan.to_execution_payload(plan), executor_spec, %{
      id: "intent:#{plan.attractor.id}:#{plan.created_at}",
      created_at: plan.created_at,
      plan_attractor_id: plan.attractor.id,
      plan_step_ids: Enum.map(plan.steps, & &1.id),
      target_state: plan.attractor.target_state,
      transition_delta: plan.transition_delta,
      metadata: %{
        "attractor_kind" => plan.attractor.kind,
        "objective_priors" => plan.attractor.objective_priors,
        "needs" => plan.attractor.needs,
        "values" => plan.attractor.values
      }
    })
  end

  def to_map(%__MODULE__{} = intent) do
    %{
      "id" => intent.id,
      "action" => intent.action,
      "cell_type" => intent.cell_type,
      "params" => stringify_nested(intent.params),
      "default_args" => stringify_nested(intent.default_args),
      "executor" => stringify_nested(intent.executor),
      "created_at" => intent.created_at,
      "plan_attractor_id" => intent.plan_attractor_id,
      "plan_step_ids" => intent.plan_step_ids,
      "target_state" => abstract_state_to_map(intent.target_state),
      "transition_delta" => stringify_nested(intent.transition_delta),
      "metadata" => stringify_nested(intent.metadata)
    }
  end

  defp required_binary(attrs, key) do
    case Map.get(attrs, key) || Map.get(attrs, to_string(key)) do
      value when is_binary(value) and value != "" -> {:ok, value}
      _ -> {:error, {:invalid_execution_intent, key}}
    end
  end

  defp required_map(attrs, key) do
    case Map.get(attrs, key) || Map.get(attrs, to_string(key)) do
      value when is_map(value) -> {:ok, value}
      _ -> {:error, {:invalid_execution_intent, key}}
    end
  end

  defp required_integer(attrs, key) do
    case Map.get(attrs, key) || Map.get(attrs, to_string(key)) do
      value when is_integer(value) and value >= 0 -> {:ok, value}
      _ -> {:error, {:invalid_execution_intent, key}}
    end
  end

  defp optional_binary(attrs, key) do
    case Map.get(attrs, key) || Map.get(attrs, to_string(key)) do
      value when is_binary(value) and value != "" -> value
      _ -> nil
    end
  end

  defp optional_string_list(attrs, key) do
    attrs
    |> Map.get(key, Map.get(attrs, to_string(key), []))
    |> List.wrap()
    |> Enum.map(&to_string/1)
  end

  defp optional_abstract_state(attrs, key) do
    case Map.get(attrs, key) || Map.get(attrs, to_string(key)) do
      %AbstractState{} = state -> state
      state when is_map(state) -> state_from_map(state)
      _ -> nil
    end
  end

  defp optional_map(attrs, key) do
    case Map.get(attrs, key) || Map.get(attrs, to_string(key)) do
      value when is_map(value) -> stringify_nested(value)
      _ -> %{}
    end
  end

  defp state_from_map(state) do
    %AbstractState{
      entity: Map.get(state, :entity) || Map.get(state, "entity") || "unknown_entity",
      phase: Map.get(state, :phase) || Map.get(state, "phase") || "unknown_phase",
      summary: Map.get(state, :summary) || Map.get(state, "summary") || "unknown_summary",
      attributes: Map.get(state, :attributes) || Map.get(state, "attributes") || %{},
      needs: Map.get(state, :needs) || Map.get(state, "needs") || %{},
      values: Map.get(state, :values) || Map.get(state, "values") || %{},
      objective_priors: Map.get(state, :objective_priors) || Map.get(state, "objective_priors") || %{}
    }
  end

  defp abstract_state_to_map(nil), do: nil
  defp abstract_state_to_map(%AbstractState{} = state), do: AbstractState.to_map(state)

  defp normalize_executor(executor_spec) when is_map(executor_spec) do
    %{
      "module" => Map.get(executor_spec, "module") || Map.get(executor_spec, :module),
      "function" => Map.get(executor_spec, "function") || Map.get(executor_spec, :function)
    }
  end

  defp normalize_executor(_), do: %{}

  defp normalize_execution_params(params) when is_list(params), do: params |> Enum.into(%{}) |> stringify_nested()
  defp normalize_execution_params(params) when is_map(params), do: stringify_nested(params)
  defp normalize_execution_params(other), do: %{"value" => stringify_nested(other)}

  def stringify_nested(value) when is_map(value) do
    Map.new(value, fn {key, nested} ->
      {to_string(key), stringify_nested(nested)}
    end)
  end

  def stringify_nested(value) when is_list(value), do: Enum.map(value, &stringify_nested/1)
  def stringify_nested(value), do: value
end
