defmodule Core.MetabolismPolicy do
  @moduledoc """
  Shared runtime policy contract for metabolism, needs, values, and objective priors.

  This keeps ATP pressure and internal drives explicit so planning, execution,
  and lifecycle systems can consume the same weighted-prior model.
  """

  @type pressure :: :low | :medium | :high
  @type policy :: %{
          required(:pressure) => pressure(),
          required(:atp) => float(),
          required(:needs) => map(),
          required(:values) => map(),
          required(:objective_priors) => map(),
          required(:sovereignty) => map()
        }

  alias Core.DNA
  alias Core.ExecutionIntent
  alias Core.Plan
  alias Core.Sovereignty

  def current_policy do
    case GenServer.whereis(Core.MetabolicDaemon) do
      nil ->
        build_policy(:low)

      pid ->
        try do
          case GenServer.call(pid, :get_policy) do
            policy when is_map(policy) ->
              build_policy(:low)
              |> merge_policy(policy)
              |> refresh_live_sovereignty()

            _ ->
              build_policy(GenServer.call(pid, :get_pressure))
          end
        catch
          :exit, _ -> build_policy(GenServer.call(pid, :get_pressure))
        end
    end
  end

  def build_policy(pressure, overrides \\ %{})

  def build_policy(pressure, overrides) when pressure in [:low, :medium, :high] and is_map(overrides) do
    base =
      %{
        pressure: pressure,
        atp: atp_level(pressure),
        needs: needs_for(pressure),
        values: values_for(pressure),
        objective_priors: objective_priors_for(pressure),
        sovereignty: Sovereignty.to_map(Sovereignty.current_state())
      }

    base
    |> merge_policy(overrides)
    |> then(&Sovereignty.merge_into_policy(&1, Map.get(&1, :sovereignty, %{})))
  end

  def build_policy(_pressure, overrides) when is_map(overrides), do: build_policy(:low, overrides)

  def objective_weight(policy, attractor, step \\ nil) do
    policy_weights =
      [
        Map.get(policy, :objective_priors, %{}),
        Map.get(policy, :needs, %{}),
        Map.get(policy, :values, %{})
      ]
      |> Enum.flat_map(&Map.values/1)
      |> max_weight()

    attractor_weights =
      [
        Map.get(attractor, :objective_priors, %{}),
        Map.get(attractor, :needs, %{}),
        Map.get(attractor, :values, %{}),
        step && Map.get(step.predicted_state, :objective_priors, %{}),
        step && Map.get(step.predicted_state, :needs, %{}),
        step && Map.get(step.predicted_state, :values, %{})
      ]
      |> Enum.reject(&is_nil/1)
      |> Enum.flat_map(&Map.values/1)
      |> max_weight()

    Enum.max([policy_weights, attractor_weights, 1.0])
  end

  def spawn_profile(%DNA{} = dna, policy \\ current_policy()) do
    weights = spawn_weights(dna)
    cost = normalize_weight(DNA.atp_requirement(dna))
    build_admission_profile(:spawn, weights, cost, policy)
  end

  def plan_profile(%Plan{} = plan, policy \\ current_policy()) do
    weights = %{
      objective_priors: presence_or_fallback(plan.attractor.objective_priors, %{"baseline" => 1.0}),
      needs: plan.attractor.needs,
      values: plan.attractor.values
    }

    cost = 0.45 + max(length(plan.steps), 1) * 0.15
    build_admission_profile(:plan, weights, cost, policy)
  end

  def intent_profile(intent, policy \\ current_policy())

  def intent_profile(%ExecutionIntent{} = intent, policy) do
    intent
    |> ExecutionIntent.to_map()
    |> intent_profile(policy)
  end

  def intent_profile(intent, policy) when is_map(intent) do
    weights = %{
      objective_priors:
        intent
        |> fetch_nested(["metadata", "objective_priors"])
        |> presence_or_fallback(%{"baseline" => 1.0}),
      needs: fetch_nested(intent, ["metadata", "needs"]) || %{},
      values: fetch_nested(intent, ["metadata", "values"]) || %{}
    }

    step_count =
      intent
      |> fetch_nested(["params", "steps"])
      |> List.wrap()
      |> length()
      |> max(1)

    cost = 0.55 + step_count * 0.20
    build_admission_profile(:execution, weights, cost, policy)
  end

  def admit_spawn(%DNA{} = dna, policy \\ current_policy()) do
    profile = spawn_profile(dna, policy)
    if admitted?(profile), do: {:ok, profile}, else: {:error, profile}
  end

  def admit_plan(%Plan{} = plan, policy \\ current_policy()) do
    profile = plan_profile(plan, policy)
    if admitted?(profile), do: {:ok, profile}, else: {:error, profile}
  end

  def admit_intent(intent, policy \\ current_policy()) do
    profile = intent_profile(intent, policy)
    if admitted?(profile), do: {:ok, profile}, else: {:error, profile}
  end

  def admitted?(%{"status" => "admitted"}), do: true
  def admitted?(%{status: "admitted"}), do: true
  def admitted?(_profile), do: false

  def merge_policy(base, overrides) do
    %{
      pressure: overrides[:pressure] || overrides["pressure"] || base.pressure,
      atp: normalize_weight(overrides[:atp] || overrides["atp"] || base.atp),
      needs: merge_weights(base.needs, overrides[:needs] || overrides["needs"] || %{}),
      values: merge_weights(base.values, overrides[:values] || overrides["values"] || %{}),
      objective_priors:
        merge_weights(base.objective_priors, overrides[:objective_priors] || overrides["objective_priors"] || %{}),
      sovereignty:
        Sovereignty.to_map(
          overrides[:sovereignty] || overrides["sovereignty"] || Map.get(base, :sovereignty, %{})
        )
    }
  end

  def to_map(policy) when is_map(policy) do
    %{
      "pressure" => to_string(Map.get(policy, :pressure, Map.get(policy, "pressure", :low))),
      "atp" => normalize_weight(Map.get(policy, :atp, Map.get(policy, "atp", 1.0))),
      "needs" => stringify_weights(Map.get(policy, :needs, Map.get(policy, "needs", %{}))),
      "values" => stringify_weights(Map.get(policy, :values, Map.get(policy, "values", %{}))),
      "objective_priors" => stringify_weights(Map.get(policy, :objective_priors, Map.get(policy, "objective_priors", %{}))),
      "sovereignty" =>
        policy
        |> Map.get(:sovereignty, Map.get(policy, "sovereignty", %{}))
        |> Sovereignty.to_map()
    }
  end

  defp refresh_live_sovereignty(policy) when is_map(policy) do
    daemon_sovereignty = Map.get(policy, :sovereignty, %{})
    live_sovereignty =
      daemon_sovereignty
      |> Sovereignty.to_map()
      |> merge_maps(Sovereignty.to_map(Sovereignty.current_state()))

    policy
    |> Map.put(:sovereignty, Sovereignty.to_map(live_sovereignty))
    |> Sovereignty.merge_into_policy(live_sovereignty)
  end

  defp atp_level(:low), do: 1.0
  defp atp_level(:medium), do: 0.7
  defp atp_level(:high), do: 0.4

  defp needs_for(:low), do: %{"exploration" => 0.6, "throughput" => 0.5, "stability" => 0.4}
  defp needs_for(:medium), do: %{"exploration" => 0.2, "throughput" => 0.7, "stability" => 0.8}
  defp needs_for(:high), do: %{"exploration" => 0.1, "throughput" => 0.9, "stability" => 1.0}

  defp values_for(:low), do: %{"learning" => 0.8, "safety" => 0.7}
  defp values_for(:medium), do: %{"learning" => 0.6, "safety" => 0.9}
  defp values_for(:high), do: %{"learning" => 0.3, "safety" => 1.0}

  defp objective_priors_for(:low), do: %{"refinement" => 0.8, "repair" => 0.6}
  defp objective_priors_for(:medium), do: %{"refinement" => 0.6, "repair" => 1.0}
  defp objective_priors_for(:high), do: %{"refinement" => 0.3, "repair" => 1.3}

  defp build_admission_profile(kind, weights, cost, policy) do
    objective_signal = weighted_signal(weights[:objective_priors] || %{}, policy.objective_priors)
    need_signal = weighted_signal(weights[:needs] || %{}, policy.needs)
    value_signal = weighted_signal(weights[:values] || %{}, policy.values)
    priority_score = Enum.max([objective_signal, need_signal, value_signal, baseline_priority(weights)])
    budget = policy.atp + priority_score * 0.35
    admitted = cost <= budget

    %{
      "kind" => Atom.to_string(kind),
      "status" => if(admitted, do: "admitted", else: "deferred"),
      "pressure" => Atom.to_string(policy.pressure),
      "lane" => lane_for(admitted, policy.pressure, priority_score),
      "cost" => round_metric(cost),
      "budget" => round_metric(budget),
      "priority_score" => round_metric(priority_score),
      "objective_signal" => round_metric(objective_signal),
      "need_signal" => round_metric(need_signal),
      "value_signal" => round_metric(value_signal)
    }
  end

  defp lane_for(true, :high, score) when score >= 1.0, do: "expedite"
  defp lane_for(true, _pressure, score) when score >= 0.8, do: "priority"
  defp lane_for(true, _pressure, _score), do: "normal"
  defp lane_for(false, _pressure, _score), do: "deferred"

  defp weighted_signal(subject_weights, policy_weights) do
    subject_weights
    |> Enum.map(fn {key, subject_weight} ->
      normalize_weight(subject_weight) * normalize_weight(Map.get(policy_weights, to_string(key), 0.0))
    end)
    |> Enum.max(fn -> 0.0 end)
  end

  defp baseline_priority(weights) do
    if Enum.all?([weights[:objective_priors] || %{}, weights[:needs] || %{}, weights[:values] || %{}], &(map_size(&1) == 0)) do
      1.0
    else
      0.0
    end
  end

  defp merge_maps(left, right) when is_map(left) and is_map(right) do
    Map.merge(left, right, fn
      _key, left_value, right_value when is_map(left_value) and is_map(right_value) ->
        merge_maps(left_value, right_value)

      _key, _left_value, right_value ->
        right_value
    end)
  end

  defp presence_or_fallback(map, _fallback) when is_map(map) and map_size(map) > 0, do: stringify_weights(map)
  defp presence_or_fallback(_map, fallback), do: stringify_weights(fallback)

  defp spawn_weights(%DNA{} = dna) do
    %{
      objective_priors:
        if(DNA.speculative?(dna), do: %{"refinement" => 1.0}, else: %{"repair" => 0.9}),
      needs:
        if(DNA.speculative?(dna), do: %{"exploration" => 1.0}, else: %{"stability" => 0.8, "throughput" => 0.6}),
      values:
        if(DNA.safety_critical?(dna), do: %{"safety" => 1.0}, else: %{"learning" => 0.5})
    }
  end

  defp fetch_nested(map, [key | rest]) when is_map(map) do
    value = Map.get(map, key) || Map.get(map, String.to_atom(key))

    case rest do
      [] -> value
      _ -> if is_map(value), do: fetch_nested(value, rest), else: nil
    end
  rescue
    ArgumentError -> Map.get(map, key)
  end

  defp fetch_nested(_map, _path), do: nil

  defp round_metric(value), do: Float.round(normalize_weight(value), 3)

  defp merge_weights(base, overrides) when is_map(base) and is_map(overrides) do
    base
    |> Map.merge(stringify_weights(overrides), fn _key, left, right -> max(normalize_weight(left), normalize_weight(right)) end)
    |> stringify_weights()
  end

  defp stringify_weights(map) do
    Map.new(map, fn {key, value} -> {to_string(key), normalize_weight(value)} end)
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

  defp max_weight([]), do: 1.0
  defp max_weight(values), do: values |> Enum.map(&normalize_weight/1) |> Enum.max(fn -> 1.0 end)
end
