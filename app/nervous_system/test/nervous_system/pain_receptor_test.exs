defmodule NervousSystem.PainReceptorTest do
  @moduledoc """
  Verifies that biological failure states are correctly converted to prediction errors.
  Now uses PubSub instead of ZMQ synapses.
  """
  use ExUnit.Case, async: false
  require Logger
  alias NervousSystem.PainReceptor
  alias NervousSystem.PubSub

  setup do
    # Ensure the Nervous System application and its PubSub bus are started
    Application.ensure_all_started(:nervous_system)
    
    # Capture the PID of the supervised instance or start it if needed
    pid = case PainReceptor.start_link([]) do
      {:ok, p} -> p
      {:error, {:already_started, p}} -> p
    end
    
    # Note: Since it's a named GenServer, we don't strictly need to stop it on_exit
    # if we want to reuse the supervised one, but for isolation we could terminate it.
    
    {:ok, pid: pid}
  end

  test "intercepts telemetry and broadcasts prediction error via PubSub" do
    # 1. Subscribe to nociception topic via our PubSub facade
    # topic(:nociception) returns "nervous_system:nociception"
    PubSub.subscribe(:nociception)
    topic = PubSub.topic(:nociception)

    # 2. Trigger a simulated "Pain" event via Telemetry
    # Note: PainReceptor listens to specific telemetry events
    metadata = %{reason: "crash", module: Core.MockCell}
    # PainReceptor.init attaches to [:elixir, :proc_lib, :crash] among others
    :telemetry.execute([:elixir, :proc_lib, :crash], %{}, metadata)

    # 3. Assert signal arrival via PubSub
    assert_receive {^topic, {:prediction_error, error}}, 5000
    
    assert error.type == "nociception"
    assert error.source == "telemetry_interceptor"
    assert error.severity == 1.0
    assert error.metadata["reason"] == "\"crash\""
    assert is_binary(error.id)
    assert is_integer(error.timestamp)
  end

  test "filters recursive nervous-system pain sources" do
    PubSub.subscribe(:nociception)
    topic = PubSub.topic(:nociception)

    # Modules in NervousSystem should be ignored to avoid feedback loops
    # Note: they are prefixed with Elixir. in the check
    metadata = %{reason: "loop", module: NervousSystem.Synapse}
    :telemetry.execute([:elixir, :proc_lib, :crash], %{}, metadata)

    refute_receive {^topic, {:prediction_error, _}}, 500
  end

  test "manual trigger_nociception works" do
    PubSub.subscribe(:nociception)
    topic = PubSub.topic(:nociception)

    PainReceptor.trigger_nociception(%{reason: "manual_test"})

    assert_receive {^topic, {:prediction_error, error}}, 1000
    assert error.metadata["reason"] == "\"manual_test\""
  end
end
