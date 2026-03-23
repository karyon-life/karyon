defmodule Core.DNA do
  @moduledoc """
  Normalizes declarative DNA into an explicit control-plane contract for
  differentiation, metabolic policy, and lifecycle behavior.
  """

  defmodule ControlPlane do
    @moduledoc false

    defstruct [
      :lineage_id,
      :differentiation_role,
      :metabolism,
      :apoptosis,
      :lifecycle,
      :learning
    ]
  end

  defstruct [
    :schema_version,
    :id,
    :file_path,
    :extends,
    :cell_type,
    :description,
    :allowed_actions,
    :subscriptions,
    :synapses,
    :utility_threshold,
    :precision_baseline,
    :atp_requirement,
    :executor,
    :raw_spec,
    :control_plane
  ]

  @type t :: %__MODULE__{}

  @schema_version 1

  def load(file_path) when is_binary(file_path) do
    full_path = Path.expand(file_path)

    with {:ok, raw_spec} <- transcribe(full_path),
         {:ok, resolved_spec} <- resolve_inheritance(raw_spec, full_path),
         {:ok, dna} <- from_spec(resolved_spec, full_path) do
      {:ok, %{dna | extends: normalize_extends(Map.get(stringify_nested(raw_spec), "extends"))}}
    end
  end

  def load!(file_path) when is_binary(file_path) do
    case load(file_path) do
      {:ok, dna} ->
        dna

      {:error, {:invalid_yaml, reason}} ->
        raise reason

      {:error, reason} ->
        raise ArgumentError, dna_error_message(reason, Path.expand(file_path))
    end
  end

  def from_spec(spec, file_path \\ "inline") when is_map(spec) do
    spec = stringify_nested(spec)
    schema_version = normalize_schema_version(Map.get(spec, "schema_version", @schema_version), file_path)
    cell_type = fetch_required_string(spec, "cell_type", file_path)
    allowed_actions = normalize_allowed_actions(Map.get(spec, "allowed_actions", []), file_path)
    synapses = normalize_synapses(Map.get(spec, "synapses", []), file_path)
    subscriptions = normalize_string_list(Map.get(spec, "subscriptions", []), file_path)
    utility_threshold = normalize_number(Map.get(spec, "utility_threshold", 0.5), "utility_threshold", file_path)
    precision_baseline = normalize_number(Map.get(spec, "precision_baseline", 1.0), "precision_baseline", file_path)
    atp_requirement = normalize_number(Map.get(spec, "atp_requirement", 0.0), "atp_requirement", file_path)
    executor = normalize_executor(spec, file_path)

    with {:ok, schema_version} <- schema_version,
         {:ok, cell_type} <- cell_type,
         {:ok, allowed_actions} <- allowed_actions,
         {:ok, synapses} <- synapses,
         {:ok, subscriptions} <- subscriptions,
         {:ok, utility_threshold} <- utility_threshold,
         {:ok, precision_baseline} <- precision_baseline,
         {:ok, atp_requirement} <- atp_requirement,
         {:ok, executor} <- executor do
      dna = %__MODULE__{
        schema_version: schema_version,
        id: normalize_string(Map.get(spec, "id"), file_path),
        file_path: file_path,
        extends: normalize_extends(Map.get(spec, "extends")),
        cell_type: cell_type,
        description: normalize_string(Map.get(spec, "description"), ""),
        allowed_actions: allowed_actions,
        subscriptions: subscriptions,
        synapses: synapses,
        utility_threshold: utility_threshold,
        precision_baseline: precision_baseline,
        atp_requirement: atp_requirement,
        executor: executor,
        raw_spec: stringify_nested(spec)
      }

      {:ok, %{dna | control_plane: build_control_plane(dna)}}
    end
  end

  def from_spec!(spec, file_path \\ "inline") when is_map(spec) do
    case from_spec(spec, file_path) do
      {:ok, dna} -> dna
      {:error, reason} -> raise ArgumentError, dna_error_message(reason, file_path)
    end
  end

  def role(%__MODULE__{control_plane: %ControlPlane{differentiation_role: role}}), do: role
  def lineage_id(%__MODULE__{control_plane: %ControlPlane{lineage_id: lineage_id}}), do: lineage_id
  def allowed_actions(%__MODULE__{allowed_actions: allowed_actions}), do: allowed_actions
  def utility_threshold(%__MODULE__{utility_threshold: threshold}), do: threshold
  def atp_requirement(%__MODULE__{atp_requirement: requirement}), do: requirement
  def executor(%__MODULE__{executor: executor}), do: executor
  def safety_critical?(%__MODULE__{control_plane: %ControlPlane{lifecycle: %{safety_critical: true}}}), do: true
  def safety_critical?(%__MODULE__{}), do: false

  def speculative?(%__MODULE__{control_plane: %ControlPlane{apoptosis: %{speculative: speculative}}}),
    do: speculative

  def to_spec(%__MODULE__{} = dna) do
    %{
      "id" => dna.id,
      "schema_version" => dna.schema_version,
      "extends" => dna.extends,
      "cell_type" => dna.cell_type,
      "description" => dna.description,
      "allowed_actions" => dna.allowed_actions,
      "subscriptions" => dna.subscriptions,
      "synapses" => dna.synapses,
      "utility_threshold" => dna.utility_threshold,
      "precision_baseline" => dna.precision_baseline,
      "atp_requirement" => dna.atp_requirement,
      "executor" => dna.executor
    }
  end

  defp build_control_plane(dna) do
    %ControlPlane{
      lineage_id: dna.id,
      differentiation_role: String.to_atom(dna.cell_type),
      metabolism: %{
        spawn_pressure_refusal: :high,
        atp_requirement: dna.atp_requirement,
        utility_threshold: dna.utility_threshold
      },
      apoptosis: %{
        speculative: Enum.empty?(dna.allowed_actions),
        torpor_synapse_floor: 1,
        prune_on_surprise_over: dna.utility_threshold
      },
      lifecycle: %{
        safety_critical: dna.cell_type in ["orchestrator", "architect_planner"],
        torpor_eligible: dna.cell_type not in ["orchestrator"],
        revive_on: :low,
        apoptosis_priority:
          cond do
            Enum.empty?(dna.allowed_actions) -> 0
            dna.cell_type in ["motor", "motor_executor", "sensory", "sensory_eye"] -> 1
            dna.cell_type in ["orchestrator", "architect_planner"] -> 3
            true -> 2
          end
      },
      learning: %{
        precision_baseline: dna.precision_baseline,
        allowed_actions: dna.allowed_actions
      }
    }
  end

  defp transcribe(file_path) do
    {:ok, Core.YamlParser.transcribe!(file_path)}
  rescue
    error in YamlElixir.ParsingError -> {:error, {:invalid_yaml, error}}
  end

  defp resolve_inheritance(spec, file_path) when is_map(spec) do
    spec = stringify_nested(spec)

    case Map.get(spec, "extends") do
      nil ->
        {:ok, spec}

      parent_path when is_binary(parent_path) ->
        resolved_parent = resolve_relative_path(parent_path, file_path)

        with {:ok, parent_dna} <- load(resolved_parent) do
          parent_spec =
            parent_dna
            |> to_spec()
            |> Map.drop(["id", "extends"])

          {:ok, deep_merge(parent_spec, Map.delete(spec, "extends"))}
        else
          {:error, reason} ->
            {:error, {:invalid_inheritance, resolved_parent, reason}}
        end

      other ->
        {:error, {:invalid_extends, other}}
    end
  end

  defp fetch_required_string(spec, key, file_path) do
    spec
    |> Map.get(key)
    |> normalize_string(nil)
    |> case do
      nil -> {:error, {:missing_required_key, key, file_path}}
      value -> {:ok, value}
    end
  end

  defp normalize_schema_version(value, file_path) do
    case normalize_number(value, "schema_version", file_path) do
      {:ok, parsed} when parsed == @schema_version -> {:ok, trunc(parsed)}
      {:ok, parsed} -> {:error, {:unsupported_schema_version, parsed}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp normalize_synapses([], _file_path), do: {:ok, []}

  defp normalize_synapses(synapses, file_path) when is_list(synapses) do
    synapses
    |> Enum.map(&normalize_synapse(&1, file_path))
    |> collect_results()
  end

  defp normalize_synapses(synapse, file_path) when is_map(synapse) do
    with {:ok, normalized} <- normalize_synapse(synapse, file_path) do
      {:ok, [normalized]}
    end
  end

  defp normalize_synapses(_value, file_path) do
    {:error, {:invalid_synapses, file_path}}
  end

  defp normalize_synapse(config, file_path) when is_map(config) do
    config = stringify_nested(config)

    with {:ok, type} <- fetch_required_string(config, "type", file_path),
         {:ok, bind} <- fetch_required_string(config, "bind", file_path) do
      {:ok, %{"type" => type, "bind" => bind}}
    end
  end

  defp normalize_string_list(values, _file_path) when is_list(values) do
    values
    |> Enum.map(fn value ->
      case normalize_string(value, nil) do
        nil -> {:error, {:invalid_string_list_entry, value}}
        normalized -> {:ok, normalized}
      end
    end)
    |> collect_results()
  end

  defp normalize_string_list(_values, _file_path), do: {:ok, []}

  defp normalize_allowed_actions(values, file_path) do
    with {:ok, normalized} <- normalize_string_list(values, file_path),
         :ok <- validate_allowed_actions(normalized, file_path) do
      {:ok, normalized}
    end
  end

  defp normalize_executor(spec, file_path) when is_map(spec) do
    normalize_executor_config(Map.get(spec, "executor"), file_path)
  end

  defp normalize_executor_config(nil, _file_path), do: {:ok, nil}

  defp normalize_executor_config(config, file_path) when is_map(config) do
    config = stringify_nested(config)

    with {:ok, module_name} <- fetch_required_string(config, "module", file_path),
         {:ok, function_name} <- fetch_required_string(config, "function", file_path) do
      {:ok,
       %{
         "module" => module_name,
         "function" => function_name,
         "default_args" => stringify_nested(Map.get(config, "default_args", %{}))
       }}
    end
  end

  defp normalize_executor_config(_config, file_path) do
    {:error, {:invalid_executor, file_path}}
  end

  defp normalize_number(value, _field, _file_path) when is_float(value), do: {:ok, value}
  defp normalize_number(value, _field, _file_path) when is_integer(value), do: {:ok, value * 1.0}

  defp normalize_number(value, field, file_path) when is_binary(value) do
    case Float.parse(value) do
      {parsed, ""} -> {:ok, parsed}
      _ -> {:error, {:invalid_numeric_value, field, file_path, value}}
    end
  end

  defp normalize_number(_value, field, file_path) do
    {:error, {:invalid_numeric_value, field, file_path, :invalid}}
  end

  defp validate_allowed_actions(actions, file_path) do
    case actions -- Enum.uniq(actions) do
      [] -> :ok
      duplicates -> {:error, {:duplicate_allowed_actions, Enum.uniq(duplicates), file_path}}
    end
  end


  defp resolve_relative_path(path, file_path) do
    file_path
    |> Path.dirname()
    |> Path.join(path)
    |> Path.expand()
  end

  defp deep_merge(parent, child) when is_map(parent) and is_map(child) do
    Map.merge(parent, child, fn _key, parent_value, child_value ->
      if is_map(parent_value) and is_map(child_value) do
        deep_merge(parent_value, child_value)
      else
        child_value
      end
    end)
  end

  defp collect_results(results) do
    Enum.reduce_while(results, {:ok, []}, fn
      {:ok, value}, {:ok, acc} -> {:cont, {:ok, [value | acc]}}
      {:error, reason}, _acc -> {:halt, {:error, reason}}
    end)
    |> case do
      {:ok, values} -> {:ok, Enum.reverse(values)}
      error -> error
    end
  end

  defp normalize_extends(nil), do: nil
  defp normalize_extends(value), do: normalize_string(value, nil)

  defp dna_error_message({:missing_required_key, key, file_path}, _default_path),
    do: "DNA #{file_path} is missing required #{key}"

  defp dna_error_message({:invalid_numeric_value, field, file_path, _value}, _default_path),
    do: "DNA #{file_path} has invalid numeric value for #{field}"

  defp dna_error_message({:unsupported_schema_version, version}, file_path),
    do: "DNA #{file_path} uses unsupported schema_version #{version}"

  defp dna_error_message({:duplicate_allowed_actions, actions, file_path}, _default_path),
    do: "DNA #{file_path} has duplicate allowed_actions: #{Enum.join(actions, ", ")}"

  defp dna_error_message({:invalid_executor, file_path}, _default_path),
    do: "DNA #{file_path} has invalid executor definition"


  defp dna_error_message({:invalid_synapses, file_path}, _default_path),
    do: "DNA #{file_path} has invalid synapses definition"

  defp dna_error_message({:invalid_inheritance, parent_path, reason}, _default_path),
    do: "DNA inheritance from #{parent_path} failed: #{dna_error_message(reason, parent_path)}"

  defp dna_error_message({:invalid_extends, _other}, file_path),
    do: "DNA #{file_path} has invalid extends definition"

  defp dna_error_message({:invalid_string_list_entry, _value}, file_path),
    do: "DNA #{file_path} contains an invalid string list entry"

  defp dna_error_message(other, file_path),
    do: "DNA #{file_path} is invalid: #{inspect(other)}"

  defp normalize_string(nil, default), do: default

  defp normalize_string(value, _default) when is_binary(value) do
    value = String.trim(value)
    if value == "", do: nil, else: value
  end

  defp normalize_string(value, _default) when is_atom(value), do: value |> Atom.to_string() |> String.trim()
  defp normalize_string(_value, default), do: default

  defp stringify_nested(value) when is_map(value) do
    Map.new(value, fn {key, nested_value} ->
      {to_string(key), stringify_nested(nested_value)}
    end)
  end

  defp stringify_nested(value) when is_list(value), do: Enum.map(value, &stringify_nested/1)
  defp stringify_nested(value), do: value
end
