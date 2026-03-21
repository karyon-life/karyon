defmodule NervousSystem.ProtobufTest do
  use ExUnit.Case
  alias Karyon.NervousSystem.MetabolicSpike
  alias Karyon.NervousSystem.PredictionError

  test "MetabolicSpike encodes and decodes correctly" do
    msg = %MetabolicSpike{
      metric_type: "cpu",
      value: 0.85,
      threshold: 0.80,
      timestamp: System.system_time(:second),
      severity: 0.85,
      source: "metabolic_daemon"
    }

    assert {:ok, iodata} = MetabolicSpike.encode(msg)
    binary = IO.iodata_to_binary(iodata)
    assert {:ok, decoded} = MetabolicSpike.decode(binary)
    assert decoded.metric_type == "cpu"
    assert_in_delta decoded.severity, 0.85, 0.0001
    assert decoded.value == 0.85
    assert decoded.source == "metabolic_daemon"
  end

  test "PredictionError round-trips targeted STDP fields safely" do
    msg = %PredictionError{
      type: "nociception",
      metadata: %{"key" => "value"},
      source: "operator_induced",
      severity: 1.0,
      source_node: "node:source",
      predicted_target: "node:predicted",
      corrected_target: "node:corrected"
    }

    assert {:ok, iodata} = PredictionError.encode(msg)
    binary = IO.iodata_to_binary(iodata)
    assert {:ok, decoded} = PredictionError.decode(binary)
    assert decoded.type == "nociception"
    assert decoded.metadata["key"] == "value"
    assert decoded.source == "operator_induced"
    assert_in_delta decoded.severity, 1.0, 0.0001
    assert decoded.source_node == "node:source"
    assert decoded.predicted_target == "node:predicted"
    assert decoded.corrected_target == "node:corrected"
  end

  test "Protobuf rejects invalid binary data" do
    invalid_binary = <<0, 1, 2, 3, 4, 5>>
    assert {:error, _} = MetabolicSpike.decode(invalid_binary)
  end
end
