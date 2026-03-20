defmodule Sensory.SpatialPoolerTest do
  use ExUnit.Case, async: true

  defmodule MemoryStub do
    def persist_pooled_sequence(spec) do
      observer = Application.get_env(:sensory, :pooler_observer)

      if is_pid(observer) do
        send(observer, {:pooled_sequence_persisted, spec})
      end

      raw_bytes = Base.encode16(spec.sequence, case: :lower)
      {:ok, %{sequence_id: "pool:#{raw_bytes}", occurrences: spec.occurrences}}
    end
  end

  setup do
    Application.put_env(:sensory, :pooler_observer, self())

    on_exit(fn ->
      Application.delete_env(:sensory, :pooler_observer)
    end)

    :ok
  end

  test "pool_bytes derives repeated pooled sequences from a raw byte stream" do
    payload = "abcdeabcde"

    assert {:ok, pooled} =
             Sensory.SpatialPooler.pool_bytes(payload,
               window_size: 5,
               threshold: 2,
               memory_module: MemoryStub
             )

    assert pooled.window_size == 5
    assert length(pooled.pooled_sequences) >= 1
    assert Enum.any?(pooled.pooled_sequences, fn sequence -> sequence.signature == Base.encode16("abcde", case: :lower) end)
  end

  test "pool_bytes persists activated sequences through the Rhizome boundary" do
    assert {:ok, pooled} =
             Sensory.SpatialPooler.pool_bytes("hellohello",
               window_size: 5,
               threshold: 2,
               memory_module: MemoryStub
             )

    assert_receive {:pooled_sequence_persisted, spec}
    assert spec.encoding == "utf8"
    assert spec.window_size == 5
    assert Enum.any?(pooled.pooled_sequences, fn sequence -> sequence.occurrences == 2 end)
  end
end
