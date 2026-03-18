defmodule Rhizome.MemoryTopology do
  @moduledoc """
  Canonical topology contract for Rhizome memory operations.

  The contract makes the three memory layers explicit:

  - `:working_graph` for active graph state in Memgraph
  - `:temporal_archive` for durable bitemporal documents in XTDB
  - `:consolidation_flow` for archive and optimization transitions between them
  """

  @type layer :: :working_graph | :temporal_archive | :consolidation_flow
  @type descriptor :: %{
          required(:layer) => layer(),
          required(:store) => String.t(),
          required(:access) => :read | :write | :read_write,
          required(:purpose) => String.t()
        }

  @contract %{
    working_graph: %{
      layer: :working_graph,
      store: "memgraph",
      access: :read_write,
      purpose: "active graph state for live topology, prediction edges, and sensory relationships",
      operations: [
        :query_working_memory,
        :query_memgraph,
        :query_low_confidence_candidates,
        :upsert_graph_node,
        :relate_graph_nodes,
        :persist_pooled_pattern,
        :normalize_abstract_state
      ]
    },
    temporal_archive: %{
      layer: :temporal_archive,
      store: "xtdb",
      access: :read_write,
      purpose: "durable bitemporal documents for lineage state, outcomes, and prediction errors",
      operations: [
        :write_archive_document,
        :query_archive,
        :query_recent_execution_outcomes,
        :query_recent_execution_telemetry,
        :submit_xtdb,
        :submit_execution_outcome,
        :submit_execution_telemetry,
        :submit_prediction_error,
        :submit_baseline_curriculum,
        :submit_objective_projection,
        :submit_cross_workspace_coordination,
        :submit_sovereignty_event,
        :submit_epistemic_foraging_event,
        :submit_simulation_daemon_event,
        :submit_teacher_daemon_event,
        :submit_abstract_intent_event,
        :submit_operator_feedback_event,
        :submit_differentiation_event,
        :load_cell_state,
        :checkpoint_cell_state
      ]
    },
    consolidation_flow: %{
      layer: :consolidation_flow,
      store: "memgraph+xtdb",
      access: :read_write,
      purpose: "sleep-cycle bridge and optimization flow that archives active graph state and consolidates memory",
      operations: [:bridge_working_memory_to_archive, :bridge_to_xtdb, :optimize_graph, :memory_relief]
    }
  }

  @operation_descriptors @contract
                         |> Enum.flat_map(fn {_layer, descriptor} ->
                           Enum.map(descriptor.operations, fn operation ->
                             {operation, Map.take(descriptor, [:layer, :store, :access, :purpose])}
                           end)
                         end)
                         |> Map.new()

  @spec contract() :: %{required(layer()) => map()}
  def contract, do: @contract

  @spec descriptor(layer()) :: map() | nil
  def descriptor(layer) when is_atom(layer), do: @contract[layer]
  def descriptor(_layer), do: nil

  @spec operation_descriptor(atom()) :: descriptor() | nil
  def operation_descriptor(operation) when is_atom(operation), do: @operation_descriptors[operation]
  def operation_descriptor(_operation), do: nil

  @spec operation_descriptor!(atom()) :: descriptor()
  def operation_descriptor!(operation) when is_atom(operation) do
    case operation_descriptor(operation) do
      nil -> raise ArgumentError, "unknown Rhizome memory topology operation: #{inspect(operation)}"
      descriptor -> descriptor
    end
  end

  @spec topology_envelope(atom(), map()) :: {:ok, map()} | {:error, :unknown_operation}
  def topology_envelope(operation, payload \\ %{})

  def topology_envelope(operation, payload) when is_atom(operation) and is_map(payload) do
    case operation_descriptor(operation) do
      nil ->
        {:error, :unknown_operation}

      descriptor ->
        {:ok,
         %{
           "layer" => Atom.to_string(descriptor.layer),
           "store" => descriptor.store,
           "access" => Atom.to_string(descriptor.access),
           "operation" => Atom.to_string(operation),
           "purpose" => descriptor.purpose,
           "payload" => payload
         }}
    end
  end

  def topology_envelope(_operation, _payload), do: {:error, :unknown_operation}
end
