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
      severity: "high"
    }

    assert {:ok, iodata} = MetabolicSpike.encode(msg)
    binary = IO.iodata_to_binary(iodata)
    assert {:ok, decoded} = MetabolicSpike.decode(binary)
    assert decoded.metric_type == "cpu"
    assert decoded.severity == "high"
    assert decoded.value == 0.85
  end

  test "PredictionError handles optional metadata fields safely" do
    msg = %PredictionError{
      type: "nociception",
      metadata: %{"key" => "value"}
    }

    assert {:ok, iodata} = PredictionError.encode(msg)
    binary = IO.iodata_to_binary(iodata)
    assert {:ok, decoded} = PredictionError.decode(binary)
    assert decoded.type == "nociception"
    assert decoded.metadata["key"] == "value"
  end

  test "Protobuf rejects invalid binary data" do
    invalid_binary = <<0, 1, 2, 3, 4, 5>>
    assert {:error, _} = MetabolicSpike.decode(invalid_binary)
  end
end
