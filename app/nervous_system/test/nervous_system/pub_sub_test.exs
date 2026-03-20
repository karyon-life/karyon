defmodule NervousSystem.PubSubTest do
  use ExUnit.Case, async: false

  setup do
    Application.delete_env(:nervous_system, :membrane_state_override)

    on_exit(fn ->
      Application.delete_env(:nervous_system, :membrane_state_override)
    end)

    :ok
  end

  test "broadcasts typed payloads over the organism bus facade" do
    assert :ok = NervousSystem.PubSub.subscribe(:motor_output)

    assert :ok =
             NervousSystem.PubSub.broadcast(:motor_output, %{
               stream: "motor_babble",
               content: "aa"
             })

    assert_received {"nervous_system:motor_output", %{stream: "motor_babble", content: "aa"}}
  end

  test "gates sensory input when the membrane is closed" do
    Application.put_env(:nervous_system, :membrane_state_override, %{
      consciousness_state: :torpor,
      membrane_open: false,
      motor_output_open: false
    })

    assert :ok = NervousSystem.PubSub.subscribe(:sensory_input)

    assert {:error, :membrane_closed} =
             NervousSystem.PubSub.broadcast(:sensory_input, %{stream: "blocked"})

    refute_received {"nervous_system:sensory_input", _}
  end

  test "exposes the endocrine-backed transport descriptor" do
    descriptor = NervousSystem.PubSub.transport_descriptor()

    assert descriptor.local_bus == NervousSystem.LocalBus
    assert descriptor.facade == NervousSystem.PubSub
    assert descriptor.mirrored_transport.transport == :nats
  end
end
