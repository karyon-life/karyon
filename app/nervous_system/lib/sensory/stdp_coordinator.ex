defmodule Sensory.STDPCoordinator do
  @moduledoc """
  Correlates MotorDriver emissions with Sensory.Stream perceptions using
  true microsecond-precise Spike-Timing-Dependent Plasticity (STDP) and
  exponential decay. Uses an ETS table for non-blocking high-frequency track.
  """

  use GenServer
  require Logger

  @ets_table :stdp_motor_spikes
  @echo_window_ms 150
  @tau 50.0 # Time constant for exponential decay
  @amplitude_plus 1.0 # Maximum weight increase

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :name, __MODULE__))
  end

  @doc """
  Records a motor spike instantly via ETS to avoid GenServer mailbox bottlenecks.
  Called by the MotorDriver or StemCell when a motor intent is executed.
  """
  def record_motor_spike(motor_node_id) do
    timestamp_us = System.os_time(:microsecond)
    # Using public write_concurrency table, any process can insert
    :ets.insert(@ets_table, {:motor_spike, to_string(motor_node_id), timestamp_us})
    :ok
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    # Create the ETS table for high-speed tracking
    # Using [:set, :public, :write_concurrency] as requested
    :ets.new(@ets_table, [
      :set,
      :public,
      :named_table,
      write_concurrency: true,
      read_concurrency: true
    ])

    # Subscribe to Sensory Stream events to detect incoming compressions
    maybe_subscribe("sensory.stream")

    {:ok, %{}}
  end

  @impl true
  def handle_info({:msg, %{topic: topic, body: payload}}, state) do
    handle_info({:msg, topic, payload}, state)
  end

  def handle_info({:msg, topic, iodata}, state) when topic == "sensory.stream" do
    payload = IO.iodata_to_binary(iodata)
    
    case decode_sensory_activation(payload) do
      {:ok, sensory_node_id} ->
        process_sensory_event(sensory_node_id, System.os_time(:microsecond))
      
      _ ->
        :ok
    end

    {:noreply, state}
  end

  def handle_info(_msg, state) do
    {:noreply, state}
  end

  # Internal Logic

  defp process_sensory_event(sensory_node_id, t_sensory_us) do
    # Find recent motor spikes in ETS
    # In a high-throughput scenario, we match all and filter by recent times
    records = :ets.tab2list(@ets_table)
    
    Enum.each(records, fn {:motor_spike, motor_node_id, t_motor_us} ->
      weight_update = calculate_weight_update(t_motor_us, t_sensory_us)

      if weight_update > 0.0 do
        # Valid causal link detected! Update Memgraph topology
        apply_memgraph_topology_update(motor_node_id, sensory_node_id, weight_update)
      end
    end)
    
    # Prune old spikes from ETS
    prune_old_spikes(t_sensory_us)
  end

  @doc """
  Calculates the STDP exponential decay based on microsecond temporal gap.
  Because motor actions cause the sensory input in this context, 
  delta_t_ms will be strictly positive (t_sensory - t_motor > 0).
  """
  def calculate_weight_update(t_motor_us, t_sensory_us) do
    delta_t_ms = (t_sensory_us - t_motor_us) / 1000.0

    if delta_t_ms > 0 and delta_t_ms <= @echo_window_ms do
      # STDP Exponential Decay calculation
      @amplitude_plus * :math.exp(-delta_t_ms / @tau)
    else
      # Outside window or negative time (spurious)
      0.0 
    end
  end

  defp apply_memgraph_topology_update(motor_id, sensory_id, weight_update) do
    timestamp = System.system_time(:second)

    query = """
    MATCH (m:MotorNode {id: $motor_id})
    MATCH (s:SensoryNode {id: $sensory_id})
    MERGE (m)-[rel:PRODUCES]->(s)
    ON CREATE SET 
        rel.weight = $weight_update, 
        rel.created_at = $timestamp, 
        rel.last_updated = $timestamp
    ON MATCH SET 
        rel.weight = rel.weight + $weight_update, 
        rel.last_updated = $timestamp
    """

    params = %{
      "motor_id" => motor_id,
      "sensory_id" => sensory_id,
      "weight_update" => weight_update,
      "timestamp" => timestamp
    }

    # Asynchronously dispatch to Rhizome natively
    Task.start(fn ->
      case query_memgraph(query, params) do
        {:ok, _} -> 
          Logger.debug("[STDPCoordinator] Successfully updated topology: MotorNode:#{motor_id} -> SensoryNode:#{sensory_id} (w: #{weight_update})")
        {:error, reason} ->
          Logger.warning("[STDPCoordinator] Failed topology update: #{inspect(reason)}")
      end
    end)
  end
  
  defp query_memgraph(query, params) do
    # Assuming Rhizome.Native exposes memgraph_query/2 or we fallback to string interpolation if it doesn't.
    # We will try the typical Elixir Bolt driver invocation pattern if Rhizome isn't capturing params
    if Code.ensure_loaded?(Rhizome.Native) and function_exported?(Rhizome.Native, :memgraph_query, 2) do
      apply(Rhizome.Native, :memgraph_query, [query, params])
    else
      # Fallback to Rhizome.Native.memgraph_query/1 with safe interpolation if needed
      Rhizome.Native.memgraph_query(interpolate_params(query, params))
    end
  end
  
  defp interpolate_params(query, params) do
    Enum.reduce(params, query, fn {k, v}, acc ->
      val_str = if is_binary(v), do: "'#{String.replace(v, "'", "\\'")}'", else: to_string(v)
      String.replace(acc, "$#{k}", val_str)
    end)
  end

  defp decode_sensory_activation(payload) do
    # Temporary fallback to pull out simple token JSON since no proto definition was given
    try do
      case Jason.decode(payload) do
        {:ok, %{"node_id" => node_id}} -> {:ok, to_string(node_id)}
        {:ok, %{"token_id" => node_id}} -> {:ok, to_string(node_id)}
        _ -> {:error, :invalid_format}
      end
    rescue
      _ -> {:error, :decode_failed}
    end
  end

  defp maybe_subscribe(subject) do
    case GenServer.whereis(:endocrine_gnat) do
      nil -> 
        if Code.ensure_loaded?(NervousSystem.LocalBus) do
          Phoenix.PubSub.subscribe(NervousSystem.LocalBus, subject)
        end
        :ok
      pid -> 
        NervousSystem.Endocrine.subscribe(pid, subject)
    end
  end

  defp prune_old_spikes(current_us) do
    cutoff_us = current_us - (@echo_window_ms * 1000)
    
    # Use match_delete to prune everything older than the cutoff efficiently
    # The ETS table has the structure: {:motor_spike, motor_node_id, t_motor_us}
    # For a set, match_delete with a guard is performant
    :ets.select_delete(@ets_table, [
      {{:motor_spike, :_, :"$1"}, [{:<, :"$1", cutoff_us}], [true]}
    ])
  end
end
