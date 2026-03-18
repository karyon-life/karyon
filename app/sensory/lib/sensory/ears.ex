defmodule Sensory.Ears do
  @moduledoc """
  Passive typed event ingestion for telemetry, logs, and webhooks.
  """

  alias Sensory.Perimeter

  def normalize_event(spec) when is_map(spec) do
    with {:ok, validated} <- validate_event_spec(spec),
         {:ok, payload} <- normalize_payload(validated.surface, Map.get(spec, :payload) || Map.get(spec, "payload")) do
      event_id = event_id(validated.surface, payload)

      {:ok,
       %{
         id: event_id,
         organ: :ears,
         surface: validated.surface,
         transport: validated.transport,
         source: normalize_source(Map.get(spec, :source) || Map.get(spec, "source")),
         observed_at: iso_now(),
         payload: payload
       }}
    end
  end

  def normalize_event(_spec), do: {:error, :invalid_ear_event}

  def ingest_event(spec, opts \\ []) do
    memory_module = Keyword.get(opts, :memory_module, Application.get_env(:sensory, :memory_module, Rhizome.Memory))

    with {:ok, event} <- normalize_event(spec),
         {:ok, _node} <-
           memory_module.upsert_graph_node(%{
             label: "SensoryEvent",
             id: event.id,
             properties: %{
               organ: Atom.to_string(event.organ),
               surface: Atom.to_string(event.surface),
               transport: Atom.to_string(event.transport),
               source: event.source,
               observed_at: event.observed_at,
               event_kind: Map.get(event.payload, :event_kind, Atom.to_string(event.surface))
             }
           }),
         {:ok, _payload_node} <-
           memory_module.upsert_graph_node(%{
             label: "SensoryPayload",
             id: "sensory_payload:" <> event.id,
             properties: payload_properties(event.payload)
           }),
         {:ok, _edge} <-
           memory_module.relate_graph_nodes(%{
             from: %{label: "SensoryEvent", id: event.id},
             to: %{label: "SensoryPayload", id: "sensory_payload:" <> event.id},
             relationship_type: "EMITS_TYPED_PAYLOAD"
           }) do
      {:ok, event}
    end
  end

  defp validate_event_spec(spec) do
    surface = Map.get(spec, :surface) || Map.get(spec, "surface")
    transport = Map.get(spec, :transport) || Map.get(spec, "transport")

    Perimeter.validate_ingestion(%{
      organ: :ears,
      surface: surface,
      transport: transport
    })
  end

  defp normalize_payload(:telemetry_event, payload) when is_map(payload) do
    {:ok,
     %{
       event_kind: "telemetry_event",
       event_name: normalize_text(Map.get(payload, :event_name) || Map.get(payload, "event_name") || "unknown"),
       severity: normalize_text(Map.get(payload, :severity) || Map.get(payload, "severity") || "info"),
       module: normalize_text(Map.get(payload, :module) || Map.get(payload, "module") || "unknown"),
       measurements: inspect(Map.get(payload, :measurements) || Map.get(payload, "measurements") || %{}),
       metadata: inspect(Map.get(payload, :metadata) || Map.get(payload, "metadata") || %{})
     }}
  end

  defp normalize_payload(:log_line, payload) when is_binary(payload) do
    {:ok,
     %{
       event_kind: "log_line",
       severity: infer_log_severity(payload),
       message: payload
     }}
  end

  defp normalize_payload(:webhook_payload, payload) when is_map(payload) do
    {:ok,
     %{
       event_kind: "webhook_payload",
       method: normalize_text(Map.get(payload, :method) || Map.get(payload, "method") || "post"),
       path: normalize_text(Map.get(payload, :path) || Map.get(payload, "path") || "/"),
       status: normalize_text(Map.get(payload, :status) || Map.get(payload, "status") || "received"),
       body: inspect(Map.get(payload, :body) || Map.get(payload, "body") || %{})
     }}
  end

  defp normalize_payload(:tensor_stream, payload) when is_binary(payload) do
    {:ok,
     %{
       event_kind: "tensor_stream",
       byte_size: byte_size(payload),
       sample: Base.encode16(binary_part(payload, 0, min(byte_size(payload), 8)))
     }}
  end

  defp normalize_payload(_surface, _payload), do: {:error, :invalid_ear_payload}

  defp payload_properties(payload) do
    Map.new(payload, fn {key, value} -> {key, normalize_text(value)} end)
  end

  defp normalize_source(nil), do: "unknown"
  defp normalize_source(value) when is_atom(value), do: Atom.to_string(value)
  defp normalize_source(value), do: to_string(value)

  defp normalize_text(value) when is_binary(value), do: value
  defp normalize_text(value) when is_atom(value), do: Atom.to_string(value)
  defp normalize_text(value) when is_list(value), do: inspect(value)
  defp normalize_text(value), do: to_string(value)

  defp infer_log_severity(message) do
    normalized = String.downcase(message)

    cond do
      String.contains?(normalized, "error") -> "error"
      String.contains?(normalized, "warn") -> "warning"
      true -> "info"
    end
  end

  defp event_id(surface, payload) do
    encoded =
      payload
      |> Enum.sort()
      |> :erlang.term_to_binary()
      |> Base.encode16(case: :lower)

    "sensory_event:" <> Atom.to_string(surface) <> ":" <> binary_part(encoded, 0, min(byte_size(encoded), 24))
  end

  defp iso_now do
    DateTime.utc_now() |> DateTime.truncate(:microsecond) |> DateTime.to_iso8601()
  end
end
