defmodule Core.Sovereignty do
  @moduledoc """
  Explicit sovereignty and symbiosis control-plane contract.

  This keeps hard mandates, soft values, evolving needs, and objective priors
  explicit so they can steer planning and metabolic admission without hiding
  organism law inside ad hoc planner heuristics.
  """

  @schema "karyon.sovereignty.v1"

  @type state :: %{
          required(:schema) => String.t(),
          required(:hard_mandates) => map(),
          required(:soft_values) => map(),
          required(:evolving_needs) => map(),
          required(:objective_priors) => map(),
          required(:precedence) => map()
        }

  def current_state(overrides \\ %{}) when is_map(overrides) do
    :core
    |> Application.get_env(:sovereignty, %{})
    |> merge_maps(overrides)
    |> normalize_state()
  end

  def normalize_state(state) when is_map(state) do
    state = atomize_keys(state)

    %{
      schema: @schema,
      hard_mandates: normalize_weight_map(Map.get(state, :hard_mandates, %{"preserve_homeostasis" => 1.0})),
      soft_values: normalize_weight_map(Map.get(state, :soft_values, %{"safety" => 0.9, "learning" => 0.6})),
      evolving_needs: normalize_weight_map(Map.get(state, :evolving_needs, %{"continuity" => 0.9, "adaptation" => 0.7})),
      objective_priors: normalize_weight_map(Map.get(state, :objective_priors, %{"repair" => 0.9, "continuity" => 1.0})),
      precedence:
        normalize_weight_map(
          Map.get(state, :precedence, %{
            "hard_mandates" => 1.5,
            "soft_values" => 1.2,
            "evolving_needs" => 1.1,
            "objective_priors" => 1.0
          })
        )
    }
  end

  def merge_into_policy(policy, sovereignty_state \\ current_state())
      when is_map(policy) and is_map(sovereignty_state) do
    state = normalize_state(sovereignty_state)
    overrides = policy_overrides(state)

    policy
    |> Map.update(:needs, overrides.needs, &merge_weights(&1, overrides.needs))
    |> Map.update(:values, overrides.values, &merge_weights(&1, overrides.values))
    |> Map.update(:objective_priors, overrides.objective_priors, &merge_weights(&1, overrides.objective_priors))
    |> Map.put(:sovereignty, to_map(state))
  end

  def policy_overrides(sovereignty_state \\ current_state()) when is_map(sovereignty_state) do
    state = normalize_state(sovereignty_state)

    %{
      needs: scale_weights(state.evolving_needs, precedence(state, "evolving_needs")),
      values: scale_weights(state.soft_values, precedence(state, "soft_values")),
      objective_priors:
        state.objective_priors
        |> scale_weights(precedence(state, "objective_priors"))
        |> merge_weights(scale_weights(state.hard_mandates, precedence(state, "hard_mandates")))
    }
  end

  def to_map(state) when is_map(state) do
    normalized = normalize_state(state)

    %{
      "schema" => normalized.schema,
      "hard_mandates" => normalized.hard_mandates,
      "soft_values" => normalized.soft_values,
      "evolving_needs" => normalized.evolving_needs,
      "objective_priors" => normalized.objective_priors,
      "precedence" => normalized.precedence
    }
  end

  defp precedence(state, key), do: Map.get(state.precedence, key, 1.0)

  defp merge_maps(left, right) do
    Map.merge(left, right, fn
      _key, left_value, right_value when is_map(left_value) and is_map(right_value) ->
        merge_maps(left_value, right_value)

      _key, _left_value, right_value ->
        right_value
    end)
  end

  defp merge_weights(left, right) when is_map(left) and is_map(right) do
    Map.merge(normalize_weight_map(left), normalize_weight_map(right), fn _key, left_value, right_value ->
      max(left_value, right_value)
    end)
  end

  defp scale_weights(map, factor) when is_map(map) do
    Map.new(map, fn {key, value} -> {to_string(key), normalize_weight(value) * normalize_weight(factor)} end)
  end

  defp normalize_weight_map(map) when is_map(map) do
    Map.new(map, fn {key, value} -> {to_string(key), normalize_weight(value)} end)
  end

  defp normalize_weight_map(_), do: %{}

  defp atomize_keys(map) do
    Map.new(map, fn
      {key, value} when is_binary(key) and is_map(value) -> {String.to_atom(key), atomize_keys(value)}
      {key, value} when is_binary(key) -> {String.to_atom(key), value}
      {key, value} when is_map(value) -> {key, atomize_keys(value)}
      {key, value} -> {key, value}
    end)
  end

  defp normalize_weight(value) when is_float(value), do: value
  defp normalize_weight(value) when is_integer(value), do: value * 1.0

  defp normalize_weight(value) when is_binary(value) do
    case Float.parse(value) do
      {parsed, _} -> parsed
      :error -> 1.0
    end
  end

  defp normalize_weight(_), do: 1.0
end
