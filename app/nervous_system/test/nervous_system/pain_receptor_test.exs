defmodule NervousSystem.PainReceptorTest do
  use ExUnit.Case, async: false
  require Logger

  setup do
    # Revert to TCP because chumak does NOT support inproc, but use a random port
    port = Enum.random(40000..60000)
    address = "tcp://127.0.0.1:#{port}"
    
    # Explicitly start the Nervous System application and wait for its supervisor
    Application.ensure_all_started(:nervous_system)
    
    # Wait for the supervisor to be registered and ready
    case wait_for_ready(NervousSystem.Supervisor, 100) do
      :ok -> :ok
      _ -> Logger.error("[PainReceptorTest] Supervisor failed to start!")
    end

    # 1. Stop the global supervised instance if it exists to avoid port/name collisions
    if Process.whereis(NervousSystem.Supervisor) do
      try do
        Supervisor.terminate_child(NervousSystem.Supervisor, NervousSystem.PainReceptor)
      rescue
        _ -> :ok
      end
    end
    
    # Also stop any manually started ones or zombies from previous failed runs
    stop_if_alive(Karyon.NervousSystem.PainReceptor)
    stop_if_alive(NervousSystem.PainReceptor)
    stop_if_alive(:pain_synapse)
    
    # Give the OS a moment to reclaim ports
    Process.sleep(100)

    # 2. Start the PainReceptor for the test with EXPLICIT address
    {:ok, pid} = NervousSystem.PainReceptor.start_link(%{address: address})
    
    on_exit(fn -> 
      if Process.alive?(pid), do: GenServer.stop(pid)
      stop_if_alive(:pain_synapse)
    end)
    
    {:ok, pid: pid, address: address}
  end

  defp wait_for_ready(name, attempts \\ 20) do
    if Process.whereis(name) do
      :ok
    else
      if attempts > 0 do
        Process.sleep(100)
        wait_for_ready(name, attempts - 1)
      else
        {:error, :timeout}
      end
    end
  end

  defp stop_if_alive(name) do
    case GenServer.whereis(name) do
      nil -> :ok
      pid ->
        try do
          Process.unlink(pid)
          GenServer.stop(pid)
        catch
          :exit, _ -> :ok
        end
    end
  end

  test "intercepts telemetry error and sends nociception signal", %{address: address} do
    # 1. Listen for Synapse signals
    
    # Start a SUB synapse to verify the PainReceptor's PUB broadcast
    {:ok, sub_pid} = NervousSystem.Synapse.start_link(
      type: :sub, 
      bind: address, 
      action: :connect,
      owner: self()
    )
    
    on_exit(fn -> if Process.alive?(sub_pid), do: GenServer.stop(sub_pid) end)

    # Subscribe to all messages (empty string topic)
    :ok = GenServer.call(sub_pid, {:subscribe, ""})

    # 2. Give ZMQ SUB time to connect to the PUB socket (slow joiner problem)
    # inproc is very fast but still needs a micro-sleep for handshake
    Process.sleep(200)

    # 3. Trigger a simulated "Pain" event via Telemetry
    # Check if PainReceptor is still alive before sending
    assert Process.whereis(NervousSystem.PainReceptor) != nil
    
    metadata = %{reason: "crash", module: __MODULE__}
    :telemetry.execute([:logger, :error], %{count: 1}, metadata)

    # 4. Assert signal arrival
    # PainReceptor might log warnings if Synapse is dead, but it should still try to send
    assert_receive {:synapse_recv, ^sub_pid, payload}, 10000
    
    assert {:ok, decoded} = Karyon.NervousSystem.PredictionError.decode(payload)
    assert decoded.type == "nociception"
    assert Map.get(decoded.metadata, "reason") == "crash"
    assert Map.get(decoded.metadata, "event_source") == "telemetry"
    assert Map.get(decoded.metadata, "event_fingerprint") == "Elixir.NervousSystem.PainReceptorTest:crash"
    assert is_binary(Map.get(decoded.metadata, "trace_id"))
  end

  test "filters recursive nervous-system pain sources", %{address: address} do
    {:ok, sub_pid} =
      NervousSystem.Synapse.start_link(
        type: :sub,
        bind: address,
        action: :connect,
        owner: self()
      )

    on_exit(fn -> if Process.alive?(sub_pid), do: GenServer.stop(sub_pid) end)

    :ok = GenServer.call(sub_pid, {:subscribe, ""})
    Process.sleep(200)

    metadata = %{reason: "loop", module: NervousSystem.Synapse}
    :telemetry.execute([:logger, :error], %{count: 1}, metadata)

    refute_receive {:synapse_recv, ^sub_pid, _payload}, 500
  end
end
