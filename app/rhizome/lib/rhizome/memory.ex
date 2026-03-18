defmodule Rhizome.Memory do
  @moduledoc """
  High-level interface for Tier-0 and Tier-1 memory operations.
  """
  require Logger
  alias Rhizome.MemoryTopology

  @doc """
  Returns the explicit Rhizome topology contract for working graph state,
  temporal archive state, and consolidation flow.
  """
  def topology_contract, do: MemoryTopology.contract()

  @doc """
  Returns the topology descriptor for a specific memory operation.
  """
  def topology_for(operation), do: MemoryTopology.operation_descriptor!(operation)

  @doc """
  Executes a typed topology query against Memgraph (Tier-0).
  """
  def query_working_memory(spec) when is_map(spec) do
    with_topology(:query_working_memory, fn -> query_memgraph(spec) end)
  end

  def query_working_memory(_opaque_query), do: {:error, :opaque_working_memory_query_forbidden}

  @doc """
  Executes a typed topology query against Memgraph (Tier-0).
  """
  def query_memgraph(spec) when is_map(spec) do
    with_topology(:query_memgraph, fn ->
      with {:ok, normalized} <- normalize_graph_query(spec) do
        run_memgraph_query(build_graph_query(normalized))
      end
    end)
  end

  def query_memgraph(_opaque_query), do: {:error, :opaque_graph_query_forbidden}

  @doc """
  Upserts a typed graph node into working memory.
  """
  def upsert_graph_node(spec) when is_map(spec) do
    with_topology(:upsert_graph_node, fn ->
      with {:ok, normalized} <- normalize_graph_node(spec),
           {:ok, _rows} <- run_memgraph_query(upsert_graph_node_query(normalized)) do
        {:ok, normalized}
      end
    end)
  end

  def upsert_graph_node(_spec), do: {:error, :invalid_graph_node}

  @doc """
  Upserts a typed graph relationship into working memory.
  """
  def relate_graph_nodes(spec) when is_map(spec) do
    with_topology(:relate_graph_nodes, fn ->
      with {:ok, normalized} <- normalize_graph_relationship(spec),
           {:ok, _rows} <- run_memgraph_query(relate_graph_nodes_query(normalized)) do
        {:ok, normalized}
      end
    end)
  end

  def relate_graph_nodes(_spec), do: {:error, :invalid_graph_relationship}

  @doc """
  Persists a pooled co-occurrence abstraction and reinforces the pathway
  between the participating graph types.
  """
  def persist_pooled_pattern(spec) when is_map(spec) do
    with_topology(:persist_pooled_pattern, fn ->
      with {:ok, normalized} <- normalize_pooled_pattern(spec),
           {:ok, _pattern} <-
             upsert_graph_node(%{
               label: "PooledPattern",
               id: normalized.id,
               properties: %{
                 signature: normalized.signature,
                 language: normalized.language,
                 occurrences: normalized.occurrences,
                 pool_type: normalized.pool_type,
                 source_types: Enum.join(normalized.source_types, ",")
               }
             }),
           {:ok, _left} <-
             upsert_graph_node(%{
               label: "PatternType",
               id: normalized.left_type_id,
               properties: %{name: hd(normalized.source_types), language: normalized.language}
             }),
           {:ok, _right} <-
             upsert_graph_node(%{
               label: "PatternType",
               id: normalized.right_type_id,
               properties: %{name: List.last(normalized.source_types), language: normalized.language}
             }),
           {:ok, _} <-
             relate_graph_nodes(%{
               from: %{label: "PatternType", id: normalized.left_type_id},
               to: %{label: "PooledPattern", id: normalized.id},
               relationship_type: "ABSTRACTS",
               properties: %{occurrences: normalized.occurrences, pool_type: normalized.pool_type}
             }),
           {:ok, _} <-
             relate_graph_nodes(%{
               from: %{label: "PatternType", id: normalized.right_type_id},
               to: %{label: "PooledPattern", id: normalized.id},
               relationship_type: "ABSTRACTS",
               properties: %{occurrences: normalized.occurrences, pool_type: normalized.pool_type}
             }),
           {:ok, pathway} <-
             Rhizome.Native.reinforce_pathway(%{
               from_id: normalized.left_type_id,
               to_id: normalized.right_type_id,
               relationship_type: "CO_OCCURS_WITH",
               weight_delta: normalized.weight_delta,
               trace_id: normalized.id,
               source_step_id: normalized.left_type_id,
               target_id: normalized.right_type_id
             }) do
        {:ok, %{pattern_id: normalized.id, pathway: pathway, occurrences: normalized.occurrences}}
      end
    end)
  end

  def persist_pooled_pattern(_spec), do: {:error, :invalid_pooled_pattern}

  @doc """
  Submits a bitemporal transaction to XTDB (Tier-1).
  """
  def write_archive_document(id, data) when is_binary(id) and is_map(data) do
    with_topology(:write_archive_document, fn -> submit_xtdb(id, data) end)
  end

  def write_archive_document(_id, data) when is_binary(data), do: {:error, :opaque_archive_document_forbidden}
  def write_archive_document(_id, _data), do: {:error, :invalid_archive_document}

  @doc """
  Queries the immutable temporal archive (Tier-1).
  """
  def query_archive(query) when is_map(query) do
    with_topology(:query_archive, fn -> Rhizome.Native.xtdb_query(query) end)
  end

  def query_archive(_opaque_query), do: {:error, :invalid_archive_query}

  @doc """
  Projects active working-memory state into the temporal archive.
  """
  def bridge_working_memory_to_archive do
    with_topology(:bridge_working_memory_to_archive, fn -> Rhizome.Native.bridge_to_xtdb() end)
  end

  @doc """
  Submits a bitemporal transaction to XTDB (Tier-1).
  """
  def submit_xtdb(id, data) when is_binary(id) and is_map(data) do
    with_topology(:submit_xtdb, fn -> Rhizome.Native.xtdb_submit(id, Jason.encode!(data)) end)
  end

  def submit_xtdb(_id, data) when is_binary(data), do: {:error, :opaque_archive_document_forbidden}
  def submit_xtdb(_id, _data), do: {:error, :invalid_xtdb_document}

  @doc """
  Persists a motor execution outcome into XTDB and projects a summary edge back into Memgraph.
  """
  def submit_execution_outcome(outcome) when is_map(outcome) do
    with_topology(:submit_execution_outcome, fn ->
      document =
        outcome
        |> stringify_keys()
        |> Map.put_new("recorded_at", System.system_time(:second))

      with id when is_binary(id) <- execution_outcome_id(document),
           {:ok, xtdb_result} <- submit_xtdb(id, document),
           :ok <- project_execution_outcome(document) do
        {:ok, %{id: id, xtdb: xtdb_result}}
      else
        {:error, reason} -> {:error, reason}
        _ -> {:error, :invalid_execution_outcome}
      end
    end)
  end

  def submit_execution_outcome(_outcome), do: {:error, :invalid_execution_outcome}

  @doc """
  Persists a typed prediction error into XTDB and projects a summary edge back into Memgraph.
  """
  def submit_prediction_error(prediction_error) when is_map(prediction_error) do
    with_topology(:submit_prediction_error, fn ->
      document =
        prediction_error
        |> stringify_keys()
        |> Map.put_new("recorded_at", System.system_time(:second))

      with id when is_binary(id) <- prediction_error_id(document),
           {:ok, xtdb_result} <- submit_xtdb(id, document),
           :ok <- project_prediction_error(document) do
        {:ok, %{id: id, xtdb: xtdb_result}}
      else
        {:error, reason} -> {:error, reason}
        _ -> {:error, :invalid_prediction_error}
      end
    end)
  end

  def submit_prediction_error(_prediction_error), do: {:error, :invalid_prediction_error}

  @doc """
  Persists a typed operator feedback event into XTDB and projects a bounded
  socio-linguistic correction edge back into Memgraph.
  """
  def submit_operator_feedback_event(event) when is_map(event) do
    with_topology(:submit_operator_feedback_event, fn ->
      document =
        event
        |> stringify_keys()
        |> Map.put_new("recorded_at", System.system_time(:second))

      with :ok <- validate_operator_feedback_event(document),
           id when is_binary(id) <- operator_feedback_event_id(document),
           {:ok, xtdb_result} <- submit_xtdb(id, document),
           :ok <- project_operator_feedback_event(document) do
        {:ok, %{id: id, xtdb: xtdb_result}}
      else
        {:error, reason} -> {:error, reason}
        _ -> {:error, :invalid_operator_feedback_event}
      end
    end)
  end

  def submit_operator_feedback_event(_event), do: {:error, :invalid_operator_feedback_event}

  @doc """
  Persists a differentiation decision into XTDB and projects a summary edge into Memgraph.
  """
  def submit_differentiation_event(event) when is_map(event) do
    with_topology(:submit_differentiation_event, fn ->
      document =
        event
        |> stringify_keys()
        |> Map.put_new("recorded_at", System.system_time(:second))

      with id when is_binary(id) <- differentiation_event_id(document),
           {:ok, xtdb_result} <- submit_xtdb(id, document),
           :ok <- project_differentiation_event(document) do
        {:ok, %{id: id, xtdb: xtdb_result}}
      else
        {:error, reason} -> {:error, reason}
        _ -> {:error, :invalid_differentiation_event}
      end
    end)
  end

  def submit_differentiation_event(_event), do: {:error, :invalid_differentiation_event}

  @doc """
  Loads the latest durable state snapshot for a cell lineage.
  """
  def load_cell_state(lineage_id) when is_binary(lineage_id) and lineage_id != "" do
    with_topology(:load_cell_state, fn ->
      query = %{
        "query" => %{
          "find" => ["(pull ?e [beliefs expectations atp_metabolism status dna_path lineage_id])"],
          "where" => [["?e", "xt/id", cell_state_id(lineage_id)]]
        }
      }

      case Rhizome.Native.xtdb_query(query) do
        {:ok, [%{} = state | _]} -> {:ok, state}
        {:ok, [[%{} = state] | _]} -> {:ok, state}
        {:ok, [%{"data" => %{} = state} | _]} -> {:ok, state}
        {:ok, _} -> {:error, :not_found}
        {:error, reason} -> {:error, reason}
        _ -> {:error, :not_found}
      end
    end)
  end

  def load_cell_state(_lineage_id), do: {:error, :invalid_lineage_id}

  @doc """
  Persists a durable state snapshot for a cell lineage.
  """
  def checkpoint_cell_state(snapshot) when is_map(snapshot) do
    with_topology(:checkpoint_cell_state, fn ->
      document =
        snapshot
        |> stringify_keys()
        |> Map.put_new("recorded_at", System.system_time(:second))

      with lineage_id when is_binary(lineage_id) and lineage_id != "" <- Map.get(document, "lineage_id"),
           {:ok, xtdb_result} <- submit_xtdb(cell_state_id(lineage_id), document) do
        {:ok, %{id: cell_state_id(lineage_id), xtdb: xtdb_result}}
      else
        {:error, reason} -> {:error, reason}
        _ -> {:error, :invalid_cell_state}
      end
    end)
  end

  def checkpoint_cell_state(_snapshot), do: {:error, :invalid_cell_state}

  @doc """
  Normalizes an abstract-state document so planning and telemetry can persist
  the same typed state shape at the Rhizome boundary.
  """
  def normalize_abstract_state(state) when is_map(state) do
    with_topology(:normalize_abstract_state, fn ->
      %{
        "entity" => to_string(Map.get(state, "entity") || Map.get(state, :entity) || "unknown"),
        "phase" => to_string(Map.get(state, "phase") || Map.get(state, :phase) || "unknown"),
        "summary" => to_string(Map.get(state, "summary") || Map.get(state, :summary) || "unknown"),
        "attributes" => stringify_keys(Map.get(state, "attributes") || Map.get(state, :attributes) || %{}),
        "needs" => normalize_weight_map(Map.get(state, "needs") || Map.get(state, :needs) || %{}),
        "values" => normalize_weight_map(Map.get(state, "values") || Map.get(state, :values) || %{}),
        "objective_priors" => normalize_weight_map(Map.get(state, "objective_priors") || Map.get(state, :objective_priors) || %{})
      }
    end)
  end

  def normalize_abstract_state(_state), do: %{}

  defp execution_outcome_id(%{"id" => id}) when is_binary(id) and id != "", do: id

  defp execution_outcome_id(document) do
    cell_id = Map.get(document, "cell_id", "unknown_cell")
    action = Map.get(document, "action", "unknown_action")
    timestamp = Map.get(document, "recorded_at", System.system_time(:second))
    "execution_outcome:#{cell_id}:#{action}:#{timestamp}"
  end

  defp prediction_error_id(%{"id" => id}) when is_binary(id) and id != "", do: id

  defp prediction_error_id(document) do
    cell_id = Map.get(document, "cell_id", "unknown_cell")
    type = Map.get(document, "type", "unknown")
    timestamp = Map.get(document, "recorded_at", System.system_time(:second))
    "prediction_error:#{cell_id}:#{type}:#{timestamp}"
  end

  defp operator_feedback_event_id(%{"id" => id}) when is_binary(id) and id != "", do: id

  defp operator_feedback_event_id(document) do
    template_id = Map.get(document, "template_id", "unknown_template")
    feedback_kind = Map.get(document, "feedback_kind", "feedback")
    timestamp = Map.get(document, "recorded_at", System.system_time(:second))
    "operator_feedback:#{template_id}:#{feedback_kind}:#{timestamp}"
  end

  defp validate_operator_feedback_event(%{
         "feedback_kind" => feedback_kind,
         "template_id" => template_id,
         "target_path" => target_path,
         "scope" => "socio_linguistic"
       })
       when is_binary(feedback_kind) and feedback_kind != "" and is_binary(template_id) and template_id != "" and
              is_binary(target_path) and target_path != "" do
    :ok
  end

  defp validate_operator_feedback_event(_document), do: {:error, :invalid_operator_feedback_event}

  defp cell_state_id(lineage_id), do: "cell_state:#{lineage_id}"

  defp differentiation_event_id(%{"id" => id}) when is_binary(id) and id != "", do: id

  defp differentiation_event_id(document) do
    lineage_id = Map.get(document, "lineage_id", "unknown_lineage")
    role = Map.get(document, "role", "unknown_role")
    timestamp = Map.get(document, "recorded_at", System.system_time(:second))
    "differentiation_event:#{lineage_id}:#{role}:#{timestamp}"
  end

  defp project_execution_outcome(document) do
    with {:ok, _cell} <- upsert_graph_node(%{label: "Cell", id: Map.get(document, "cell_id", "unknown_cell")}),
         {:ok, _outcome} <-
           upsert_graph_node(%{
             label: "ExecutionOutcome",
             id: execution_outcome_id(document),
             properties: %{
               action: Map.get(document, "action", "unknown_action"),
               status: Map.get(document, "status", "unknown"),
               executor: Map.get(document, "executor", "unknown"),
               vm_id: Map.get(document, "vm_id", "none"),
               exit_code: normalize_numeric(document["exit_code"]),
               recorded_at: Map.get(document, "recorded_at", System.system_time(:second))
             }
           }),
         {:ok, _edge} <-
           relate_graph_nodes(%{
             from: %{label: "Cell", id: Map.get(document, "cell_id", "unknown_cell")},
             to: %{label: "ExecutionOutcome", id: execution_outcome_id(document)},
             relationship_type: "EMITTED"
           }) do
      :ok
    else
      {:error, reason} ->
        Logger.warning("[Rhizome.Memory] Memgraph projection of execution outcome failed: #{inspect(reason)}")
        :ok
    end
  end

  defp project_prediction_error(document) do
    correction_type = prediction_correction_type(document)
    correction_status = prediction_correction_status(document)
    correction_id = "graph_correction:#{prediction_error_id(document)}"
    correction_targets = prediction_correction_targets(document)

    with {:ok, _cell} <- upsert_graph_node(%{label: "Cell", id: Map.get(document, "cell_id", "unknown_cell")}),
         {:ok, _prediction_error} <-
           upsert_graph_node(%{
             label: "PredictionError",
             id: prediction_error_id(document),
             properties: %{
               type: Map.get(document, "type", "unknown"),
               message: Map.get(document, "message", ""),
               status: Map.get(document, "status", "observed"),
               schema_version: prediction_schema_version(document),
                source_cell_id: Map.get(document, "source_cell_id", "unknown"),
                vfe: normalize_float(document["vfe"]),
                atp: normalize_float(document["atp"]),
                observed_at: Map.get(document, "observed_at", Map.get(document, "recorded_at", iso_timestamp())),
                recorded_at: Map.get(document, "recorded_at", iso_timestamp()),
                timestamp_unit: Map.get(document, "timestamp_unit", "iso8601")
             }
           }),
         {:ok, _edge} <-
           relate_graph_nodes(%{
             from: %{label: "Cell", id: Map.get(document, "cell_id", "unknown_cell")},
             to: %{label: "PredictionError", id: prediction_error_id(document)},
             relationship_type: "EXPERIENCED"
           }),
         {:ok, _correction} <-
           upsert_graph_node(%{
             label: "GraphCorrection",
             id: correction_id,
             properties: %{
               correction_type: correction_type,
               correction_status: correction_status,
               source_prediction_error_id: prediction_error_id(document),
               target_count: length(correction_targets),
               recorded_at: Map.get(document, "recorded_at", iso_timestamp())
             }
           }),
         {:ok, _triggered_edge} <-
           relate_graph_nodes(%{
             from: %{label: "PredictionError", id: prediction_error_id(document)},
             to: %{label: "GraphCorrection", id: correction_id},
             relationship_type: "TRIGGERED"
           }) do
      relate_prediction_correction_targets(correction_id, correction_targets)
      :ok
    else
      {:error, reason} ->
        Logger.warning("[Rhizome.Memory] Memgraph projection of prediction error failed: #{inspect(reason)}")
        :ok
    end
  end

  defp project_operator_feedback_event(document) do
    feedback_id = operator_feedback_event_id(document)
    template_id = Map.get(document, "template_id", "unknown_template")
    target_path = Map.get(document, "target_path", "unknown_path")
    pathway_update = Map.get(document, "pathway_update", %{})

    with {:ok, _feedback} <-
           upsert_graph_node(%{
             label: "OperatorFeedbackEvent",
             id: feedback_id,
             properties: %{
               feedback_kind: Map.get(document, "feedback_kind", "friction"),
               friction_level: Map.get(document, "friction_level", "medium"),
               scope: Map.get(document, "scope", "socio_linguistic"),
               target_domain: Map.get(document, "target_domain", "operator_output"),
               target_path: target_path
             }
           }),
         {:ok, _template} <-
           upsert_graph_node(%{
             label: "OperatorTemplate",
             id: template_id,
             properties: %{template_id: template_id, target_path: target_path}
           }),
         {:ok, _rel} <-
           relate_graph_nodes(%{
             from: %{label: "OperatorFeedbackEvent", id: feedback_id},
             to: %{label: "OperatorTemplate", id: template_id},
             relationship_type: "AFFECTS_TEMPLATE",
             properties: %{
               update_type: Map.get(pathway_update, "type", "observe_only"),
               weight_delta: Map.get(pathway_update, "weight_delta", 0.0),
               target_path: target_path
             }
           }) do
      :ok
    end
  end

  defp project_differentiation_event(document) do
    with {:ok, _cell} <- upsert_graph_node(%{label: "Cell", id: Map.get(document, "lineage_id", "unknown_lineage")}),
         {:ok, _event} <-
           upsert_graph_node(%{
             label: "DifferentiationEvent",
             id: differentiation_event_id(document),
             properties: %{
               role: Map.get(document, "role", "unknown_role"),
               pressure: Map.get(document, "pressure", "unknown"),
               source: Map.get(document, "source", "epigenetic_supervisor"),
               status: Map.get(document, "status", "selected"),
               dna_path: Map.get(document, "dna_path", "unknown"),
               recorded_at: Map.get(document, "recorded_at", System.system_time(:second))
             }
           }),
         {:ok, _edge} <-
           relate_graph_nodes(%{
             from: %{label: "Cell", id: Map.get(document, "lineage_id", "unknown_lineage")},
             to: %{label: "DifferentiationEvent", id: differentiation_event_id(document)},
             relationship_type: "DIFFERENTIATED_AS"
           }) do
      :ok
    else
      {:error, reason} ->
        Logger.warning("[Rhizome.Memory] Memgraph projection of differentiation event failed: #{inspect(reason)}")
        :ok
    end
  end

  defp normalize_graph_query(spec) do
    label = normalize_graph_label(Map.get(spec, :label) || Map.get(spec, "label"))
    filters = normalize_graph_properties(Map.get(spec, :filters) || Map.get(spec, "filters") || %{})
    return_fields = normalize_return_fields(Map.get(spec, :return) || Map.get(spec, "return") || [:node])
    limit = normalize_limit(Map.get(spec, :limit) || Map.get(spec, "limit") || 50)

    if is_nil(label) or filters == :invalid or return_fields == :invalid or is_nil(limit) do
      {:error, :invalid_graph_query}
    else
      {:ok, %{label: label, filters: filters, return_fields: return_fields, limit: limit}}
    end
  end

  defp normalize_graph_node(spec) do
    label = normalize_graph_label(Map.get(spec, :label) || Map.get(spec, "label"))
    id = normalize_graph_id(Map.get(spec, :id) || Map.get(spec, "id"))

    properties =
      spec
      |> Map.get(:properties, Map.get(spec, "properties", %{}))
      |> normalize_graph_properties()

    if is_nil(label) or is_nil(id) or properties == :invalid do
      {:error, :invalid_graph_node}
    else
      {:ok, %{label: label, id: id, properties: Map.put(properties, "id", id)}}
    end
  end

  defp normalize_graph_relationship(spec) do
    with {:ok, from} <- normalize_graph_reference(Map.get(spec, :from) || Map.get(spec, "from")),
         {:ok, to} <- normalize_graph_reference(Map.get(spec, :to) || Map.get(spec, "to")),
         relationship_type when not is_nil(relationship_type) <-
           normalize_relationship_type(
             Map.get(spec, :relationship_type) || Map.get(spec, "relationship_type") || "RELATED_TO"
           ),
         properties <-
           normalize_graph_properties(Map.get(spec, :properties) || Map.get(spec, "properties") || %{}),
         false <- properties == :invalid do
      {:ok, %{from: from, to: to, relationship_type: relationship_type, properties: properties}}
    else
      _ -> {:error, :invalid_graph_relationship}
    end
  end

  defp normalize_graph_reference(spec) when is_map(spec) do
    label = normalize_graph_label(Map.get(spec, :label) || Map.get(spec, "label"))
    id = normalize_graph_id(Map.get(spec, :id) || Map.get(spec, "id"))

    if is_nil(label) or is_nil(id), do: {:error, :invalid_graph_reference}, else: {:ok, %{label: label, id: id}}
  end

  defp normalize_graph_reference(_spec), do: {:error, :invalid_graph_reference}

  defp normalize_pooled_pattern(spec) do
    language = normalize_graph_id(Map.get(spec, :language) || Map.get(spec, "language") || "unknown")
    pool_type = normalize_graph_id(Map.get(spec, :pool_type) || Map.get(spec, "pool_type") || "co_occurrence")
    source_types = normalize_source_types(Map.get(spec, :source_types) || Map.get(spec, "source_types"))
    occurrences = normalize_occurrences(Map.get(spec, :occurrences) || Map.get(spec, "occurrences"))

    case {language, pool_type, source_types, occurrences} do
      {nil, _, _, _} -> {:error, :invalid_pooled_pattern}
      {_, _, :invalid, _} -> {:error, :invalid_pooled_pattern}
      {_, _, _, nil} -> {:error, :invalid_pooled_pattern}
      {language, pool_type, [left, right] = source_types, occurrences} ->
        signature = "#{left}->#{right}"

        {:ok,
         %{
           id: normalize_graph_id(Map.get(spec, :id) || Map.get(spec, "id") || "pool:#{language}:#{signature}"),
           language: language,
           pool_type: pool_type,
           source_types: source_types,
           signature: signature,
           occurrences: occurrences,
           left_type_id: "pattern_type:#{language}:#{left}",
           right_type_id: "pattern_type:#{language}:#{right}",
           weight_delta: max(0.1, occurrences / 2)
         }}

      _ ->
        {:error, :invalid_pooled_pattern}
    end
  end

  defp build_graph_query(%{label: label, filters: filters, return_fields: return_fields, limit: limit}) do
    where_clause =
      case property_match_clause("n", filters) do
        "" -> ""
        properties -> " #{properties}"
      end

    return_clause =
      case return_fields do
        [:node] ->
          "RETURN properties(n) AS node"

        fields ->
          "RETURN " <>
            Enum.map_join(fields, ", ", fn field ->
              normalized = escape_cypher(field)
              "n.#{normalized} AS #{normalized}"
            end)
      end

    "MATCH (n:#{label})#{where_clause} #{return_clause} LIMIT #{limit}"
  end

  defp upsert_graph_node_query(%{label: label, properties: properties}) do
    """
    MERGE (n:#{label} {id: #{property_literal(properties["id"])}})
    #{set_properties_clause("n", Map.delete(properties, "id"))}
    RETURN n.id AS id
    """
  end

  defp relate_graph_nodes_query(%{from: from, to: to, relationship_type: relationship_type, properties: properties}) do
    set_clause = set_properties_clause("r", properties)

    """
    MERGE (from:#{from.label} {id: #{property_literal(from.id)}})
    MERGE (to:#{to.label} {id: #{property_literal(to.id)}})
    MERGE (from)-[r:#{relationship_type}]->(to)
    #{set_clause}
    RETURN type(r) AS relationship_type
    """
  end

  defp property_match_clause(_binding, properties) when map_size(properties) == 0, do: ""

  defp property_match_clause(binding, properties) do
    conditions =
      Enum.map_join(properties, " AND ", fn {key, value} ->
        "#{binding}.#{escape_cypher(key)} = #{property_literal(value)}"
      end)

    "WHERE #{conditions}"
  end

  defp set_properties_clause(_binding, properties) when map_size(properties) == 0, do: ""

  defp set_properties_clause(binding, properties) do
    assignments =
      Enum.map_join(properties, ",\n    ", fn {key, value} ->
        "#{binding}.#{escape_cypher(key)} = #{property_literal(value)}"
      end)

    "SET #{assignments}"
  end

  defp property_literal(value) when is_binary(value), do: "'#{escape_cypher(value)}'"
  defp property_literal(value) when is_boolean(value), do: if(value, do: "true", else: "false")
  defp property_literal(value) when is_integer(value), do: Integer.to_string(value)
  defp property_literal(value) when is_float(value), do: :erlang.float_to_binary(value, [:compact, decimals: 10])
  defp property_literal(value) when is_atom(value), do: value |> Atom.to_string() |> property_literal()
  defp property_literal(value), do: value |> to_string() |> property_literal()

  defp normalize_graph_label(value) do
    value
    |> normalize_string()
    |> case do
      nil ->
        nil

      normalized ->
        normalized
        |> String.replace(~r/[^A-Za-z0-9_]/, "")
        |> case do
          "" -> nil
          clean -> clean
        end
    end
  end

  defp normalize_graph_id(nil), do: nil

  defp normalize_graph_id(value) do
    value
    |> normalize_string()
    |> case do
      nil -> nil
      "" -> nil
      normalized -> normalized
    end
  end

  defp normalize_graph_properties(map) when is_map(map) do
    Enum.reduce_while(map, %{}, fn {key, value}, acc ->
      normalized_key = normalize_property_key(key)

      cond do
        is_nil(normalized_key) ->
          {:halt, :invalid}

        is_map(value) or is_list(value) ->
          {:halt, :invalid}

        true ->
          {:cont, Map.put(acc, normalized_key, normalize_property_value(value))}
      end
    end)
  end

  defp normalize_graph_properties(_), do: :invalid

  defp normalize_source_types(types) when is_list(types) do
    types
    |> Enum.map(&normalize_graph_label/1)
    |> Enum.reject(&is_nil/1)
    |> case do
      [left, right] -> [left, right]
      _ -> :invalid
    end
  end

  defp normalize_source_types(_), do: :invalid

  defp normalize_occurrences(value) when is_integer(value) and value > 0, do: value
  defp normalize_occurrences(value) when is_float(value) and value > 0, do: trunc(Float.ceil(value))
  defp normalize_occurrences(_), do: nil

  defp prediction_schema_version(document) do
    document
    |> Map.get("metadata", %{})
    |> case do
      %{} = metadata -> Map.get(metadata, "schema_version", "2026-03-18")
      _ -> "2026-03-18"
    end
  end

  defp prediction_correction_type(document) do
    document
    |> Map.get("metadata", %{})
    |> case do
      %{} = metadata -> Map.get(metadata, "correction_type", "observe_only")
      _ -> "observe_only"
    end
  end

  defp prediction_correction_status(document) do
    document
    |> Map.get("metadata", %{})
    |> case do
      %{} = metadata -> Map.get(metadata, "correction_status", "observed")
      _ -> "observed"
    end
  end

  defp prediction_correction_targets(document) do
    document
    |> Map.get("metadata", %{})
    |> case do
      %{"correction_targets" => targets} when is_list(targets) -> Enum.map(targets, &stringify_keys/1)
      _ -> []
    end
  end

  defp relate_prediction_correction_targets(correction_id, targets) do
    Enum.each(targets, fn target ->
      target_id = Map.get(target, "to_id", "unknown_target")
      target_kind = Map.get(target, "target_kind", "pathway")

      with {:ok, _target_node} <-
             upsert_graph_node(%{
               label: "GraphCorrectionTarget",
               id: "graph_correction_target:#{target_id}",
               properties: %{target_id: target_id, target_kind: target_kind}
             }),
           {:ok, _edge} <-
             relate_graph_nodes(%{
               from: %{label: "GraphCorrection", id: correction_id},
               to: %{label: "GraphCorrectionTarget", id: "graph_correction_target:#{target_id}"},
               relationship_type: "AFFECTS"
             }) do
        :ok
      else
        {:error, reason} ->
          Logger.warning("[Rhizome.Memory] Failed to persist graph correction target #{inspect(target)}: #{inspect(reason)}")
          :ok
      end
    end)
  end

  defp iso_timestamp do
    DateTime.utc_now() |> DateTime.truncate(:microsecond) |> DateTime.to_iso8601()
  end

  defp normalize_return_fields(fields) when is_list(fields) do
    Enum.reduce_while(fields, [], fn field, acc ->
      case normalize_property_key(field) do
        nil -> {:halt, :invalid}
        "node" -> {:cont, [:node | acc]}
        normalized -> {:cont, [normalized | acc]}
      end
    end)
    |> case do
      :invalid -> :invalid
      normalized -> normalized |> Enum.reverse() |> Enum.uniq()
    end
  end

  defp normalize_return_fields(_), do: :invalid

  defp normalize_limit(value) when is_integer(value) and value > 0, do: value
  defp normalize_limit(_), do: nil

  defp normalize_property_key(value) do
    value
    |> normalize_string()
    |> case do
      nil ->
        nil

      normalized ->
        normalized
        |> String.replace(~r/[^A-Za-z0-9_]/, "_")
        |> case do
          "" -> nil
          clean -> clean
        end
    end
  end

  defp normalize_property_value(value) when is_float(value), do: value
  defp normalize_property_value(value) when is_integer(value), do: value
  defp normalize_property_value(value) when is_boolean(value), do: value
  defp normalize_property_value(value) when is_atom(value), do: Atom.to_string(value)
  defp normalize_property_value(value) when is_binary(value), do: value
  defp normalize_property_value(value), do: to_string(value)

  defp normalize_string(nil), do: nil
  defp normalize_string(value) when is_binary(value), do: value
  defp normalize_string(value) when is_atom(value), do: Atom.to_string(value)
  defp normalize_string(value), do: to_string(value)

  defp normalize_relationship_type(value) do
    value
    |> normalize_string()
    |> String.upcase()
    |> String.replace(~r/[^A-Z0-9_]/, "_")
    |> case do
      "" -> nil
      normalized -> normalized
    end
  end

  defp normalize_numeric(value) when is_integer(value), do: value
  defp normalize_numeric(_value), do: -1
  defp normalize_float(value) when is_float(value), do: value
  defp normalize_float(value) when is_integer(value), do: value * 1.0
  defp normalize_float(_value), do: -1.0

  defp normalize_weight_map(map) when is_map(map) do
    Map.new(map, fn {key, value} -> {to_string(key), normalize_weight(value)} end)
  end

  defp normalize_weight_map(_), do: %{}

  defp normalize_weight(value) when is_float(value), do: value
  defp normalize_weight(value) when is_integer(value), do: value * 1.0
  defp normalize_weight(value) when is_binary(value) do
    case Float.parse(value) do
      {parsed, _} -> parsed
      :error -> -1.0
    end
  end

  defp normalize_weight(_), do: -1.0

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

  defp escape_cypher(value) when is_binary(value) do
    value
    |> String.replace("\\", "\\\\")
    |> String.replace("'", "\\'")
  end

  defp escape_cypher(value), do: value |> to_string() |> escape_cypher()

  defp with_topology(operation, fun) when is_atom(operation) and is_function(fun, 0) do
    _descriptor = MemoryTopology.operation_descriptor!(operation)
    fun.()
  end

  defp run_memgraph_query(query) when is_binary(query) do
    Rhizome.Native.memgraph_query(query)
  end
end
