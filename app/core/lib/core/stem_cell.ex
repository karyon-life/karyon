defmodule Core.StemCell do
  @moduledoc """
  The behavioral template for Karyon cells (Actors).
  Implements the `gen_server` behavior, binding to `pg` (Process Groups)
  and initializing ZeroMQ (:chumak) Synaptic connections for deterministic execution.
  """
  use GenServer
  require Logger

  @doc """
  Spawns a new Stem Cell given a declarative DNA specification.
  """
  def start_link(dna_path) do
    GenServer.start_link(__MODULE__, dna_path)
  end

  def start(dna_path) do
    GenServer.start(__MODULE__, dna_path)
  end

  @impl true
  def init(dna_path) do
    Logger.info("Genesis: Stem Cell Booting from #{dna_path}")
    
    full_path = Path.expand(dna_path)
    dna_spec = Core.YamlParser.transcribe!(full_path)

    # Phase 1/2 Integration: Decentralized Process Discovery via Erlang :pg
    group_topic = 
      case Map.get(dna_spec, "cell_type", :undifferentiated) do
        topic when is_binary(topic) -> String.to_atom(topic)
        topic -> topic
      end
    :pg.join(group_topic, self())

    # Phase 2 Integration: Synaptic Zero-Buffer connections
    synapses = 
      case Map.get(dna_spec, "synapses", []) do
        [] -> []
        syn_configs when is_list(syn_configs) ->
          Enum.map(syn_configs, fn config ->
            start_synapse(config)
          end)
        syn_config when is_map(syn_config) ->
            [start_synapse(syn_config)]
      end

    # Phase 1: Self-subscribe to the Pain Receptor as an "Eye" for the organism
    nociception_address = Application.get_env(:nervous_system, :nociception_port, 5555)
    
    bind_uri = case nociception_address do
      addr when is_binary(addr) -> addr
      port when is_integer(port) -> "tcp://127.0.0.1:#{port}"
    end

    {:ok, nociception_syn_pid} = NervousSystem.Synapse.start_link(
      type: :sub, 
      bind: bind_uri, 
      action: :connect,
      hwm: 500
    )

    # Subscribe to metabolic spikes via NATS (Endocrine system)
    endocrine_topic = "metabolic.spike"
    
    # Phase 6: Bitemporal State Hydration (XTDB Recovery)
    # We use the dna_path as a stable identifier for this cell's "lineage"
    recovered_beliefs = hydrate_beliefs(dna_path)

    state = %{
      dna_spec: dna_spec,
      synapses: [nociception_syn_pid | synapses], 
      expectations: %{}, # Map of id -> %{goal: term, precision: float}
      beliefs: recovered_beliefs,      # Hydrated from XTDB
      status: :active,
      atp_metabolism: 1.0 # Current metabolic health (1.0 = optimal)
    }

    # Register for endocrine signals if NATS is up
    case GenServer.whereis(:endocrine_gnat) do
      nil -> :ok
      pid -> NervousSystem.Endocrine.subscribe(pid, endocrine_topic)
    end

    {:ok, state}
  end

  @impl true
  def handle_call({:execute, action, params}, _from, state) do
    allowed_actions = Map.get(state.dna_spec, "allowed_actions", [])
    if action in allowed_actions do
      Logger.info("[StemCell] Executing allowed action: #{action}")
      
      # Phase 1: Dynamic Dispatch based on DNA
      case dispatch_motor_action(state.dna_spec, action, params) do
        {:ok, result} -> {:reply, {:ok, result}, state}
        {:error, reason} -> {:reply, {:error, reason}, state}
        # Catch-all for dynamic dispatch safety
        other -> {:reply, {:ok, other}, state}
      end
    else
      Logger.error("[StemCell] ACTION DENIED: #{action} not in DNA allowed_actions.")
      {:reply, {:error, :unauthorized}, state}
    end
  end

  @impl true
  def handle_call({:form_expectation, id, goal, precision}, _from, state) do
    Logger.info("[StemCell] Forming expectation: #{inspect(goal)} with precision #{precision}")
    new_expectations = Map.put(state.expectations, id, %{goal: goal, precision: precision})
    {:reply, :ok, %{state | expectations: new_expectations}}
  end

  @impl true
  def handle_call(:get_status, _from, state) do
    {:reply, state.status, state}
  end

  @impl true
  def handle_call(:get_synapse_count, _from, state) do
    {:reply, length(state.synapses), state}
  end

  defp dispatch_motor_action(dna_spec, _action, params) do
    executor = Map.get(dna_spec, "motor_executor", "none")
    
    case executor do
      "firecracker_python" ->
        # Dispatch to Sandbox application
        Sandbox.Provisioner.capture_output(params[:vm_id] || "default_vm")
      "none" ->
        Logger.warning("[StemCell] No specialized motor_executor defined for this cell.")
        {:error, :motor_executor_not_configured}
      "error_test" ->
        {:error, :simulated_failure}
      other ->
        Logger.warning("[StemCell] Unknown motor_executor: #{other}.")
        {:error, {:unknown_motor_executor, other}}
    end
  end

  @impl true
  def handle_info({:msg, %{body: iodata, topic: topic}}, state) do
    handle_info({:msg, topic, iodata}, state)
  end

  def handle_info({:msg, _topic, iodata}, state) do
    payload = IO.iodata_to_binary(iodata)
    # Handle NATS Metabolic Spikes (Endocrine system)
    case Karyon.NervousSystem.MetabolicSpike.decode(payload) do
      {:ok, %Karyon.NervousSystem.MetabolicSpike{severity: "high"}} ->
        Logger.error("[StemCell] CRITICAL Metabolic Stress. Shedding synapses and entering Digital Torpor.")
        
        # Phase 5: Digital Torpor - Shed all non-essential synapses to reclaim cycles
        # We keep the pain receptor (index 0) but drop others
        essential = hd(state.synapses)
        others = tl(state.synapses)
        
        Enum.each(others, fn pid -> 
          if Process.alive?(pid), do: GenServer.stop(pid)
        end)

        {:noreply, %{state | atp_metabolism: 0.1, status: :torpor, synapses: [essential]}}

      {:ok, %Karyon.NervousSystem.MetabolicSpike{severity: "medium"}} ->
        # Speculative cells (no allowed actions) undergo apoptosis to save the colony
        if Enum.empty?(Map.get(state.dna_spec, "allowed_actions", [])) do
          Logger.warning("[StemCell] Medium Stress: Speculative Cell undergoing programmed apoptosis.")
          {:stop, :metabolic_pruning, state}
        else
          Logger.warning("[StemCell] Medium Metabolic Stress detected. Reducing activity.")
          {:noreply, %{state | atp_metabolism: 0.5}}
        end

      {:ok, %Karyon.NervousSystem.MetabolicSpike{severity: "low"}} ->
        {:noreply, %{state | atp_metabolism: 0.8}}

      {:error, reason} ->
        Logger.debug("[StemCell] Failed to decode metabolic spike: #{inspect(reason)}. Payload length: #{byte_size(payload)}")
        {:noreply, state}

      _ ->
        {:noreply, state}
    end
  end

  @impl true
  def handle_info({:synapse_recv, _pid, iodata}, state) do
    payload = IO.iodata_to_binary(iodata)
    case Karyon.NervousSystem.PredictionError.decode(payload) do
      {:ok, %Karyon.NervousSystem.PredictionError{type: "nociception", metadata: meta}} ->
        Logger.warning("[StemCell] Received Nociception Signal! Calculating Variational Free Energy.")
        
        # Calculate Variational Free Energy (F)
        vfe = calculate_variational_free_energy(state.expectations, meta)
        
        # Phase 2: Persist state to Rhizome for Memory Consolidation
        update_rhizome_state(state.dna_spec, vfe, state.atp_metabolism)

        utility_threshold = Map.get(state.dna_spec, "utility_threshold", 0.5)

        if vfe > utility_threshold do
          Logger.error("[StemCell] VFE #{vfe} exceeds threshold #{utility_threshold}. Triggering structural pruning.")
          # Pruning logic: remove failed branches in the Rhizome
          prune_rhizome_pathways(state.expectations)
        end
        
        {:noreply, %{state | expectations: %{}, beliefs: Map.put(state.beliefs, :last_vfe, vfe)}}
      _ ->
        {:noreply, state}
    end
  end

  @doc """
  Senses the "gradient" of available cells for a specific role/topic.
  Returns a random PID from the Process Group, mimicking stigmergy-based discovery.
  """
  def sense_gradient(role) do
    case :pg.get_members(role) do
      [] -> {:error, :no_gradient_detected}
      members -> {:ok, Enum.random(members)}
    end
  end

  defp calculate_variational_free_energy(expectations, _metadata) do
    # VFE = Sum of (precision * squared_prediction_error)
    # If we have expectations and receive a pain signal, error is high.
    Enum.reduce(expectations, 0.0, fn {_id, %{precision: p}}, acc ->
      acc + (p * 1.0) # Error is 1.0 on nociception
    end)
  end

  defp start_synapse(config) do
    type = String.to_atom(Map.get(config, "type", "push"))
    bind = Map.get(config, "bind", "tcp://127.0.0.1:0")

    case NervousSystem.Synapse.start_link(type: type, bind: bind) do
      {:ok, pid} -> pid
      {:error, reason} ->
        Logger.error("[StemCell] Failed to start synapse: #{inspect(reason)}. Continuing differentiation.")
        nil
    end
  end

  defp update_rhizome_state(dna_spec, vfe, atp) do
    id = Map.get(dna_spec, "id", "unknown_cell")
    query = "MERGE (c:Cell {id: '#{id}'}) SET c.vfe = #{vfe}, c.atp = #{atp}, c.last_update = #{System.system_time(:second)}"
    Rhizome.Native.memgraph_query(query)
  end

  defp hydrate_beliefs(dna_path) do
    query = %{
      "query" => %{
        "find" => ["(pull ?e [beliefs])"],
        "where" => [["?e", "xt/id", dna_path]]
      }
    }

    case Rhizome.Native.xtdb_query(query) do
      {:ok, [%{"beliefs" => beliefs} | _]} when is_map(beliefs) -> beliefs
      {:ok, [[%{"beliefs" => beliefs}] | _]} when is_map(beliefs) -> beliefs
      {:ok, [%{"data" => %{"beliefs" => beliefs}} | _]} when is_map(beliefs) -> beliefs
      _ -> %{}
    end
  end

  defp prune_rhizome_pathways(expectations) do
    # Phase 4 Integration: Communicate with Rhizome.Native to weaken graph edges
    Enum.each(expectations, fn {id, _} ->
      Logger.info("[StemCell] Requesting Rhizome pruning for: #{id}")
      
      # Convert ID to numeric if possible for pointer creation
      numeric_id = 
        case id do
          i when is_integer(i) -> i
          s when is_binary(s) -> 
            case Integer.parse(s) do
              {i, _} -> i
              _ -> 0 # Default placeholder
            end
          _ -> 0
        end

      resource = Rhizome.Native.create_pointer(numeric_id)
      Rhizome.Native.weaken_edge(resource)
    end)
  end
end
