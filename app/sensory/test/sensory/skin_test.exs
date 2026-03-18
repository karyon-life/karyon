defmodule Sensory.SkinTest do
  use ExUnit.Case, async: true

  defmodule MemoryStub do
    def persist_pooled_pattern(spec) do
      observer = Application.get_env(:sensory, :skin_pooler_observer)

      if is_pid(observer) do
        send(observer, {:skin_pattern_persisted, spec})
      end

      {:ok, %{pattern_id: "skin:#{spec.language}:#{Enum.join(spec.source_types, "->")}"}}
    end
  end

  setup do
    Application.put_env(:sensory, :skin_pooler_observer, self())

    on_exit(fn ->
      Application.delete_env(:sensory, :skin_pooler_observer)
    end)

    :ok
  end

  test "discovers repeated opaque text protocol structure" do
    payload = "HDR alpha beta HDR alpha beta TAIL"

    assert {:ok, result} =
             Sensory.discover_payload(payload,
               threshold: 2,
               memory_module: MemoryStub
             )

    assert result.surface == :protocol_frame
    assert result.encoding == "opaque_text"
    assert Enum.any?(result.pooled_patterns, fn pattern -> pattern.signature == "hdr->alpha" end)
    assert_receive {:skin_pattern_persisted, %{pool_type: "opaque_structure", language: "opaque_text"}}
  end

  test "discovers repeated opaque binary structure" do
    payload = <<16, 32, 16, 32, 255>>

    assert {:ok, result} =
             Sensory.discover_payload(payload,
               surface: :binary_payload,
               threshold: 2,
               memory_module: MemoryStub
             )

    assert result.surface == :binary_payload
    assert result.encoding == "opaque_binary"
    assert Enum.any?(result.pooled_patterns, fn pattern -> pattern.signature == "10->20" end)
  end

  test "rejects payloads without sufficient repeated structure" do
    assert {:ok, result} =
             Sensory.discover_payload("single token", threshold: 2, memory_module: MemoryStub)

    assert result.pooled_patterns == []
  end
end
