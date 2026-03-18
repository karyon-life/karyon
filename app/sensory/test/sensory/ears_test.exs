defmodule Sensory.EarsTest do
  use ExUnit.Case, async: true

  defmodule MemoryStub do
    def upsert_graph_node(spec) do
      send(self(), {:upsert_graph_node, spec})
      {:ok, spec}
    end

    def relate_graph_nodes(spec) do
      send(self(), {:relate_graph_nodes, spec})
      {:ok, spec}
    end
  end

  test "normalizes telemetry events into typed sensory records" do
    assert {:ok, event} =
             Sensory.normalize_event(%{
               surface: :telemetry_event,
               transport: :zeromq,
               source: :runtime_probe,
               payload: %{
                 event_name: [:logger, :error],
                 severity: :error,
                 module: Core.StemCell,
                 measurements: %{count: 1},
                 metadata: %{trace_id: "trace-1"}
               }
             })

    assert event.organ == :ears
    assert event.surface == :telemetry_event
    assert event.payload.event_kind == "telemetry_event"
    assert event.payload.severity == "error"
  end

  test "normalizes log and webhook payloads into typed sensory records" do
    assert {:ok, log_event} =
             Sensory.normalize_event(%{
               surface: :log_line,
               transport: :zeromq,
               source: "logs",
               payload: "[error] disk pressure spike"
             })

    assert log_event.payload.severity == "error"

    assert {:ok, webhook_event} =
             Sensory.normalize_event(%{
               surface: :webhook_payload,
               transport: :http,
               source: "webhooks",
               payload: %{"method" => "POST", "path" => "/hooks/build", "status" => "accepted", "body" => %{"id" => 42}}
             })

    assert webhook_event.payload.event_kind == "webhook_payload"
    assert webhook_event.payload.path == "/hooks/build"
  end

  test "ingests events through typed rhizome projection" do
    assert {:ok, event} =
             Sensory.ingest_event(
               %{
                 surface: :telemetry_event,
                 transport: :zeromq,
                 source: "telemetry",
                 payload: %{"event_name" => "metabolism.poll", "severity" => "warning", "module" => "Core.MetabolicDaemon"}
               },
               memory_module: MemoryStub
             )

    assert event.surface == :telemetry_event
    assert_received {:upsert_graph_node, %{label: "SensoryEvent"}}
    assert_received {:upsert_graph_node, %{label: "SensoryPayload"}}
    assert_received {:relate_graph_nodes, %{relationship_type: "EMITS_TYPED_PAYLOAD"}}
  end

  test "rejects unsupported ear transports and malformed payloads" do
    assert {:error, {:transport_not_allowed_for_surface, :ears, :webhook_payload, :zeromq}} =
             Sensory.normalize_event(%{
               surface: :webhook_payload,
               transport: :zeromq,
               source: "bad",
               payload: %{}
             })

    assert {:error, :invalid_ear_payload} =
             Sensory.normalize_event(%{
               surface: :telemetry_event,
               transport: :zeromq,
               source: "telemetry",
               payload: "not-a-map"
             })
  end
end
