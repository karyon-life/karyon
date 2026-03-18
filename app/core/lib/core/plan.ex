defmodule Core.Plan do
  @moduledoc """
  Typed planning contracts for graph-backed execution planning.
  """

  alias __MODULE__.Attractor
  alias __MODULE__.AbstractState
  alias __MODULE__.Step

  @enforce_keys [:attractor, :steps, :transition_delta, :created_at]
  defstruct [:attractor, :steps, :transition_delta, :created_at]

  @type t :: %__MODULE__{
          attractor: Attractor.t(),
          steps: [Step.t()],
          transition_delta: map(),
          created_at: non_neg_integer()
        }

  def to_execution_payload(%__MODULE__{} = plan) do
    %{
      "attractor" => plan.attractor.id,
      "attractor_state" => Attractor.to_map(plan.attractor),
      "steps" => Enum.map(plan.steps, &Step.to_map/1),
      "transition_delta" => stringify_nested(plan.transition_delta),
      "timestamp" => plan.created_at
    }
  end

  def stringify_nested(value) when is_map(value) do
    Map.new(value, fn
      {key, nested} when is_map(nested) -> {to_string(key), stringify_nested(nested)}
      {key, nested} when is_list(nested) -> {to_string(key), Enum.map(nested, &stringify_nested/1)}
      {key, nested} -> {to_string(key), nested}
    end)
  end

  def stringify_nested(value) when is_list(value), do: Enum.map(value, &stringify_nested/1)
  def stringify_nested(value), do: value

  defmodule Attractor do
    @moduledoc false

    @enforce_keys [:id, :kind, :properties, :target_state, :objective_priors, :needs, :values]
    defstruct [:id, :kind, :properties, :target_state, :objective_priors, :needs, :values]

    @type t :: %__MODULE__{
            id: String.t(),
            kind: String.t(),
            properties: map(),
            target_state: AbstractState.t(),
            objective_priors: map(),
            needs: map(),
            values: map()
          }

    def to_map(%__MODULE__{} = attractor) do
      %{
        "id" => attractor.id,
        "kind" => attractor.kind,
        "properties" => Core.Plan.stringify_nested(attractor.properties),
        "target_state" => AbstractState.to_map(attractor.target_state),
        "objective_priors" => Core.Plan.stringify_nested(attractor.objective_priors),
        "needs" => Core.Plan.stringify_nested(attractor.needs),
        "values" => Core.Plan.stringify_nested(attractor.values)
      }
    end
  end

  defmodule AbstractState do
    @moduledoc false

    @enforce_keys [:entity, :phase, :summary, :attributes, :needs, :values, :objective_priors]
    defstruct [:entity, :phase, :summary, :attributes, :needs, :values, :objective_priors]

    @type t :: %__MODULE__{
            entity: String.t(),
            phase: String.t(),
            summary: String.t(),
            attributes: map(),
            needs: map(),
            values: map(),
            objective_priors: map()
          }

    def to_map(%__MODULE__{} = state) do
      %{
        "entity" => state.entity,
        "phase" => state.phase,
        "summary" => state.summary,
        "attributes" => Core.Plan.stringify_nested(state.attributes),
        "needs" => Core.Plan.stringify_nested(state.needs),
        "values" => Core.Plan.stringify_nested(state.values),
        "objective_priors" => Core.Plan.stringify_nested(state.objective_priors)
      }
    end
  end

  defmodule Step do
    @moduledoc false

    @enforce_keys [:id, :action, :params, :predicted_state]
    defstruct [:id, :action, :params, :predicted_state]

    @type t :: %__MODULE__{
            id: String.t(),
            action: String.t(),
            params: map(),
            predicted_state: AbstractState.t()
          }

    def to_map(%__MODULE__{} = step) do
      %{
        "id" => step.id,
        "action" => step.action,
        "params" => Core.Plan.stringify_nested(step.params),
        "predicted_state" => AbstractState.to_map(step.predicted_state),
        "predicted_outcome" => step.predicted_state.summary
      }
    end
  end
end
