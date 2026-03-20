defmodule Sensory.PerimeterTest do
  use ExUnit.Case, async: true

  test "sensory perimeter declares the explicit organs and surfaces" do
    contract = Sensory.perimeter_contract()

    assert Map.keys(contract) |> Enum.sort() == [:ears, :skin, :tabula_rasa]
    assert :continuous_byte_stream in Sensory.allowed_surfaces()
    assert :telemetry_event in Sensory.allowed_surfaces()
    assert :protocol_frame in Sensory.allowed_surfaces()
  end

  test "valid ingestion paths are accepted by policy" do
    assert {:ok, %{organ: :tabula_rasa, surface: :continuous_byte_stream, transport: :zeromq}} =
             Sensory.validate_ingestion(%{organ: :tabula_rasa, surface: :continuous_byte_stream, transport: :zeromq})

    assert {:ok, %{organ: :ears, surface: :telemetry_event, transport: :zeromq}} =
             Sensory.validate_ingestion(%{organ: "ears", surface: "telemetry_event", transport: "zeromq"})
  end

  test "unsupported organs, surfaces, and transports are rejected by policy" do
    assert {:error, {:unsupported_sensory_organ, :nose}} =
             Sensory.validate_ingestion(%{organ: :nose, surface: :telemetry_event, transport: :zeromq})

    assert {:error, {:unsupported_ingest_surface, :email_attachment}} =
             Sensory.validate_ingestion(%{organ: :ears, surface: :email_attachment, transport: :http})

    assert {:error, {:transport_not_allowed_for_surface, :tabula_rasa, :continuous_byte_stream, :http}} =
             Sensory.validate_ingestion(%{organ: :tabula_rasa, surface: :continuous_byte_stream, transport: :http})
  end

  test "stream supervisor refuses unsupported sensory subscriptions" do
    assert {:stop, {:unsupported_ingest_surface, :email_attachment}} =
             Sensory.StreamSupervisor.init(
               subscriptions: [%{organ: :ears, surface: :email_attachment, transport: :zeromq, topic: "bad"}]
             )
  end
end
