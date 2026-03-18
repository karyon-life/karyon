defmodule Sensory.SpatialPoolerTest do
  use ExUnit.Case, async: true

  defmodule MemoryStub do
    def persist_pooled_pattern(spec) do
      observer = Application.get_env(:sensory, :pooler_observer)

      if is_pid(observer) do
        send(observer, {:pooled_pattern_persisted, spec})
      end

      {:ok, %{pattern_id: "pool:#{spec.language}:#{Enum.join(spec.source_types, "->")}", occurrences: spec.occurrences}}
    end
  end

  setup do
    Application.put_env(:sensory, :pooler_observer, self())

    on_exit(fn ->
      Application.delete_env(:sensory, :pooler_observer)
    end)

    :ok
  end

  test "pool_code derives repeated co-occurrence abstractions from deterministic sensory graphs" do
    code = """
    let alpha = 1;
    let beta = 2;
    let gamma = 3;
    """

    assert {:ok, pooled} =
             Sensory.SpatialPooler.pool_code("javascript", code,
               threshold: 2,
               memory_module: MemoryStub
             )

    assert length(pooled.pooled_patterns) >= 1
    assert Enum.any?(pooled.pooled_patterns, fn pattern -> pattern.occurrences >= 2 end)
  end

  test "pool_graph persists pooled abstractions through the Rhizome boundary" do
    graph = %{
      "nodes" => [
        %{"id" => 1, "type" => "program"},
        %{"id" => 2, "type" => "lexical_declaration"},
        %{"id" => 3, "type" => "identifier"},
        %{"id" => 4, "type" => "lexical_declaration"},
        %{"id" => 5, "type" => "identifier"}
      ],
      "edges" => [
        %{"source" => 1, "target" => 2, "type" => "CHILD"},
        %{"source" => 2, "target" => 3, "type" => "CHILD"},
        %{"source" => 1, "target" => 4, "type" => "CHILD"},
        %{"source" => 4, "target" => 5, "type" => "CHILD"}
      ]
    }

    assert {:ok, pooled} =
             Sensory.SpatialPooler.pool_graph("javascript", graph,
               threshold: 2,
               memory_module: MemoryStub
             )

    assert_receive {:pooled_pattern_persisted, spec}
    assert spec.language == "javascript"
    assert spec.pool_type == "co_occurrence"
    assert Enum.any?(pooled.pooled_patterns, fn pattern -> pattern.occurrences == 2 end)
  end
end
