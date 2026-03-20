defmodule Sensory.SkinTest do
  use ExUnit.Case, async: true

  defmodule MemoryStub do
    def persist_pooled_sequence(spec) do
      observer = Application.get_env(:sensory, :skin_pooler_observer)

      if is_pid(observer) do
        send(observer, {:skin_sequence_persisted, spec})
      end

      raw_bytes = Base.encode16(spec.sequence, case: :lower)
      {:ok, %{sequence_id: "skin:#{raw_bytes}", occurrences: spec.occurrences}}
    end
  end

  setup do
    Application.put_env(:sensory, :skin_pooler_observer, self())

    on_exit(fn ->
      Application.delete_env(:sensory, :skin_pooler_observer)
    end)

    :ok
  end

  test "discovers repeated opaque text byte windows" do
    payload = "hellohello"

    assert {:ok, result} =
             Sensory.discover_payload(payload,
               window: 5,
               threshold: 2,
               memory_module: MemoryStub
             )

    assert result.surface == :protocol_frame
    assert result.encoding == "utf8"
    assert Enum.any?(result.pooled_sequences, fn sequence -> sequence.signature == Base.encode16("hello", case: :lower) end)
    assert_receive {:skin_sequence_persisted, %{encoding: "utf8", activation_threshold: 2}}
  end

  test "discovers repeated opaque binary byte windows" do
    payload = <<16, 32, 16, 32, 16, 32>>

    assert {:ok, result} =
             Sensory.discover_payload(payload,
               surface: :binary_payload,
               window: 2,
               threshold: 2,
               memory_module: MemoryStub
             )

    assert result.surface == :binary_payload
    assert result.encoding == "binary"
    assert Enum.any?(result.pooled_sequences, fn sequence -> sequence.signature == "1020" end)
  end

  test "rejects payloads without sufficient repeated structure" do
    assert {:ok, result} =
             Sensory.discover_payload("single", window: 5, threshold: 2, memory_module: MemoryStub)

    assert result.pooled_sequences == []
  end
end
