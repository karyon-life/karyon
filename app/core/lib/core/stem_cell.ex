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
        syn_configs ->
          Enum.map(syn_configs, fn config ->
            type = String.to_atom(Map.get(config, "type", "push"))
            bind = Map.get(config, "bind", "tcp://127.0.0.1:0")
            {:ok, syn_pid} = NervousSystem.Synapse.start_link(type: type, bind: bind)
            syn_pid
          end)
      end

    # Phase 1: Self-subscribe to the Pain Receptor as an "Eye" for the organism
    {:ok, nociception_syn_pid} = NervousSystem.Synapse.start_link(type: :sub, bind: "tcp://127.0.0.1:5555", action: :connect)

    state = %{
      dna_spec: dna_spec,
      synapses: [nociception_syn_pid | synapses], 
      expectations: %{}, # Map of id -> expectation_data
      status: :active
    }

    {:ok, state}
  end

  @impl true
  def handle_call(:get_status, _from, state) do
    {:reply, state.status, state}
  end

  @impl true
  def handle_call({:form_expectation, id, goal}, _from, state) do
    Logger.info("[StemCell] Forming expectation: #{inspect(goal)}")
    new_expectations = Map.put(state.expectations, id, goal)
    {:reply, :ok, %{state | expectations: new_expectations}}
  end

  @impl true
  def handle_info({:synapse_recv, _pid, payload}, state) do
    case Jason.decode(payload) do
      {:ok, %{"type" => "nociception", "metadata" => meta}} ->
        Logger.warning("[StemCell] Received Nociception Signal! Calculating Prediction Error.")
        # Calculate Prediction Error: Contrast environment failure against our active expectations
        prediction_error = calculate_prediction_error(state.expectations, meta)
        
        if prediction_error > 0.5 do
          Logger.error("[StemCell] Critical Prediction Error: #{prediction_error}. Pruning expectations.")
          # Pruning logic would be here (Phase 4 integration with Rhizome)
        end
        
        {:noreply, %{state | expectations: %{}}}
      _ ->
        {:noreply, state}
    end
  end

  defp calculate_prediction_error(expectations, _metadata) do
    # Simple heuristic for MVP: if we have any active expectations and we receive pain, 
    # the error is 1.0.
    if map_size(expectations) > 0, do: 1.0, else: 0.0
  end
end
