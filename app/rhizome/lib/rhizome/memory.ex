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
  Returns low-confidence graph candidates suitable for bounded epistemic foraging.
  """
  def query_low_confidence_candidates(spec \\ %{})

  def query_low_confidence_candidates(spec) when is_map(spec) do
    with_topology(:query_low_confidence_candidates, fn ->
      with {:ok, normalized} <- normalize_low_confidence_query(spec),
           {:ok, rows} <- run_memgraph_query(build_low_confidence_query(normalized)) do
        {:ok, Enum.map(rows, &normalize_low_confidence_row/1)}
      end
    end)
  end

  def query_low_confidence_candidates(_spec), do: {:error, :invalid_low_confidence_query}

  @doc """
  Returns grammar super-nodes and their pooled-sequence members for dream-state simulation.
  """
  def query_grammar_supernodes(spec \\ %{})

  def query_grammar_supernodes(spec) when is_map(spec) do
    with_topology(:query_grammar_supernodes, fn ->
      limit = normalize_limit(Map.get(spec, :limit) || Map.get(spec, "limit") || 8)

      if is_nil(limit) do
        {:error, :invalid_grammar_supernode_query}
      else
        run_memgraph_query(build_grammar_supernode_query(limit))
      end
    end)
  end

  def query_grammar_supernodes(_spec), do: {:error, :invalid_grammar_supernode_query}

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
  Persists a pooled byte-window abstraction as a typed PooledSequence node.
  """
  def persist_pooled_sequence(spec) when is_map(spec) do
    with_topology(:persist_pooled_sequence, fn ->
      with {:ok, normalized} <- normalize_pooled_sequence(spec),
           {:ok, _sequence} <-
             upsert_graph_node(%{
               label: "PooledSequence",
               id: normalized.id,
               properties: %{
                 signature: normalized.signature,
                 raw_bytes: normalized.raw_bytes,
                 encoding: normalized.encoding,
                 occurrences: normalized.occurrences,
                 activation_threshold: normalized.activation_threshold,
                 window_size: normalized.window_size,
                 observed_at: normalized.observed_at,
                 source: normalized.source,
                 organ: normalized.organ
               }
             }),
           {:ok, _source} <-
             upsert_graph_node(%{
               label: "SequenceWindow",
               id: normalized.window_id,
               properties: %{
                 encoding: normalized.encoding,
                 window_size: normalized.window_size
               }
             }),
           {:ok, _edge} <-
             relate_graph_nodes(%{
               from: %{label: "SequenceWindow", id: normalized.window_id},
               to: %{label: "PooledSequence", id: normalized.id},
               relationship_type: "EMERGES_AS",
               properties: %{
                 occurrences: normalized.occurrences,
                 activation_threshold: normalized.activation_threshold,
                 observed_at: normalized.observed_at
               }
             }) do
        {:ok, %{sequence_id: normalized.id, occurrences: normalized.occurrences}}
      end
    end)
  end

  def persist_pooled_sequence(_spec), do: {:error, :invalid_pooled_sequence}

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
  Returns recent execution outcomes suitable for simulation-daemon replay.
  """
  def query_recent_execution_outcomes(opts \\ %{})

  def query_recent_execution_outcomes(opts) when is_map(opts) do
    with_topology(:query_recent_execution_outcomes, fn ->
      limit = normalize_limit(Map.get(opts, :limit) || Map.get(opts, "limit") || 5)

      if is_nil(limit) do
        {:error, :invalid_recent_execution_outcomes_query}
      else
        query_archive(%{
          "query" => %{
            "find" => ["(pull ?e [xt/id cell_id action status vm_id plan_attractor_id plan_step_ids result recorded_at])"],
            "where" => [
              ["?e", "status", "success"]
            ]
          },
          "limit" => limit
        })
      end
    end)
  end

  def query_recent_execution_outcomes(_opts), do: {:error, :invalid_recent_execution_outcomes_query}

  @doc """
  Atomic upsert of a SensoryNode and its constituent edges.
  """
  def upsert_sensory_node(id, constituent_ids) when is_integer(id) or is_binary(id) do
    with_topology(:upsert_sensory_node, fn ->
      query = build_sensory_node_query(id, constituent_ids)
      Rhizome.Native.memgraph_query(query)
    end)
  end

  @doc """
  Atomic deletion of a SensoryNode and its orphaned edges.
  """
  def delete_sensory_node(id) when is_integer(id) or is_binary(id) do
    with_topology(:delete_sensory_node, fn ->
      query = build_delete_sensory_node_query(id)
      Rhizome.Native.memgraph_query(query)
    end)
  end

  @doc """
  Returns recent execution telemetry artifacts suitable for curriculum replay.
  """
  def query_recent_execution_telemetry(opts \\ %{})

  def query_recent_execution_telemetry(opts) when is_map(opts) do
    with_topology(:query_recent_execution_telemetry, fn ->
      limit = normalize_limit(Map.get(opts, :limit) || Map.get(opts, "limit") || 10)

      if is_nil(limit) do
        {:error, :invalid_recent_execution_telemetry_query}
      else
        query_archive(%{
          "query" => %{
            "find" => [
              "(pull ?e [xt/id source_document_id cell_id action status executor vm_id exit_code learning_phase learning_edge tags provenance result_summary result])"
            ],
            "where" => [["?e", "schema", "karyon.execution-telemetry.v1"]]
          },
          "limit" => limit
        })
      end
    end)
  end

  def query_recent_execution_telemetry(_opts), do: {:error, :invalid_recent_execution_telemetry_query}

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
  Persists a typed execution-telemetry curriculum artifact into XTDB and projects
  a replayable telemetry surface into Memgraph.
  """
  def submit_execution_telemetry(event) when is_map(event) do
    with_topology(:submit_execution_telemetry, fn ->
      document =
        event
        |> stringify_keys()
        |> Map.put_new("recorded_at", System.system_time(:second))

      with :ok <- validate_execution_telemetry(document),
           id when is_binary(id) <- execution_telemetry_id(document),
           {:ok, xtdb_result} <- submit_xtdb(id, document),
           :ok <- project_execution_telemetry(document) do
        {:ok, %{id: id, xtdb: xtdb_result}}
      else
        {:error, reason} -> {:error, reason}
        _ -> {:error, :invalid_execution_telemetry}
      end
    end)
  end

  def submit_execution_telemetry(_event), do: {:error, :invalid_execution_telemetry}

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
  Applies STDP structural plasticity in Memgraph and dual-writes a trauma event to XTDB.
  """
  def prune_stdp_pathway(event) when is_map(event) do
    with_topology(:prune_stdp_pathway, fn ->
      document =
        event
        |> stringify_keys()
        |> Map.put_new("event_at", System.system_time(:second))
        |> Map.put_new("recorded_at", iso_timestamp())
        |> Map.put_new("observed_at", iso_timestamp())

      with :ok <- validate_stdp_pathway(document),
           {:ok, result} <- Rhizome.Native.prune_stdp_pathway(document),
           {:ok, _trauma} <- maybe_submit_trauma_event(document, result) do
        {:ok, result}
      else
        {:error, reason} -> {:error, reason}
        _ -> {:error, :invalid_stdp_pathway}
      end
    end)
  end

  def prune_stdp_pathway(_event), do: {:error, :invalid_stdp_pathway}

  @doc """
  Persists an immutable trauma event into XTDB.
  """
  def submit_trauma_event(event) when is_map(event) do
    with_topology(:submit_trauma_event, fn ->
      document =
        event
        |> stringify_keys()
        |> Map.put_new("recorded_at", iso_timestamp())
        |> Map.put_new("observed_at", iso_timestamp())

      with :ok <- validate_trauma_event(document),
           id when is_binary(id) <- trauma_event_id(document),
           {:ok, xtdb_result} <- submit_xtdb(id, document) do
        {:ok, %{id: id, xtdb: xtdb_result}}
      else
        {:error, reason} -> {:error, reason}
        _ -> {:error, :invalid_trauma_event}
      end
    end)
  end

  def submit_trauma_event(_event), do: {:error, :invalid_trauma_event}

  @doc """
  Persists a typed baseline-diet curriculum artifact into XTDB and projects its
  structural grammar substrate into Memgraph.
  """
  def submit_baseline_curriculum(event) when is_map(event) do
    with_topology(:submit_baseline_curriculum, fn ->
      document =
        event
        |> stringify_keys()
        |> Map.put_new("ingested_at", System.system_time(:second))

      with :ok <- validate_baseline_curriculum(document),
           id when is_binary(id) <- baseline_curriculum_id(document),
           {:ok, xtdb_result} <- submit_xtdb(id, document),
           :ok <- project_baseline_curriculum(document) do
        {:ok, %{id: id, xtdb: xtdb_result}}
      else
        {:error, reason} -> {:error, reason}
        _ -> {:error, :invalid_baseline_curriculum}
      end
    end)
  end

  def submit_baseline_curriculum(_event), do: {:error, :invalid_baseline_curriculum}

  @doc """
  Persists a workspace objective projection into XTDB and projects the selected
  attractor surface back into Memgraph.
  """
  def submit_objective_projection(event) when is_map(event) do
    with_topology(:submit_objective_projection, fn ->
      document =
        event
        |> stringify_keys()
        |> Map.put_new("recorded_at", System.system_time(:second))

      with :ok <- validate_objective_projection(document),
           id when is_binary(id) <- objective_projection_id(document),
           {:ok, xtdb_result} <- submit_xtdb(id, document),
           :ok <- project_objective_projection(document) do
        {:ok, %{id: id, xtdb: xtdb_result}}
      else
        {:error, reason} -> {:error, reason}
        _ -> {:error, :invalid_objective_projection}
      end
    end)
  end

  def submit_objective_projection(_event), do: {:error, :invalid_objective_projection}

  @doc """
  Persists a shared-memory cross-workspace coordination record into XTDB and
  projects workspace-limb relationships into Memgraph.
  """
  def submit_cross_workspace_coordination(event) when is_map(event) do
    with_topology(:submit_cross_workspace_coordination, fn ->
      document =
        event
        |> stringify_keys()
        |> Map.put_new("recorded_at", System.system_time(:second))

      with :ok <- validate_cross_workspace_coordination(document),
           id when is_binary(id) <- cross_workspace_coordination_id(document),
           {:ok, xtdb_result} <- submit_xtdb(id, document),
           :ok <- project_cross_workspace_coordination(document) do
        {:ok, %{id: id, xtdb: xtdb_result}}
      else
        {:error, reason} -> {:error, reason}
        _ -> {:error, :invalid_cross_workspace_coordination}
      end
    end)
  end

  def submit_cross_workspace_coordination(_event), do: {:error, :invalid_cross_workspace_coordination}

  @doc """
  Persists a sovereignty paradox, refusal, or negotiation event into XTDB and
  projects the decision surface into Memgraph.
  """
  def submit_sovereignty_event(event) when is_map(event) do
    with_topology(:submit_sovereignty_event, fn ->
      document =
        event
        |> stringify_keys()
        |> Map.put_new("recorded_at", System.system_time(:second))

      with :ok <- validate_sovereignty_event(document),
           id when is_binary(id) <- sovereignty_event_id(document),
           {:ok, xtdb_result} <- submit_xtdb(id, document),
           :ok <- project_sovereignty_event(document) do
        {:ok, %{id: id, xtdb: xtdb_result}}
      else
        {:error, reason} -> {:error, reason}
        _ -> {:error, :invalid_sovereignty_event}
      end
    end)
  end

  def submit_sovereignty_event(_event), do: {:error, :invalid_sovereignty_event}

  @doc """
  Persists a bounded epistemic-foraging event and projects the confidence update
  back into working memory.
  """
  def submit_epistemic_foraging_event(event) when is_map(event) do
    with_topology(:submit_epistemic_foraging_event, fn ->
      document =
        event
        |> stringify_keys()
        |> Map.put_new("recorded_at", System.system_time(:second))

      with :ok <- validate_epistemic_foraging_event(document),
           id when is_binary(id) <- epistemic_foraging_event_id(document),
           {:ok, xtdb_result} <- submit_xtdb(id, document),
           :ok <- project_epistemic_foraging_event(document) do
        {:ok, %{id: id, xtdb: xtdb_result}}
      else
        {:error, reason} -> {:error, reason}
        _ -> {:error, :invalid_epistemic_foraging_event}
      end
    end)
  end

  def submit_epistemic_foraging_event(_event), do: {:error, :invalid_epistemic_foraging_event}

  @doc """
  Persists a dream-state permutation result and projects it back into Rhizome.
  """
  def submit_simulation_daemon_event(event) when is_map(event) do
    with_topology(:submit_simulation_daemon_event, fn ->
      document =
        event
        |> stringify_keys()
        |> Map.put_new("recorded_at", System.system_time(:second))

      with :ok <- validate_simulation_daemon_event(document),
           id when is_binary(id) <- simulation_daemon_event_id(document),
           {:ok, xtdb_result} <- submit_xtdb(id, document),
           :ok <- project_simulation_daemon_event(document) do
        {:ok, %{id: id, xtdb: xtdb_result}}
      else
        {:error, reason} -> {:error, reason}
        _ -> {:error, :invalid_simulation_daemon_event}
      end
    end)
  end

  def submit_simulation_daemon_event(_event), do: {:error, :invalid_simulation_daemon_event}

  @doc """
  Persists a teacher-daemon exam result and projects the curriculum event into Rhizome.
  """
  def submit_teacher_daemon_event(event) when is_map(event) do
    with_topology(:submit_teacher_daemon_event, fn ->
      document =
        event
        |> stringify_keys()
        |> Map.put_new("recorded_at", System.system_time(:second))

      with :ok <- validate_teacher_daemon_event(document),
           id when is_binary(id) <- teacher_daemon_event_id(document),
           {:ok, xtdb_result} <- submit_xtdb(id, document),
           :ok <- project_teacher_daemon_event(document) do
        {:ok, %{id: id, xtdb: xtdb_result}}
      else
        {:error, reason} -> {:error, reason}
        _ -> {:error, :invalid_teacher_daemon_event}
      end
    end)
  end

  def submit_teacher_daemon_event(_event), do: {:error, :invalid_teacher_daemon_event}

  @doc """
  Persists an abstract-intent bundle and projects directives plus drift events into Rhizome.
  """
  def submit_abstract_intent_event(event) when is_map(event) do
    with_topology(:submit_abstract_intent_event, fn ->
      document =
        event
        |> stringify_keys()
        |> Map.put_new("recorded_at", System.system_time(:second))

      with :ok <- validate_abstract_intent_event(document),
           id when is_binary(id) <- abstract_intent_event_id(document),
           {:ok, xtdb_result} <- submit_xtdb(id, document),
           :ok <- project_abstract_intent_event(document) do
        {:ok, %{id: id, xtdb: xtdb_result}}
      else
        {:error, reason} -> {:error, reason}
        _ -> {:error, :invalid_abstract_intent_event}
      end
    end)
  end

  def submit_abstract_intent_event(_event), do: {:error, :invalid_abstract_intent_event}

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

  defp trauma_event_id(%{"id" => id}) when is_binary(id) and id != "", do: id

  defp trauma_event_id(document) do
    trace_id = Map.get(document, "trace_id", "stdp")
    timestamp = Map.get(document, "event_at", System.system_time(:second))
    "trauma_event:#{trace_id}:#{timestamp}"
  end

  defp execution_telemetry_id(%{"telemetry_id" => id}) when is_binary(id) and id != "", do: id

  defp execution_telemetry_id(document) do
    source_id = Map.get(document, "source_document_id", "unknown_source")
    "execution_telemetry:#{:erlang.phash2(source_id)}"
  end

  defp operator_feedback_event_id(%{"id" => id}) when is_binary(id) and id != "", do: id

  defp operator_feedback_event_id(document) do
    template_id = Map.get(document, "template_id", "unknown_template")
    feedback_kind = Map.get(document, "feedback_kind", "feedback")
    timestamp = Map.get(document, "recorded_at", System.system_time(:second))
    "operator_feedback:#{template_id}:#{feedback_kind}:#{timestamp}"
  end

  defp objective_projection_id(%{"id" => id}) when is_binary(id) and id != "", do: id
  defp objective_projection_id(document) do
    workspace_root = Map.get(document, "workspace_root", "unknown_workspace")
    "objective_projection:#{:erlang.phash2(workspace_root)}"
  end

  defp baseline_curriculum_id(%{"baseline_id" => id}) when is_binary(id) and id != "", do: id

  defp baseline_curriculum_id(document) do
    repository_id = Map.get(document, "repository_id", "unknown_repository")
    "baseline_curriculum:#{:erlang.phash2(repository_id)}"
  end

  defp sovereignty_event_id(%{"id" => id}) when is_binary(id) and id != "", do: id

  defp sovereignty_event_id(document) do
    intent_id = Map.get(document, "intent_id", "unknown_intent")
    "sovereignty_event:#{intent_id}"
  end

  defp cross_workspace_coordination_id(%{"id" => id}) when is_binary(id) and id != "", do: id

  defp cross_workspace_coordination_id(document) do
    roots = Map.get(document, "workspace_roots", [])
    "cross_workspace:#{:erlang.phash2(roots)}"
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

  defp validate_stdp_pathway(%{
         "sensory_id" => sensory_id,
         "motor_id" => motor_id,
         "severity" => severity,
         "trace_id" => trace_id
       })
       when is_binary(sensory_id) and sensory_id != "" and is_binary(motor_id) and motor_id != "" and
              is_binary(trace_id) and trace_id != "" do
    case normalize_float(severity) do
      value when is_float(value) and value >= 0.0 and value <= 1.0 -> :ok
      _ -> {:error, :invalid_stdp_pathway}
    end
  end

  defp validate_stdp_pathway(_document), do: {:error, :invalid_stdp_pathway}

  defp validate_trauma_event(%{
         "schema" => "karyon.trauma-event.v1",
         "sensory_id" => sensory_id,
         "motor_id" => motor_id,
         "severity" => severity,
         "plasticity_mode" => plasticity_mode,
         "edge_action" => edge_action,
         "trace_id" => trace_id,
         "recorded_at" => recorded_at,
         "observed_at" => observed_at
       })
       when is_binary(sensory_id) and sensory_id != "" and is_binary(motor_id) and motor_id != "" and
              is_binary(plasticity_mode) and plasticity_mode != "" and is_binary(edge_action) and edge_action != "" and
              is_binary(trace_id) and trace_id != "" and is_binary(recorded_at) and recorded_at != "" and
              is_binary(observed_at) and observed_at != "" do
    case normalize_float(severity) do
      value when is_float(value) and value >= 0.0 and value <= 1.0 -> :ok
      _ -> {:error, :invalid_trauma_event}
    end
  end

  defp validate_trauma_event(_document), do: {:error, :invalid_trauma_event}

  defp validate_objective_projection(%{
         "workspace_root" => workspace_root,
         "manifest_ids" => manifest_ids,
         "hard_mandates" => hard_mandates,
         "soft_values" => soft_values,
         "evolving_needs" => evolving_needs,
         "objective_priors" => objective_priors,
         "precedence" => precedence,
         "projected_attractors" => projected_attractors
       })
       when is_binary(workspace_root) and workspace_root != "" and is_list(manifest_ids) and is_map(hard_mandates) and
              is_map(soft_values) and is_map(evolving_needs) and is_map(objective_priors) and is_map(precedence) and
              is_list(projected_attractors) do
    :ok
  end

  defp validate_objective_projection(_document), do: {:error, :invalid_objective_projection}

  defp validate_baseline_curriculum(%{
         "baseline_id" => baseline_id,
         "repository_id" => repository_id,
         "root_path" => root_path,
         "file_count" => file_count,
         "language_count" => language_count,
         "languages" => languages,
         "total_nodes" => total_nodes,
         "total_edges" => total_edges,
         "sample_files" => sample_files,
         "acceptance" => %{"status" => acceptance_status, "criteria" => criteria}
       })
       when is_binary(baseline_id) and baseline_id != "" and is_binary(repository_id) and repository_id != "" and
              is_binary(root_path) and root_path != "" and is_integer(file_count) and file_count >= 0 and
              is_integer(language_count) and language_count >= 0 and is_list(languages) and
              is_integer(total_nodes) and total_nodes >= 0 and is_integer(total_edges) and total_edges >= 0 and
              is_list(sample_files) and is_binary(acceptance_status) and is_map(criteria) do
    :ok
  end

  defp validate_baseline_curriculum(_document), do: {:error, :invalid_baseline_curriculum}

  defp validate_execution_telemetry(%{
         "telemetry_id" => telemetry_id,
         "schema" => "karyon.execution-telemetry.v1",
         "source_document_id" => source_document_id,
         "cell_id" => cell_id,
         "action" => action,
         "status" => status,
         "executor" => executor,
         "vm_id" => vm_id,
         "exit_code" => exit_code,
         "learning_phase" => learning_phase,
         "learning_edge" => learning_edge,
         "tags" => tags,
         "provenance" => provenance,
         "result_summary" => result_summary
       })
       when is_binary(telemetry_id) and telemetry_id != "" and is_binary(source_document_id) and source_document_id != "" and
              is_binary(cell_id) and cell_id != "" and is_binary(action) and action != "" and is_binary(status) and
              status != "" and is_binary(executor) and executor != "" and is_binary(vm_id) and vm_id != "" and
              is_integer(exit_code) and is_binary(learning_phase) and learning_phase != "" and
              is_binary(learning_edge) and learning_edge != "" and is_list(tags) and is_map(provenance) and
              is_map(result_summary) do
    :ok
  end

  defp validate_execution_telemetry(_document), do: {:error, :invalid_execution_telemetry}

  defp validate_sovereignty_event(%{
         "intent_id" => intent_id,
         "decision" => decision,
         "event_kind" => event_kind,
         "action" => action,
         "lineage_id" => lineage_id,
         "metabolic_risk" => metabolic_risk,
         "paradoxes" => paradoxes
       })
       when is_binary(intent_id) and intent_id != "" and is_binary(decision) and decision != "" and
              is_binary(event_kind) and event_kind != "" and is_binary(action) and action != "" and
              is_binary(lineage_id) and lineage_id != "" and is_binary(metabolic_risk) and metabolic_risk != "" and
              is_list(paradoxes) do
    :ok
  end

  defp validate_sovereignty_event(_document), do: {:error, :invalid_sovereignty_event}

  defp validate_cross_workspace_coordination(%{
         "central_workspace" => central_workspace,
         "workspace_roots" => workspace_roots,
         "localized_plan_paths" => localized_plan_paths,
         "roles" => roles,
         "coordination_scopes" => coordination_scopes,
         "attractor_ids" => attractor_ids
       })
       when is_binary(central_workspace) and central_workspace != "" and is_list(workspace_roots) and
              is_list(localized_plan_paths) and is_list(roles) and is_list(coordination_scopes) and
              is_list(attractor_ids) do
    :ok
  end

  defp validate_cross_workspace_coordination(_document), do: {:error, :invalid_cross_workspace_coordination}

  defp epistemic_foraging_event_id(%{"id" => id}) when is_binary(id) and id != "", do: id

  defp epistemic_foraging_event_id(document) do
    candidate_id = Map.get(document, "candidate_id", "unknown_candidate")
    timestamp = Map.get(document, "recorded_at", System.system_time(:second))
    "epistemic_foraging:#{candidate_id}:#{timestamp}"
  end

  defp simulation_daemon_event_id(%{"id" => id}) when is_binary(id) and id != "", do: id

  defp simulation_daemon_event_id(document) do
    source_outcome_id = Map.get(document, "source_outcome_id", "unknown_outcome")
    timestamp = Map.get(document, "recorded_at", System.system_time(:second))
    "simulation_daemon:#{source_outcome_id}:#{timestamp}"
  end

  defp teacher_daemon_event_id(%{"teacher_event_id" => id}) when is_binary(id) and id != "", do: id

  defp teacher_daemon_event_id(document) do
    exam_id = Map.get(document, "exam_id", "unknown_exam")
    "teacher_event:#{exam_id}"
  end

  defp abstract_intent_event_id(%{"intent_bundle_id" => id}) when is_binary(id) and id != "", do: id

  defp abstract_intent_event_id(document) do
    recorded_at = Map.get(document, "recorded_at", System.system_time(:second))
    "abstract_intent:#{recorded_at}"
  end

  defp validate_epistemic_foraging_event(%{
         "candidate_id" => candidate_id,
         "candidate_label" => candidate_label,
         "source_confidence" => source_confidence,
         "updated_confidence" => updated_confidence,
         "confidence_delta" => confidence_delta,
         "outcome_status" => outcome_status
       })
       when is_binary(candidate_id) and candidate_id != "" and is_binary(candidate_label) and candidate_label != "" and
              is_binary(outcome_status) and outcome_status != "" do
    if Enum.all?([source_confidence, updated_confidence, confidence_delta], &is_number/1) do
      :ok
    else
      {:error, :invalid_epistemic_foraging_event}
    end
  end

  defp validate_epistemic_foraging_event(_document), do: {:error, :invalid_epistemic_foraging_event}

  defp validate_simulation_daemon_event(%{
         "permutation_id" => permutation_id,
         "intent_id" => intent_id,
         "outcome_status" => outcome_status,
         "dream_mode" => dream_mode,
         "predicted_free_energy" => predicted_free_energy,
         "external_motor_output_used" => external_motor_output_used
       })
       when is_binary(permutation_id) and permutation_id != "" and is_binary(intent_id) and intent_id != "" and
              is_binary(outcome_status) and outcome_status != "" and is_binary(dream_mode) and dream_mode != "" and
              is_boolean(external_motor_output_used) do
    if is_number(predicted_free_energy) do
      :ok
    else
      {:error, :invalid_simulation_daemon_event}
    end
  end

  defp validate_simulation_daemon_event(_document), do: {:error, :invalid_simulation_daemon_event}

  defp validate_teacher_daemon_event(%{
         "teacher_event_id" => teacher_event_id,
         "exam_id" => exam_id,
         "schema" => "karyon.teacher-daemon.v1",
         "source_path" => source_path,
         "source_kind" => source_kind,
         "headline" => headline,
         "prompt" => prompt,
         "confidence_threshold" => confidence_threshold,
         "curriculum_scope" => curriculum_scope,
         "intent_id" => intent_id,
         "outcome_status" => outcome_status,
         "vm_id" => vm_id,
         "performance_trace" => performance_trace
       })
       when is_binary(teacher_event_id) and teacher_event_id != "" and is_binary(exam_id) and exam_id != "" and
              is_binary(source_path) and source_path != "" and is_binary(source_kind) and source_kind != "" and
              is_binary(headline) and headline != "" and is_binary(prompt) and prompt != "" and
              is_number(confidence_threshold) and is_binary(curriculum_scope) and curriculum_scope != "" and
              is_binary(intent_id) and intent_id != "" and is_binary(outcome_status) and outcome_status != "" and
              is_binary(vm_id) and vm_id != "" and is_map(performance_trace) do
    :ok
  end

  defp validate_teacher_daemon_event(_document), do: {:error, :invalid_teacher_daemon_event}

  defp validate_abstract_intent_event(%{
         "intent_bundle_id" => intent_bundle_id,
         "schema" => "karyon.abstract-intent.v1",
         "source_documents" => source_documents,
         "directives" => directives,
         "git_history" => git_history,
         "observed_signals" => observed_signals,
         "drift_events" => drift_events
       })
       when is_binary(intent_bundle_id) and intent_bundle_id != "" and is_list(source_documents) and is_list(directives) and
              is_list(git_history) and is_map(observed_signals) and is_list(drift_events) do
    :ok
  end

  defp validate_abstract_intent_event(_document), do: {:error, :invalid_abstract_intent_event}

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

  defp maybe_submit_trauma_event(_document, %{plasticity_mode: :noop}), do: {:ok, %{id: :noop}}

  defp maybe_submit_trauma_event(document, result) do
    submit_trauma_event(%{
      "schema" => "karyon.trauma-event.v1",
      "sensory_id" => Map.get(document, "sensory_id"),
      "motor_id" => Map.get(document, "motor_id"),
      "severity" => normalize_float(Map.get(document, "severity")),
      "plasticity_mode" => Atom.to_string(Map.get(result, :plasticity_mode, :unknown)),
      "edge_action" => trauma_edge_action(Map.get(result, :plasticity_mode, :unknown)),
      "trace_id" => Map.get(document, "trace_id", "stdp"),
      "event_at" => Map.get(document, "event_at", System.system_time(:second)),
      "recorded_at" => Map.get(document, "recorded_at", iso_timestamp()),
      "observed_at" => Map.get(document, "observed_at", iso_timestamp())
    })
  end

  defp trauma_edge_action(:depressed), do: "weight_degraded"
  defp trauma_edge_action(:deleted), do: "edge_deleted"
  defp trauma_edge_action(_), do: "noop"

  defp project_execution_telemetry(document) do
    telemetry_id = execution_telemetry_id(document)
    source_document_id = Map.get(document, "source_document_id", "unknown_source")
    cell_id = Map.get(document, "cell_id", "unknown_cell")

    with {:ok, _cell} <- upsert_graph_node(%{label: "Cell", id: cell_id}),
         {:ok, _telemetry} <-
           upsert_graph_node(%{
             label: "ExecutionTelemetry",
             id: telemetry_id,
             properties: %{
               action: Map.get(document, "action", "unknown_action"),
               status: Map.get(document, "status", "unknown"),
               executor: Map.get(document, "executor", "unknown"),
               vm_id: Map.get(document, "vm_id", "unknown"),
               learning_phase: Map.get(document, "learning_phase", "action_feedback"),
               tag_count: length(List.wrap(Map.get(document, "tags", []))),
               recorded_at: Map.get(document, "recorded_at", System.system_time(:second))
             }
           }),
         {:ok, _source} <-
           upsert_graph_node(%{
             label: "ExecutionOutcome",
             id: source_document_id,
             properties: %{status: Map.get(document, "status", "unknown")}
           }),
         {:ok, _edge} <-
           relate_graph_nodes(%{
             from: %{label: "ExecutionTelemetry", id: telemetry_id},
             to: %{label: "ExecutionOutcome", id: source_document_id},
             relationship_type: "DERIVED_FROM"
           }),
         {:ok, _cell_edge} <-
           relate_graph_nodes(%{
             from: %{label: "Cell", id: cell_id},
             to: %{label: "ExecutionTelemetry", id: telemetry_id},
             relationship_type: "EMITTED_TELEMETRY"
           }) do
      :ok
    else
      {:error, reason} ->
        Logger.warning("[Rhizome.Memory] Memgraph projection of execution telemetry failed: #{inspect(reason)}")
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

  defp project_objective_projection(document) do
    projection_id = objective_projection_id(document)
    workspace_root = Map.get(document, "workspace_root", "unknown_workspace")
    workspace_id = "workspace:#{:erlang.phash2(workspace_root)}"
    manifest_ids = Map.get(document, "manifest_ids", [])

    with {:ok, _workspace} <-
           upsert_graph_node(%{
             label: "Workspace",
             id: workspace_id,
             properties: %{root: workspace_root, manifest_count: length(manifest_ids)}
           }),
         {:ok, _projection} <-
           upsert_graph_node(%{
             label: "ObjectiveProjection",
             id: projection_id,
             properties: %{
               workspace_root: workspace_root,
               manifest_ids: Enum.join(manifest_ids, ","),
               recorded_at: Map.get(document, "recorded_at", System.system_time(:second))
             }
           }),
         {:ok, _edge} <-
           relate_graph_nodes(%{
             from: %{label: "Workspace", id: workspace_id},
             to: %{label: "ObjectiveProjection", id: projection_id},
             relationship_type: "PROJECTS_OBJECTIVES"
           }) do
      project_objective_attractors(projection_id, Map.get(document, "projected_attractors", []))
      :ok
    else
      {:error, reason} ->
        Logger.warning("[Rhizome.Memory] Memgraph projection of objective projection failed: #{inspect(reason)}")
        :ok
    end
  end

  defp project_baseline_curriculum(document) do
    baseline_id = baseline_curriculum_id(document)
    repository_id = Map.get(document, "repository_id", "unknown_repository")
    acceptance = Map.get(document, "acceptance", %{})

    with {:ok, _repository} <-
           upsert_graph_node(%{
             label: "Repository",
             id: repository_id,
             properties: %{
               root_path: Map.get(document, "root_path", ""),
               file_count: normalize_numeric(document["file_count"])
             }
           }),
         {:ok, _baseline} <-
           upsert_graph_node(%{
             label: "BaselineCurriculum",
             id: baseline_id,
             properties: %{
               language_count: normalize_numeric(document["language_count"]),
               total_nodes: normalize_numeric(document["total_nodes"]),
               total_edges: normalize_numeric(document["total_edges"]),
               acceptance_status: Map.get(acceptance, "status", "unknown"),
               recorded_at: Map.get(document, "ingested_at", System.system_time(:second))
             }
           }),
         {:ok, _edge} <-
           relate_graph_nodes(%{
             from: %{label: "Repository", id: repository_id},
             to: %{label: "BaselineCurriculum", id: baseline_id},
             relationship_type: "ESTABLISHES_BASELINE"
           }) do
      project_baseline_languages(baseline_id, Map.get(document, "languages", []))
      :ok
    else
      {:error, reason} ->
        Logger.warning("[Rhizome.Memory] Memgraph projection of baseline curriculum failed: #{inspect(reason)}")
        :ok
    end
  end

  defp project_sovereignty_event(document) do
    event_id = sovereignty_event_id(document)
    intent_id = Map.get(document, "intent_id", "unknown_intent")
    paradoxes = List.wrap(Map.get(document, "paradoxes", []))

    with {:ok, _event} <-
           upsert_graph_node(%{
             label: "SovereigntyEvent",
             id: event_id,
             properties: %{
               decision: Map.get(document, "decision", "unknown"),
               event_kind: Map.get(document, "event_kind", "unknown"),
               action: Map.get(document, "action", "unknown"),
               metabolic_risk: Map.get(document, "metabolic_risk", "unknown"),
               paradoxes: Enum.join(paradoxes, ","),
               recorded_at: Map.get(document, "recorded_at", System.system_time(:second))
             }
           }),
         {:ok, _intent} <-
           upsert_graph_node(%{
             label: "ExecutionIntentSurface",
             id: intent_id,
             properties: %{action: Map.get(document, "action", "unknown")}
           }),
         {:ok, _edge} <-
           relate_graph_nodes(%{
             from: %{label: "SovereigntyEvent", id: event_id},
             to: %{label: "ExecutionIntentSurface", id: intent_id},
             relationship_type: "ASSESSES_INTENT"
           }) do
      :ok
    else
      {:error, reason} ->
        Logger.warning("[Rhizome.Memory] Memgraph projection of sovereignty event failed: #{inspect(reason)}")
        :ok
    end
  end

  defp project_cross_workspace_coordination(document) do
    coordination_id = cross_workspace_coordination_id(document)
    central_workspace = Map.get(document, "central_workspace", "unknown_workspace")
    workspace_roots = List.wrap(Map.get(document, "workspace_roots", []))
    roles = List.wrap(Map.get(document, "roles", []))

    with {:ok, _coordination} <-
           upsert_graph_node(%{
             label: "CrossWorkspaceCoordination",
             id: coordination_id,
             properties: %{
               central_workspace: central_workspace,
               workspace_count: length(workspace_roots),
               recorded_at: Map.get(document, "recorded_at", System.system_time(:second))
             }
           }) do
      Enum.zip(workspace_roots, roles)
      |> Enum.each(fn {workspace_root, role} ->
        workspace_id = "workspace:#{:erlang.phash2(workspace_root)}"

        with {:ok, _workspace} <-
               upsert_graph_node(%{
                 label: "Workspace",
                 id: workspace_id,
                 properties: %{root: workspace_root, role: role}
               }),
             {:ok, _edge} <-
               relate_graph_nodes(%{
                 from: %{label: "CrossWorkspaceCoordination", id: coordination_id},
                 to: %{label: "Workspace", id: workspace_id},
                 relationship_type: "COORDINATES_LIMB",
                 properties: %{role: role}
               }) do
          :ok
        else
          {:error, reason} ->
            Logger.warning("[Rhizome.Memory] Memgraph projection of cross-workspace limb failed: #{inspect(reason)}")
            :ok
        end
      end)

      :ok
    else
      {:error, reason} ->
        Logger.warning("[Rhizome.Memory] Memgraph projection of cross-workspace coordination failed: #{inspect(reason)}")
        :ok
    end
  end

  defp project_epistemic_foraging_event(document) do
    event_id = epistemic_foraging_event_id(document)
    candidate_label = Map.get(document, "candidate_label", "SuperNode")
    candidate_id = Map.get(document, "candidate_id", "unknown_candidate")

    with {:ok, _candidate} <-
           upsert_graph_node(%{
             label: candidate_label,
             id: candidate_id,
             properties: %{
               confidence: normalize_float(document["updated_confidence"]),
               last_foraged_at: Map.get(document, "recorded_at", System.system_time(:second)),
               last_foraging_status: Map.get(document, "outcome_status", "unknown")
             }
           }),
         {:ok, _event} <-
           upsert_graph_node(%{
             label: "EpistemicForagingEvent",
             id: event_id,
             properties: %{
               mode: Map.get(document, "mode", "idle_probe"),
               source_confidence: normalize_float(document["source_confidence"]),
               updated_confidence: normalize_float(document["updated_confidence"]),
               confidence_delta: normalize_float(document["confidence_delta"]),
               outcome_status: Map.get(document, "outcome_status", "unknown"),
               intent_id: Map.get(document, "intent_id", "unknown_intent"),
               recorded_at: Map.get(document, "recorded_at", System.system_time(:second))
             }
           }),
         {:ok, _edge} <-
           relate_graph_nodes(%{
             from: %{label: "EpistemicForagingEvent", id: event_id},
             to: %{label: candidate_label, id: candidate_id},
             relationship_type: "PROBED",
             properties: %{
               confidence_delta: normalize_float(document["confidence_delta"]),
               outcome_status: Map.get(document, "outcome_status", "unknown")
             }
           }) do
      :ok
    else
      {:error, reason} ->
        Logger.warning("[Rhizome.Memory] Memgraph projection of epistemic foraging event failed: #{inspect(reason)}")
        :ok
    end
  end

  defp project_simulation_daemon_event(document) do
    event_id = simulation_daemon_event_id(document)
    grammar_supernode_ids = List.wrap(Map.get(document, "grammar_supernode_ids", []))

    with {:ok, _event} <-
           upsert_graph_node(%{
             label: "SimulationDaemonEvent",
             id: event_id,
             properties: %{
               permutation_id: Map.get(document, "permutation_id", "unknown_permutation"),
               dream_mode: Map.get(document, "dream_mode", "grammar_monte_carlo"),
               outcome_status: Map.get(document, "outcome_status", "unknown"),
               predicted_free_energy: normalize_float(Map.get(document, "predicted_free_energy", 0.0)),
               external_motor_output_used: Map.get(document, "external_motor_output_used", false),
               recorded_at: Map.get(document, "recorded_at", System.system_time(:second))
             }
           }) do
      Enum.each(grammar_supernode_ids, fn grammar_id ->
        with {:ok, _grammar} <-
               upsert_graph_node(%{
                 label: "GrammarSuperNode",
                 id: grammar_id,
                 properties: %{kind: "structural_grammar_rule", source: "operator_environment"}
               }),
             {:ok, _edge} <-
               relate_graph_nodes(%{
                 from: %{label: "SimulationDaemonEvent", id: event_id},
                 to: %{label: "GrammarSuperNode", id: grammar_id},
                 relationship_type: "DREAMED_FROM",
                 properties: %{
                   dream_mode: Map.get(document, "dream_mode", "grammar_monte_carlo"),
                   outcome_status: Map.get(document, "outcome_status", "unknown")
                 }
               }) do
          :ok
        else
          _ -> :ok
        end
      end)

      :ok
    else
      {:error, reason} ->
        Logger.warning("[Rhizome.Memory] Memgraph projection of simulation-daemon event failed: #{inspect(reason)}")
      :ok
    end
  end

  defp project_teacher_daemon_event(document) do
    event_id = teacher_daemon_event_id(document)
    exam_id = Map.get(document, "exam_id", "unknown_exam")

    with {:ok, _exam} <-
           upsert_graph_node(%{
             label: "SyntheticOracleExam",
             id: exam_id,
             properties: %{
               source_path: Map.get(document, "source_path", ""),
               source_kind: Map.get(document, "source_kind", "unknown"),
               curriculum_scope: Map.get(document, "curriculum_scope", "curriculum_source"),
               confidence_threshold: normalize_float(document["confidence_threshold"])
             }
           }),
         {:ok, _event} <-
           upsert_graph_node(%{
             label: "TeacherDaemonEvent",
             id: event_id,
             properties: %{
               headline: Map.get(document, "headline", "unknown"),
               outcome_status: Map.get(document, "outcome_status", "unknown"),
               vm_id: Map.get(document, "vm_id", "unknown"),
               recorded_at: Map.get(document, "recorded_at", System.system_time(:second))
             }
           }),
         {:ok, _edge} <-
           relate_graph_nodes(%{
             from: %{label: "TeacherDaemonEvent", id: event_id},
             to: %{label: "SyntheticOracleExam", id: exam_id},
             relationship_type: "ADMINISTERS_EXAM"
           }) do
      :ok
    else
      {:error, reason} ->
        Logger.warning("[Rhizome.Memory] Memgraph projection of teacher daemon event failed: #{inspect(reason)}")
        :ok
    end
  end

  defp project_abstract_intent_event(document) do
    bundle_id = abstract_intent_event_id(document)
    drift_events = List.wrap(Map.get(document, "drift_events", []))

    with {:ok, _bundle} <-
           upsert_graph_node(%{
             label: "AbstractIntentBundle",
             id: bundle_id,
             properties: %{
               document_count: length(List.wrap(Map.get(document, "source_documents", []))),
               directive_count: length(List.wrap(Map.get(document, "directives", []))),
               git_history_count: length(List.wrap(Map.get(document, "git_history", []))),
               drift_count: length(drift_events),
               recorded_at: Map.get(document, "recorded_at", System.system_time(:second))
             }
           }) do
      project_intent_directives(bundle_id, List.wrap(Map.get(document, "directives", [])))
      project_implementation_drift(bundle_id, drift_events)
      :ok
    else
      {:error, reason} ->
        Logger.warning("[Rhizome.Memory] Memgraph projection of abstract intent failed: #{inspect(reason)}")
        :ok
    end
  end

  defp project_objective_attractors(projection_id, projected_attractors) do
    Enum.each(projected_attractors, fn attractor ->
      attractor_id = Map.get(attractor, "id", "unknown_attractor")
      attractor_kind = Map.get(attractor, "kind", "SuperNode")

      with {:ok, _attractor} <-
             upsert_graph_node(%{
               label: "ObjectiveAttractor",
               id: attractor_id,
               properties: %{
                 kind: attractor_kind,
                 objective_priors: Jason.encode!(Map.get(attractor, "objective_priors", %{})),
                 needs: Jason.encode!(Map.get(attractor, "needs", %{})),
                 values: Jason.encode!(Map.get(attractor, "values", %{}))
               }
             }),
           {:ok, _edge} <-
             relate_graph_nodes(%{
               from: %{label: "ObjectiveProjection", id: projection_id},
               to: %{label: "ObjectiveAttractor", id: attractor_id},
               relationship_type: "PROJECTS_ATTRACTOR"
             }) do
        :ok
      else
        {:error, reason} ->
          Logger.warning("[Rhizome.Memory] Memgraph projection of objective attractor failed: #{inspect(reason)}")
          :ok
      end
    end)
  end

  defp project_baseline_languages(baseline_id, languages) do
    Enum.each(languages, fn language ->
      language_id = "grammar_language:#{language}"

      with {:ok, _language} <-
             upsert_graph_node(%{
               label: "GrammarLanguage",
               id: language_id,
               properties: %{name: language}
             }),
           {:ok, _edge} <-
             relate_graph_nodes(%{
               from: %{label: "BaselineCurriculum", id: baseline_id},
               to: %{label: "GrammarLanguage", id: language_id},
               relationship_type: "CURATES_LANGUAGE"
             }) do
        :ok
      else
        {:error, reason} ->
          Logger.warning("[Rhizome.Memory] Memgraph projection of baseline language failed: #{inspect(reason)}")
          :ok
      end
    end)
  end

  defp project_intent_directives(bundle_id, directives) do
    Enum.each(directives, fn directive ->
      directive_id = Map.get(directive, "directive_id", "unknown_directive")

      with {:ok, _directive} <-
             upsert_graph_node(%{
               label: "IntentDirective",
               id: directive_id,
               properties: %{
                 statement: Map.get(directive, "statement", ""),
                 constraint_kind: Map.get(directive, "constraint_kind", "architecture"),
                 expected_signal: Map.get(directive, "expected_signal", "unknown")
               }
             }),
           {:ok, _edge} <-
             relate_graph_nodes(%{
               from: %{label: "AbstractIntentBundle", id: bundle_id},
               to: %{label: "IntentDirective", id: directive_id},
               relationship_type: "DECLARES_INTENT"
             }) do
        :ok
      else
        {:error, reason} ->
          Logger.warning("[Rhizome.Memory] Memgraph projection of intent directive failed: #{inspect(reason)}")
          :ok
      end
    end)
  end

  defp project_implementation_drift(bundle_id, drift_events) do
    Enum.each(drift_events, fn drift ->
      drift_id = Map.get(drift, "drift_id", "unknown_drift")

      with {:ok, _drift} <-
             upsert_graph_node(%{
               label: "ImplementationDrift",
               id: drift_id,
               properties: %{
                 directive_id: Map.get(drift, "directive_id", "unknown_directive"),
                 expected_signal: Map.get(drift, "expected_signal", "unknown"),
                 drift_kind: Map.get(drift, "drift_kind", "design_implementation_documentation"),
                 severity: Map.get(drift, "severity", "medium")
               }
             }),
           {:ok, _edge} <-
             relate_graph_nodes(%{
               from: %{label: "AbstractIntentBundle", id: bundle_id},
               to: %{label: "ImplementationDrift", id: drift_id},
               relationship_type: "DETECTS_DRIFT"
             }) do
        :ok
      else
        {:error, reason} ->
          Logger.warning("[Rhizome.Memory] Memgraph projection of implementation drift failed: #{inspect(reason)}")
          :ok
      end
    end)
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

  defp normalize_low_confidence_query(spec) do
    label = normalize_graph_label(Map.get(spec, :label) || Map.get(spec, "label") || "SuperNode")
    threshold = normalize_float(Map.get(spec, :threshold) || Map.get(spec, "threshold") || 0.5)
    limit = normalize_limit(Map.get(spec, :limit) || Map.get(spec, "limit") || 5)

    if is_nil(label) or is_nil(limit) do
      {:error, :invalid_low_confidence_query}
    else
      {:ok, %{label: label, threshold: threshold, limit: limit}}
    end
  end

  defp normalize_low_confidence_row(row) when is_map(row) do
    %{
      "id" => Map.get(row, "id", "unknown_candidate"),
      "label" => Map.get(row, "label", "SuperNode"),
      "summary" => Map.get(row, "summary", ""),
      "confidence" => normalize_float(Map.get(row, "confidence", 0.0)),
      "type" => Map.get(row, "type", "unknown")
    }
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

  defp normalize_pooled_sequence(spec) do
    sequence = Map.get(spec, :sequence) || Map.get(spec, "sequence")
    raw_bytes = normalize_raw_bytes(sequence || Map.get(spec, :raw_bytes) || Map.get(spec, "raw_bytes"))
    encoding = normalize_graph_id(Map.get(spec, :encoding) || Map.get(spec, "encoding") || "binary")
    occurrences = normalize_occurrences(Map.get(spec, :occurrences) || Map.get(spec, "occurrences"))
    activation_threshold = normalize_occurrences(Map.get(spec, :activation_threshold) || Map.get(spec, "activation_threshold"))
    window_size = normalize_occurrences(Map.get(spec, :window_size) || Map.get(spec, "window_size"))
    observed_at = normalize_numeric(Map.get(spec, :observed_at) || Map.get(spec, "observed_at") || System.system_time(:second))
    source = normalize_graph_id(Map.get(spec, :source) || Map.get(spec, "source") || "unknown")
    organ = normalize_graph_id(Map.get(spec, :organ) || Map.get(spec, "organ") || "unknown")

    case {raw_bytes, encoding, occurrences, activation_threshold, window_size, observed_at, source, organ} do
      {nil, _, _, _, _, _, _, _} ->
        {:error, :invalid_pooled_sequence}

      {_, nil, _, _, _, _, _, _} ->
        {:error, :invalid_pooled_sequence}

      {_, _, nil, _, _, _, _, _} ->
        {:error, :invalid_pooled_sequence}

      {_, _, _, nil, _, _, _, _} ->
        {:error, :invalid_pooled_sequence}

      {_, _, _, _, nil, _, _, _} ->
        {:error, :invalid_pooled_sequence}

      {_, _, _, _, _, nil, _, _} ->
        {:error, :invalid_pooled_sequence}

      {_, _, _, _, _, _, nil, _} ->
        {:error, :invalid_pooled_sequence}

      {_, _, _, _, _, _, _, nil} ->
        {:error, :invalid_pooled_sequence}

      {raw_bytes, encoding, occurrences, activation_threshold, window_size, observed_at, source, organ} ->
        signature = String.downcase(raw_bytes)

        {:ok,
         %{
           id: normalize_graph_id(Map.get(spec, :id) || Map.get(spec, "id") || "pooled_sequence:#{signature}"),
           signature: signature,
           raw_bytes: raw_bytes,
           encoding: encoding,
           occurrences: occurrences,
           activation_threshold: activation_threshold,
           window_size: window_size,
           observed_at: observed_at,
           source: source,
           organ: organ,
           window_id: "sequence_window:#{encoding}:#{window_size}"
         }}
    end
  end

  defp build_grammar_supernode_query(limit) do
    """
    MATCH (g:GrammarSuperNode)-[:ABSTRACTS]->(p:PooledSequence)
    WHERE g.source = 'operator_environment'
    RETURN
      g.id AS id,
      g.kind AS kind,
      coalesce(g.confidence, 0.0) AS confidence,
      collect(p.id) AS pooled_sequence_ids
    ORDER BY coalesce(g.confidence, 0.0) DESC, g.id ASC
    LIMIT #{limit}
    """
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

  defp build_low_confidence_query(%{label: label, threshold: threshold, limit: limit}) do
    """
    MATCH (n:#{label})
    WHERE coalesce(n.confidence, 0.0) <= #{property_literal(threshold)}
    RETURN
      n.id AS id,
      '#{escape_cypher(label)}' AS label,
      coalesce(n.summary, '') AS summary,
      coalesce(n.confidence, 0.0) AS confidence,
      coalesce(n.type, '#{escape_cypher(label)}') AS type
    ORDER BY coalesce(n.confidence, 0.0) ASC, coalesce(n.id, '') ASC
    LIMIT #{limit}
    """
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

  defp build_sensory_node_query(id, constituent_ids) do
    escaped_id = property_literal(id)
    unwind_list = "[#{Enum.map_join(constituent_ids, ", ", &property_literal/1)}]"

    """
    MERGE (n:SensoryNode {id: #{escaped_id}})
    WITH n
    UNWIND #{unwind_list} AS c_id
    MATCH (c:SensoryNode {id: c_id})
    MERGE (n)-[:COMPOSED_OF]->(c)
    RETURN n.id AS id
    """
  end

  defp build_delete_sensory_node_query(id) do
    """
    MATCH (n:SensoryNode {id: #{property_literal(id)}})
    DETACH DELETE n
    RETURN #{property_literal(id)} AS id
    """
  end

  defp normalize_raw_bytes(value) when is_binary(value) do
    Base.encode16(value, case: :lower)
  end

  defp normalize_raw_bytes(value) when is_list(value) do
    try do
      value
      |> :erlang.list_to_binary()
      |> Base.encode16(case: :lower)
    rescue
      _ -> nil
    end
  end

  defp normalize_raw_bytes(value) when is_bitstring(value), do: Base.encode16(value, case: :lower)
  defp normalize_raw_bytes(nil), do: nil
  defp normalize_raw_bytes(_value), do: nil

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
