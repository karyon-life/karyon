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
    
    # Tail the log source in a separate task to avoid blocking init
    Task.start_link(fn -> pipe_loop(pipe_path, synapse, 0, "") end)
    
    {:ok, %{pipe: pipe_path, synapse: synapse, port: port}}
  end

  defp pipe_loop(pipe_path, synapse, offset, buffered) do
    case File.exists?(pipe_path) do
      true ->
        case File.read(pipe_path) do
          {:ok, contents} ->
            total_bytes = byte_size(contents)
            safe_offset = min(offset, total_bytes)
            delta = binary_part(contents, safe_offset, total_bytes - safe_offset)
            new_buffered = emit_lines(delta, synapse, buffered)

            Process.sleep(100)
            pipe_loop(pipe_path, synapse, total_bytes, new_buffered)

          {:error, reason} ->
            Logger.error("[Sandbox.Console] Error streaming pipe: #{inspect(reason)}")
            Process.sleep(1000)
            pipe_loop(pipe_path, synapse, offset, buffered)
        end

      false ->
        Process.sleep(100)
        pipe_loop(pipe_path, synapse, offset, buffered)
    end
  end

  defp emit_lines(delta, synapse, buffered) do
    combined = buffered <> delta

    case String.split(combined, "\n", trim: false) do
      [] ->
        combined

      segments ->
        {complete, remainder} = Enum.split(segments, -1)

        Enum.each(complete, fn line ->
          emit_line(line, synapse)
        end)

        List.first(remainder) || ""
    end
  end

  defp emit_line("", _synapse), do: :ok

  defp emit_line(line, synapse) do
    NervousSystem.Synapse.send_signal(synapse, "LOG:#{line}\n")

    if String.contains?(line, ["ERROR", "PANIC", "Exception", "Kernel panic"]) do
      Logger.error("[Sandbox.Console] Sandbox CRITICAL failure detected! Signaling PainReceptor.")

      NervousSystem.PainReceptor.trigger_nociception(%{
        origin: "firecracker",
        log_segment: String.trim(line),
        severity: :high
      })
    end
  end

  @impl true
  def handle_call(:get_port, _from, state) do
    {:reply, {:ok, state.port}, state}
  end
end
