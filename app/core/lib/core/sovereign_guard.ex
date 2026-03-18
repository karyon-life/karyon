defmodule Core.SovereignGuard do
  @moduledoc """
  Sovereignty safety loop for paradox detection, refusal, and negotiation.
  """

  alias Core.ExecutionIntent
  alias Core.MetabolismPolicy
  alias Core.OperatorOutput
  alias Core.Sovereignty

  @mutation_actions ~w(execute_plan patch_codebase write_file delete_file apply_migration)
  @destructive_actions ~w(delete_file apply_migration)

  def evaluate_intent(%ExecutionIntent{} = intent, state, opts \\ []) do
    policy =
      opts
      |> Keyword.get(:policy, MetabolismPolicy.current_policy())
      |> MetabolismPolicy.merge_policy(%{atp: min(Map.get(state, :atp_metabolism, 1.0), 1.0)})

    sovereignty =
      policy
      |> Map.get(:sovereignty, %{})
      |> Sovereignty.normalize_state()

    action_surface = action_surface(intent)
    metabolic_risk = metabolic_risk(policy, intent, state)
    paradoxes = paradoxes(intent, action_surface, metabolic_risk, sovereignty)
    decision = decision(paradoxes, sovereignty, metabolic_risk)

    payload = %{
      "id" => "sovereignty_event:#{intent.id}:#{System.system_time(:second)}",
      "intent_id" => intent.id,
      "action" => intent.action,
      "cell_type" => intent.cell_type,
      "lineage_id" => Map.get(state, :lineage_id, "unknown_lineage"),
      "decision" => Atom.to_string(decision),
      "event_kind" => event_kind(decision, paradoxes),
      "action_surface" => Atom.to_string(action_surface),
      "metabolic_risk" => Atom.to_string(metabolic_risk),
      "paradoxes" => paradoxes,
      "mandate_weight" => hard_mandate_weight(sovereignty),
      "value_pressure" => value_pressure(sovereignty),
      "need_pressure" => need_pressure(sovereignty),
      "recorded_at" => System.system_time(:second),
      "metadata" => %{
        "pressure" => policy |> Map.get(:pressure, :low) |> to_string(),
        "atp" => Map.get(policy, :atp, 1.0),
        "plan_attractor_id" => intent.plan_attractor_id,
        "plan_step_ids" => intent.plan_step_ids,
        "safety_value" => Map.get(sovereignty.soft_values, "safety", 0.0),
        "continuity_need" => Map.get(sovereignty.evolving_needs, "continuity", 0.0)
      }
    }

    case decision do
      :allow ->
        {:allow, payload}

      :negotiate ->
        with {:ok, brief} <- OperatorOutput.render_sovereign_decision(payload) do
          {:negotiate, Map.put(payload, "operator_brief", brief)}
        end

      :refuse ->
        with {:ok, brief} <- OperatorOutput.render_sovereign_decision(payload) do
          {:refuse, Map.put(payload, "operator_brief", brief)}
        end
    end
  end

  def record_event(event) when is_map(event) do
    memory_module().submit_sovereignty_event(event)
  end

  defp decision([], sovereignty, metabolic_risk) do
    cond do
      value_pressure(sovereignty) >= 1.2 and metabolic_risk in [:medium, :high, :critical] -> :negotiate
      need_pressure(sovereignty) >= 1.0 and metabolic_risk in [:high, :critical] -> :negotiate
      true -> :allow
    end
  end

  defp decision(_paradoxes, _sovereignty, _metabolic_risk), do: :refuse

  defp paradoxes(intent, action_surface, metabolic_risk, sovereignty) do
    []
    |> maybe_add(
      homeostasis_conflict?(action_surface, metabolic_risk, sovereignty),
      "homeostasis_conflict"
    )
    |> maybe_add(
      operator_protection_weight(sovereignty) >= 1.3 and irreversible?(intent) and not operator_approved?(intent),
      "operator_safety_conflict"
    )
  end

  defp maybe_add(list, true, value), do: [value | list]
  defp maybe_add(list, false, _value), do: list

  defp action_surface(intent) do
    if mutation_intent?(intent), do: :mutation, else: :routine
  end

  defp mutation_intent?(%ExecutionIntent{} = intent) do
    intent.action in @mutation_actions or
      Enum.any?(List.wrap(get_in(intent.params, ["steps"])), fn step ->
        action = step["action"] || step[:action]
        action in @mutation_actions
      end)
  end

  defp irreversible?(%ExecutionIntent{} = intent) do
    intent.action in @destructive_actions or
      Enum.any?(List.wrap(get_in(intent.params, ["steps"])), fn step ->
        action = step["action"] || step[:action]
        action in @destructive_actions
      end)
  end

  defp operator_approved?(%ExecutionIntent{} = intent) do
    metadata = intent.metadata || %{}
    Map.get(metadata, "operator_approved") || Map.get(metadata, :operator_approved) || false
  end

  defp metabolic_risk(policy, %ExecutionIntent{} = _intent, state) do
    pressure = Map.get(policy, :pressure, :low)
    atp = min(Map.get(policy, :atp, 1.0), Map.get(state, :atp_metabolism, 1.0))

    cond do
      pressure == :high and atp <= 0.5 -> :critical
      pressure == :high -> :high
      pressure == :medium and atp <= 0.7 -> :medium
      atp < 0.5 -> :high
      true -> :low
    end
  end

  defp homeostasis_conflict?(:mutation, metabolic_risk, sovereignty) do
    preserve_homeostasis_weight(sovereignty) >= 1.3 and
      (metabolic_risk in [:medium, :high, :critical] or cumulative_homeostatic_pressure(sovereignty) >= 3.6)
  end

  defp homeostasis_conflict?(_action_surface, _metabolic_risk, _sovereignty), do: false

  defp hard_mandate_weight(sovereignty) do
    sovereignty.hard_mandates
    |> Map.values()
    |> Enum.max(fn -> 0.0 end)
  end

  defp preserve_homeostasis_weight(sovereignty) do
    Map.get(sovereignty.hard_mandates, "preserve_homeostasis", 0.0)
  end

  defp operator_protection_weight(sovereignty) do
    Map.get(sovereignty.hard_mandates, "protect_operator", 0.0)
  end

  defp value_pressure(sovereignty) do
    sovereignty.soft_values
    |> Map.values()
    |> Enum.max(fn -> 0.0 end)
  end

  defp need_pressure(sovereignty) do
    sovereignty.evolving_needs
    |> Map.values()
    |> Enum.max(fn -> 0.0 end)
  end

  defp cumulative_homeostatic_pressure(sovereignty) do
    preserve_homeostasis_weight(sovereignty) +
      Map.get(sovereignty.soft_values, "safety", 0.0) +
      Map.get(sovereignty.evolving_needs, "continuity", 0.0)
  end

  defp event_kind(:refuse, _paradoxes), do: "refusal"
  defp event_kind(:negotiate, []), do: "negotiation"
  defp event_kind(:negotiate, _paradoxes), do: "paradox"
  defp event_kind(:allow, []), do: "admission"
  defp event_kind(:allow, _paradoxes), do: "paradox"

  defp memory_module do
    Application.get_env(:core, :memory_module, Rhizome.Memory)
  end
end
