defmodule NervousSystem.PainReceptor do
  @moduledoc """
  The Pain Receptor intercepts application crash logs via Telemetry.
  It converts biological failure states (like process crashes) into high-priority prediction errors
  and routes them recursively back to the organism's internal PubSub bus.
  """
  use GenServer
  require Logger

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    # Subscribe to telemetry events (crashes and exceptions)
    :telemetry.attach_many(
      "karyon-pain-receptor",
      [
        [:elixir, :application, :stop],
        [:elixir, :proc_lib, :crash],
        [:phoenix, :live_view, :handle_event, :exception]
      ],
      &__MODULE__.handle_telemetry/4,
      nil
    )

    {:ok, %{error_counts: %{}, last_emitted: %{}}}
  end

  @doc """
  Manually triggers a nociception event. Useful for testing and external controllers.
  """
  def trigger_nociception(metadata \\ %{}) do
    fingerprint = fingerprint_error(metadata)
    emit_pain(fingerprint, metadata)
  end

  def handle_telemetry(_event, _measurements, metadata, _config) do
    if not recursive_pain?(metadata) do
      # Fingerprint the error to prevent broadcast storms
      fingerprint = fingerprint_error(metadata)

      if allowed_to_emit?(fingerprint) do
        emit_pain(fingerprint, metadata)
      end
    end
  end

  defp recursive_pain?(%{module: mod}) do
    mod_str = to_string(mod)
    String.starts_with?(mod_str, "Elixir.NervousSystem") or
      String.starts_with?(mod_str, "Elixir.Sensory")
  end
  defp recursive_pain?(_), do: false

  defp emit_pain(fingerprint, metadata) do
    prediction_error = build_prediction_error(fingerprint, metadata)
    
    # Broadcast via Phoenix PubSub (LocalBus) instead of ZMQ
    NervousSystem.PubSub.broadcast(:nociception, {:prediction_error, prediction_error})
    
    :telemetry.execute([:karyon, :nervous_system, :pain, :emitted], %{count: 1}, %{fingerprint: fingerprint})
  end

  defp build_prediction_error(fingerprint, metadata) do
    %{
      id: "pain:#{fingerprint}:#{System.system_time(:millisecond)}",
      type: "nociception",
      message: error_message(metadata),
      timestamp: System.system_time(:second),
      metadata: sanitize_metadata(metadata),
      cell_id: get_cell_id(metadata),
      source: "telemetry_interceptor",
      severity: calculate_severity(metadata)
    }
  end

  defp fingerprint_error(metadata) do
    case metadata do
      %{module: mod} -> "#{mod}"
      %{reason: reason} -> "#{inspect(reason)}"
      _ -> "unknown_fail"
    end
  end

  defp allowed_to_emit?(_fingerprint) do
    true
  end

  defp sanitize_metadata(metadata) do
    Map.new(metadata, fn {k, v} -> {to_string(k), inspect(v)} end)
  end

  defp error_message(%{reason: reason}), do: inspect(reason)
  defp error_message(_), do: "Unknown biological failure"

  defp get_cell_id(%{cell_id: id}), do: id
  defp get_cell_id(_), do: "platform"

  defp calculate_severity(_metadata), do: 1.0
end
