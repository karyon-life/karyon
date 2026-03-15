defmodule Sandbox.Console do
  @moduledoc """
  Pipes the Firecracker serial console (named pipe) to a ZMQ Synapse.
  Provides high-fidelity audit and feedback logs for the microkernel.
  """
  use GenServer
  require Logger

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @impl true
  def init(opts) do
    pipe_path = Keyword.fetch!(opts, :pipe_path)
    vm_id = Keyword.fetch!(opts, :vm_id)
    
    # Start a Synapse to broadcast logs
    {:ok, synapse} = NervousSystem.Synapse.start_link(type: :push, bind: "tcp://127.0.0.1:0")
    {:ok, port} = GenServer.call(synapse, :get_port)
    
    Logger.info("[Sandbox.Console] Piping logs for #{vm_id} from #{pipe_path} to ZMQ port #{port}")
    
    # Open pipe in a separate task to avoid blocking init
    Task.start_link(fn -> pipe_loop(pipe_path, synapse) end)
    
    {:ok, %{pipe: pipe_path, synapse: synapse, port: port}}
  end

  defp pipe_loop(pipe_path, synapse) do
    # Wait for pipe to exist
    case File.exists?(pipe_path) do
      true ->
        try do
          File.stream!(pipe_path)
          |> Enum.each(fn line ->
            NervousSystem.Synapse.send_signal(synapse, "LOG:#{line}")
            
            # Detect high-severity errors for Active Inference feedback
            if String.contains?(line, ["ERROR", "PANIC", "Exception", "Kernel panic"]) do
              Logger.error("[Sandbox.Console] Sandbox CRITICAL failure detected! Signaling PainReceptor.")
              NervousSystem.PainReceptor.trigger_nociception(%{
                origin: "firecracker",
                log_segment: String.trim(line),
                severity: :high
              })
            end
          end)
        rescue
          e ->
            Logger.error("[Sandbox.Console] Error streaming pipe: #{inspect(e)}")
            Process.sleep(1000)
            pipe_loop(pipe_path, synapse)
        end
      false ->
        Process.sleep(100)
        pipe_loop(pipe_path, synapse)
    end
  end

  @impl true
  def handle_call(:get_port, _from, state) do
    {:reply, {:ok, state.port}, state}
  end
end
