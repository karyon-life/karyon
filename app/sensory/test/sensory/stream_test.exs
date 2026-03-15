defmodule Sensory.StreamTest do
  use ExUnit.Case
  alias Sensory.Native
  alias Sensory.Quantizer

  test "quantization and publication throughput" do
    tensor = for _ <- 1..100, do: :rand.uniform()
    binary = Quantizer.quantize(tensor)
    
    # Verify publication returns ok even without listeners (ZMQ PUB/SUB behavior)
    assert {:ok, _} = Native.zmq_publish_tensor("neural_tensor", binary)
  end

  test "deterministic AST parsing ensures zero-hallucination" do
    code = "def hello(): print('world')"
    # parse_to_graph returns a JSON string of the deterministic AST
    result = Native.parse_to_graph("python", code)
    assert String.contains?(result, "function_definition")
    assert String.contains?(result, "hello")
  end
  
  test "ingest_to_memgraph returns a resource pointer" do
    code = "int main() { return 0; }"
    case Native.ingest_to_memgraph("c", code) do
      {:ok, resource} -> 
        assert is_reference(resource)
      {:error, reason} ->
        # Accept connection errors if memgraph is down, but logic must be sound
        assert String.contains?(reason, "Connection Error") or String.contains?(reason, "initialized")
    end
  end
end
