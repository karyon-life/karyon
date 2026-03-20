defmodule NervousSystem.PubSub do
  @moduledoc """
  Direct organism bus facade for operator-facing sensory, motor, and telemetry
  traffic.

  The local Phoenix.PubSub mesh is the first delivery surface. When requested,
  events may also be mirrored onto the endocrine NATS plane without exposing
  transport details to callers.
  """

  @local_bus NervousSystem.LocalBus

  @type channel :: :sensory_input | :motor_output | :telemetry | :nociception | binary()

  def transport_descriptor do
    %{
      local_bus: @local_bus,
      facade: __MODULE__,
      mirrored_transport: NervousSystem.Endocrine.transport_descriptor()
    }
  end

  def topic(channel) when channel in [:sensory_input, :motor_output, :telemetry, :nociception] do
    "nervous_system:#{channel}"
  end

  def topic(channel) when is_binary(channel), do: channel

  def subscribe(channel) do
    Phoenix.PubSub.subscribe(@local_bus, topic(channel))
  end

  def broadcast(channel, payload, opts \\ []) do
    resolved_topic = topic(channel)

    if membrane_allows?(channel) do
      case Phoenix.PubSub.broadcast(@local_bus, resolved_topic, {resolved_topic, payload}) do
        :ok ->
          maybe_mirror_to_endocrine(resolved_topic, payload, opts)
          :ok

        other ->
          other
      end
    else
      {:error, :membrane_closed}
    end
  end

  defp maybe_mirror_to_endocrine(topic, payload, opts) do
    if Keyword.get(opts, :mirror_to_endocrine, false) do
      with gnat when not is_nil(gnat) <- NervousSystem.Endocrine.get_gnat(),
           {:ok, encoded} <- Jason.encode(%{topic: topic, payload: payload}),
           :ok <- NervousSystem.Endocrine.publish_gradient(gnat, topic, encoded) do
        :ok
      else
        _ -> :ok
      end
    else
      :ok
    end
  end

  def membrane_state do
    cond do
      is_map(Application.get_env(:nervous_system, :membrane_state_override)) ->
        Application.get_env(:nervous_system, :membrane_state_override)

      not Code.ensure_loaded?(Core.MetabolicDaemon) ->
        %{consciousness_state: :awake, membrane_open: true, motor_output_open: true}

      pid = GenServer.whereis(Core.MetabolicDaemon) ->
        case GenServer.call(pid, :get_membrane_state, 200) do
          state when is_map(state) -> state
          _ -> %{consciousness_state: :awake, membrane_open: true, motor_output_open: true}
        end

      true ->
        %{consciousness_state: :awake, membrane_open: true, motor_output_open: true}
    end
  catch
    :exit, _ ->
      %{consciousness_state: :awake, membrane_open: true, motor_output_open: true}
  end

  defp membrane_allows?(:telemetry), do: true
  defp membrane_allows?(:nociception), do: true

  defp membrane_allows?(:sensory_input) do
    membrane_state().membrane_open
  end

  defp membrane_allows?(:motor_output) do
    membrane_state().motor_output_open
  end

  defp membrane_allows?(channel) when is_binary(channel), do: membrane_allows?(binary_channel(channel))
  defp membrane_allows?(_channel), do: true

  defp binary_channel("nervous_system:sensory_input"), do: :sensory_input
  defp binary_channel("nervous_system:motor_output"), do: :motor_output
  defp binary_channel("nervous_system:telemetry"), do: :telemetry
  defp binary_channel("nervous_system:nociception"), do: :nociception
  defp binary_channel(_other), do: :external
end
