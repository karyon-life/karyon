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
    group_topic = Map.get(dna_spec, "cell_type", :undifferentiated)
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

    state = %{
      dna_spec: dna_spec,
      synapses: synapses, 
      status: :active
    }

    {:ok, state}
  end

  @impl true
  def handle_call(:get_status, _from, state) do
    {:reply, state.status, state}
  end

  # Phase 2 constraint: Apoptosis enforcement happens by the caller sending forceful exits
  # or returning standard OTP errors if logic panics.
end
