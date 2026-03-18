defmodule Core.ObjectiveManifest do
  @moduledoc """
  Persistent objective-manifest ingestion and localized workspace-plan projection.
  """

  alias Core.Plan
  alias Core.Plan.AbstractState
  alias Core.Plan.Attractor
  alias Core.Sovereignty
  alias Sandbox.MonorepoPipeline

  @plan_schema "karyon.workspace-plan.v1"

  def root_dir do
    Application.get_env(:core, :objectives_root, Path.join(System.user_home!(), ".karyon/objectives"))
  end

  def load_manifests(root_dir \\ root_dir()) do
    expanded = Path.expand(root_dir)

    if File.dir?(expanded) do
      expanded
      |> manifest_files()
      |> Enum.reduce_while({:ok, []}, fn path, {:ok, acc} ->
        case load_manifest(path) do
          {:ok, manifest} -> {:cont, {:ok, [manifest | acc]}}
          {:error, reason} -> {:halt, {:error, reason}}
        end
      end)
      |> case do
        {:ok, manifests} -> {:ok, Enum.reverse(manifests)}
        error -> error
      end
    else
      {:ok, []}
    end
  end

  def manifests_for_workspace(workspace_path, opts \\ []) do
    root = Keyword.get(opts, :root_dir, root_dir())

    with {:ok, manifests} <- load_manifests(root) do
      workspace = Path.expand(workspace_path)
      {:ok, Enum.filter(manifests, &applies_to_workspace?(&1, workspace))}
    end
  end

  def sovereignty_for_workspace(workspace_path, opts \\ []) do
    with {:ok, manifests} <- manifests_for_workspace(workspace_path, opts) do
      base = Sovereignty.current_state()

      merged =
        Enum.reduce(manifests, base, fn manifest, acc ->
          Sovereignty.normalize_state(%{
            hard_mandates: merge_weights(acc.hard_mandates, manifest.hard_mandates),
            soft_values: merge_weights(acc.soft_values, manifest.soft_values),
            evolving_needs: merge_weights(acc.evolving_needs, manifest.evolving_needs),
            objective_priors: merge_weights(acc.objective_priors, manifest.objective_priors),
            precedence: merge_weights(acc.precedence, manifest.precedence)
          })
        end)

      {:ok, Map.put(merged, :manifest_ids, Enum.map(manifests, & &1.id))}
    end
  end

  def rank_attractors(attractors, workspace_path, opts \\ []) when is_list(attractors) do
    with {:ok, sovereignty} <- sovereignty_for_workspace(workspace_path, opts),
         {:ok, manifests} <- manifests_for_workspace(workspace_path, opts) do
      preferred = manifests |> Enum.flat_map(& &1.preferred_attractors) |> MapSet.new()
      policy = Sovereignty.policy_overrides(sovereignty)

      ranked =
        attractors
        |> Enum.map(fn attractor ->
          score = attractor_score(attractor, policy, preferred)
          %{attractor: attractor, score: Float.round(score, 6)}
        end)
        |> Enum.sort_by(&{-&1.score, attractor_id(&1.attractor)})

      {:ok, ranked}
    end
  end

  def enrich_plan(%Plan{} = plan, workspace_path, opts \\ []) do
    with {:ok, sovereignty} <- sovereignty_for_workspace(workspace_path, opts) do
      overrides = Sovereignty.policy_overrides(sovereignty)
      manifest_ids = Map.get(sovereignty, :manifest_ids, [])
      sovereignty_map = sovereignty_to_map(sovereignty)
      %Attractor{} = attractor = plan.attractor
      %AbstractState{} = target_state = attractor.target_state

      enriched_attractor = %Attractor{
        attractor
        | properties:
            attractor.properties
            |> Map.put("workspace_root", Path.expand(workspace_path))
            |> Map.put("objective_manifest_ids", manifest_ids)
            |> Map.put("sovereignty", sovereignty_map),
          needs: merge_weights(attractor.needs, overrides.needs),
          values: merge_weights(attractor.values, overrides.values),
          objective_priors: merge_weights(attractor.objective_priors, overrides.objective_priors),
          target_state:
            %AbstractState{
              target_state
              | needs: merge_weights(target_state.needs, overrides.needs),
                values: merge_weights(target_state.values, overrides.values),
                objective_priors: merge_weights(target_state.objective_priors, overrides.objective_priors)
            }
      }

      {:ok,
       %Plan{
         plan
         | attractor: enriched_attractor,
           transition_delta:
             plan.transition_delta
             |> Map.put(:objective_manifest_ids, manifest_ids)
             |> Map.put(:workspace_root, Path.expand(workspace_path))
             |> Map.put(:workspace_objectives, %{
               "sovereignty" => sovereignty_map,
               "manifest_ids" => manifest_ids
             })
       }}
    end
  end

  def project_workspace_plan(%Plan{} = plan, workspace_path, opts \\ []) do
    with {:ok, workspace_path} <- MonorepoPipeline.validate_target_workspace(workspace_path),
         {:ok, manifests} <- manifests_for_workspace(workspace_path, opts),
         {:ok, sovereignty} <- sovereignty_for_workspace(workspace_path, opts),
         {:ok, enriched_plan} <- enrich_plan(plan, workspace_path, opts),
         :ok <- persist_projection(enriched_plan, workspace_path, manifests, sovereignty, opts),
         {:ok, path, blueprint} <- write_blueprint(enriched_plan, workspace_path, manifests, sovereignty) do
      {:ok, %{plan: enriched_plan, path: path, blueprint: blueprint}}
    end
  end

  defp persist_projection(%Plan{} = plan, workspace_path, manifests, sovereignty, opts) do
    memory_module =
      Keyword.get(opts, :memory_module, Application.get_env(:core, :memory_module, Rhizome.Memory))

    case memory_module.submit_objective_projection(%{
           "workspace_root" => Path.expand(workspace_path),
           "manifest_ids" => Enum.map(manifests, & &1.id),
           "hard_mandates" => sovereignty.hard_mandates,
           "soft_values" => sovereignty.soft_values,
           "evolving_needs" => sovereignty.evolving_needs,
           "objective_priors" => sovereignty.objective_priors,
           "precedence" => sovereignty.precedence,
           "projected_attractors" => [
             %{
               "id" => plan.attractor.id,
               "kind" => plan.attractor.kind,
               "objective_priors" => plan.attractor.objective_priors,
               "needs" => plan.attractor.needs,
               "values" => plan.attractor.values
             }
           ],
           "recorded_at" => plan.created_at
         }) do
      {:ok, _result} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp write_blueprint(%Plan{} = plan, workspace_path, manifests, sovereignty) do
    workspace = Path.expand(workspace_path)
    nexical_dir = Path.join(workspace, ".nexical")
    path = Path.join(nexical_dir, "plan.yml")

    blueprint = %{
      "schema" => @plan_schema,
      "workspace_root" => workspace,
      "workspace_role" => "target_workspace",
      "engine_manifest" => MonorepoPipeline.engine_manifest(),
      "generated_at" => plan.created_at,
      "objective_manifest_ids" => Enum.map(manifests, & &1.id),
      "sovereignty" => sovereignty_to_map(sovereignty),
      "selected_attractor" => Plan.Attractor.to_map(plan.attractor),
      "plan" => Plan.to_execution_payload(plan)
    }

    File.mkdir_p!(nexical_dir)
    File.write!(path, yaml_document(blueprint))

    {:ok, path, blueprint}
  rescue
    error in File.Error -> {:error, {:workspace_plan_write_failed, error.reason}}
  end

  defp load_manifest(path) do
    case YamlElixir.read_from_file(path) do
      {:ok, %{} = document} ->
        {:ok, normalize_manifest(document, path)}

      {:ok, [first | _]} when is_map(first) ->
        {:ok, normalize_manifest(first, path)}

      {:error, reason} ->
        {:error, {:invalid_objective_manifest, path, reason}}

      _ ->
        {:error, {:invalid_objective_manifest, path, :unsupported_shape}}
    end
  end

  defp normalize_manifest(document, path) do
    map = stringify_keys(document)

    sovereignty =
      Sovereignty.normalize_state(%{
        "hard_mandates" => Map.get(map, "hard_mandates", %{}),
        "soft_values" => Map.get(map, "soft_values", %{}),
        "evolving_needs" => Map.get(map, "evolving_needs", %{}),
        "objective_priors" => Map.get(map, "objective_priors", %{}),
        "precedence" => Map.get(map, "precedence", %{})
      })

    %{
      id: Map.get(map, "id", Path.basename(path, Path.extname(path))),
      source_path: path,
      workspace_match: normalize_string_list(Map.get(map, "workspace_match") || Map.get(map, "workspaces") || []),
      preferred_attractors: normalize_string_list(Map.get(map, "preferred_attractors") || []),
      hard_mandates: sovereignty.hard_mandates,
      soft_values: sovereignty.soft_values,
      evolving_needs: sovereignty.evolving_needs,
      objective_priors: sovereignty.objective_priors,
      precedence: sovereignty.precedence
    }
  end

  defp manifest_files(root_dir) do
    [Path.join(root_dir, "*.yml"), Path.join(root_dir, "*.yaml")]
    |> Enum.flat_map(&Path.wildcard/1)
    |> Enum.sort()
  end

  defp applies_to_workspace?(manifest, workspace_path) do
    case manifest.workspace_match do
      [] ->
        true

      patterns ->
        Enum.any?(patterns, fn pattern ->
          expanded = Path.expand(pattern)

          cond do
            wildcard?(pattern) -> workspace_path in Path.wildcard(expanded)
            true -> expanded == workspace_path
          end
        end)
    end
  end

  defp wildcard?(pattern), do: String.contains?(pattern, ["*", "?", "[", "{"])

  defp attractor_score(%Attractor{} = attractor, policy, preferred) do
    score_map(attractor.objective_priors, policy.objective_priors) +
      score_map(attractor.needs, policy.needs) +
      score_map(attractor.values, policy.values) +
      if(MapSet.member?(preferred, attractor.id), do: 2.0, else: 0.0)
  end

  defp attractor_score(attractor, policy, preferred) when is_map(attractor) do
    attractor_score(
      %Attractor{
        id: attractor_id(attractor),
        kind: Map.get(attractor, :kind) || Map.get(attractor, "kind") || "SuperNode",
        properties: %{},
        target_state: %AbstractState{
          entity: attractor_id(attractor),
          phase: "target",
          summary: attractor_id(attractor),
          attributes: %{},
          needs: %{},
          values: %{},
          objective_priors: %{}
        },
        objective_priors: Map.get(attractor, :objective_priors) || Map.get(attractor, "objective_priors") || %{},
        needs: Map.get(attractor, :needs) || Map.get(attractor, "needs") || %{},
        values: Map.get(attractor, :values) || Map.get(attractor, "values") || %{}
      },
      policy,
      preferred
    )
  end

  defp attractor_id(%Attractor{id: id}), do: id
  defp attractor_id(attractor), do: Map.get(attractor, :id) || Map.get(attractor, "id") || "unknown_attractor"

  defp score_map(subject, policy) do
    subject
    |> stringify_keys()
    |> Enum.map(fn {key, weight} ->
      normalize_weight(weight) * normalize_weight(Map.get(policy, to_string(key), 0.0))
    end)
    |> Enum.max(fn -> 0.0 end)
  end

  defp yaml_document(map), do: encode_yaml(map, 0)

  defp encode_yaml(map, indent) when is_map(map) do
    map
    |> Enum.map(fn {key, value} ->
      prefix = String.duplicate("  ", indent) <> "#{key}:"

      cond do
        is_map(value) and map_size(value) > 0 -> prefix <> "\n" <> encode_yaml(value, indent + 1)
        is_list(value) and value != [] -> prefix <> "\n" <> encode_yaml(value, indent + 1)
        is_map(value) -> prefix <> " {}\n"
        value == [] -> prefix <> " []\n"
        true -> prefix <> " " <> yaml_scalar(value) <> "\n"
      end
    end)
    |> Enum.join()
  end

  defp encode_yaml(list, indent) when is_list(list) do
    Enum.map_join(list, "", fn item ->
      prefix = String.duplicate("  ", indent) <> "-"

      cond do
        is_map(item) and map_size(item) > 0 ->
          [first_key | _] = Map.keys(item)
          nested = encode_yaml(item, indent + 1)
          String.replace_leading(nested, String.duplicate("  ", indent + 1) <> "#{first_key}:", "#{prefix} #{first_key}:")

        is_map(item) ->
          prefix <> " {}\n"

        is_list(item) and item != [] ->
          prefix <> "\n" <> encode_yaml(item, indent + 1)

        true ->
          prefix <> " " <> yaml_scalar(item) <> "\n"
      end
    end)
  end

  defp yaml_scalar(value) when is_binary(value), do: inspect(value)
  defp yaml_scalar(value) when is_boolean(value), do: to_string(value)
  defp yaml_scalar(value) when is_integer(value) or is_float(value), do: to_string(value)
  defp yaml_scalar(nil), do: "null"
  defp yaml_scalar(value), do: inspect(to_string(value))

  defp merge_weights(left, right) when is_map(left) and is_map(right) do
    Map.merge(stringify_keys(left), stringify_keys(right), fn _key, left_value, right_value ->
      max(normalize_weight(left_value), normalize_weight(right_value))
    end)
  end

  defp merge_weights(left, _right) when is_map(left), do: stringify_keys(left)
  defp merge_weights(_left, right) when is_map(right), do: stringify_keys(right)
  defp merge_weights(_left, _right), do: %{}

  defp normalize_string_list(list) when is_list(list), do: Enum.map(list, &to_string/1)
  defp normalize_string_list(value) when is_binary(value), do: [value]
  defp normalize_string_list(_), do: []

  defp stringify_keys(map) when is_map(map) do
    Map.new(map, fn
      {key, value} when is_map(value) -> {to_string(key), stringify_keys(value)}
      {key, value} when is_list(value) -> {to_string(key), Enum.map(value, &stringify_nested/1)}
      {key, value} -> {to_string(key), value}
    end)
  end

  defp stringify_nested(value) when is_map(value), do: stringify_keys(value)
  defp stringify_nested(value) when is_list(value), do: Enum.map(value, &stringify_nested/1)
  defp stringify_nested(value), do: value

  defp sovereignty_to_map(sovereignty) do
    sovereignty
    |> Map.drop([:manifest_ids])
    |> Sovereignty.to_map()
  end

  defp normalize_weight(value) when is_float(value), do: value
  defp normalize_weight(value) when is_integer(value), do: value * 1.0

  defp normalize_weight(value) when is_binary(value) do
    case Float.parse(value) do
      {parsed, _} -> parsed
      :error -> 0.0
    end
  end

  defp normalize_weight(_), do: 0.0
end
