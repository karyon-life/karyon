defmodule Sensory.TabulaRasaIngestorTest do
  use ExUnit.Case, async: true

  alias Sensory.TabulaRasa.Ingestor

  defmodule MemoryStub do
    def persist_pooled_sequence(spec) do
      observer = Application.get_env(:sensory, :ingestor_observer)

      if is_pid(observer) do
        send(observer, {:pooled_sequence_persisted, spec})
      end

      raw_bytes = Base.encode16(spec.sequence, case: :lower)
      {:ok, %{sequence_id: "ingestor:#{raw_bytes}", occurrences: spec.occurrences}}
    end
  end

  setup do
    Application.put_env(:sensory, :ingestor_observer, self())

    on_exit(fn ->
      Application.delete_env(:sensory, :ingestor_observer)
    end)

    :ok
  end

  test "starts under the sensory supervision tree" do
    Application.ensure_all_started(:sensory)
    assert Process.whereis(Ingestor)
  end

  test "ingest_bytes forwards natively and returns empty activations" do
    name = :"ingestor_#{System.unique_integer([:positive])}"
    {:ok, pid} = Ingestor.start_link(name: name, memory_module: MemoryStub, window_size: 5, threshold: 2)

    assert {:ok, result1} = Ingestor.ingest_bytes("hello", server: pid)
    assert result1.pooled_sequences == []

    assert {:ok, result2} = Ingestor.ingest_bytes("hello", server: pid)
    assert result2.pooled_sequences == []
  end

  test "ingestor maintains a bounded ephemeral buffer" do
    name = :"bounded_ingestor_#{System.unique_integer([:positive])}"
    {:ok, pid} = Ingestor.start_link(name: name, memory_module: MemoryStub, max_buffer_size: 6, window_size: 3)

    assert {:ok, _} = Ingestor.ingest_bytes("abcdef", server: pid)
    assert {:ok, _} = Ingestor.ingest_bytes("ghij", server: pid)

    snapshot = Ingestor.snapshot(pid)
    assert snapshot.buffer == "efghij"
    assert snapshot.buffer_size == 6
  end
end
