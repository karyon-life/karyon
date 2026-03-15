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
    nociception_port = Application.get_env(:nervous_system, :nociception_port, 5555)
    {:ok, nociception_syn_pid} = NervousSystem.Synapse.start_link(type: :sub, bind: "tcp://127.0.0.1:#{nociception_port}", action: :connect)

    state = %{
      dna_spec: dna_spec,
      synapses: [nociception_syn_pid | synapses], 
      expectations: %{}, # Map of id -> %{goal: term, precision: float}
      beliefs: %{},      # Map of id -> float (0.0 to 1.0)
      status: :active
    }

    {:ok, state}
  end

  @impl true
  def handle_call(:get_status, _from, state) do
    {:reply, state.status, state}
  end

  @impl true
  def handle_call({:form_expectation, id, goal, precision}, _from, state) do
    Logger.info("[StemCell] Forming expectation: #{inspect(goal)} with precision #{precision}")
    new_expectations = Map.put(state.expectations, id, %{goal: goal, precision: precision})
    {:reply, :ok, %{state | expectations: new_expectations}}
  end

  @impl true
  def handle_info({:synapse_recv, _pid, payload}, state) do
    case Jason.decode(payload) do
      {:ok, %{"type" => "nociception", "metadata" => meta}} ->
        Logger.warning("[StemCell] Received Nociception Signal! Calculating Variational Free Energy.")
        
        # Calculate Variational Free Energy (F)
        # In this simplified model, F = sum(precision * (expectation - reality)^2)
        vfe = calculate_variational_free_energy(state.expectations, meta)
        
        if vfe > 0.5 do
          Logger.error("[StemCell] High Variational Free Energy: #{vfe}. Triggering structural pruning.")
          # Pruning logic: remove failed branches in the Rhizome
          prune_rhizome_pathways(state.expectations)
        end
        
        {:noreply, %{state | expectations: %{}, beliefs: Map.put(state.beliefs, :last_vfe, vfe)}}
      _ ->
        {:noreply, state}
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

  defp prune_rhizome_pathways(expectations) do
    # Phase 4 Integration: Communicate with Rhizome.Native to weaken graph edges
    Enum.each(expectations, fn {id, _} ->
      Logger.info("[StemCell] Requesting Rhizome pruning for: #{id}")
      Rhizome.Native.weaken_edge(to_string(id))
    end)
  end
end
