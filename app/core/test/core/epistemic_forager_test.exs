defmodule Core.EpistemicForagerTest do
  use ExUnit.Case, async: true

  alias Core.EpistemicForager

  defmodule MemoryStub do
    def query_low_confidence_candidates(_query) do
      {:ok,
       [
         %{
           "id" => "community:uncertain",
           "label" => "SuperNode",
           "summary" => "uncertain cluster",
           "confidence" => 0.22,
           "type" => "COMMUNITY"
         }
       ]}
    end

    def submit_epistemic_foraging_event(event) do
      if pid = Process.whereis(:epistemic_forager_observer) do
        send(pid, {:foraging_event_persisted, event})
      end

      {:ok, %{id: "epistemic_foraging:community:uncertain"}}
    end
  end

  defmodule EmptyMemoryStub do
    def query_low_confidence_candidates(_query), do: {:ok, []}
    def submit_epistemic_foraging_event(_event), do: {:ok, %{id: "unused"}}
  end

  defmodule ExecutorStub do
    def execute_plan(intent) do
      if pid = Process.whereis(:epistemic_forager_observer) do
        send(pid, {:sandbox_execute_plan, intent})
      end

      {:ok, %{status: :exited, exit_code: 0, vm_id: "forage-vm", mode: :mock}}
    end
  end

  setup do
    Process.register(self(), :epistemic_forager_observer)

    on_exit(fn ->
      if Process.whereis(:epistemic_forager_observer) == self() do
        Process.unregister(:epistemic_forager_observer)
      end
    end)

    :ok
  end

  test "forage_idle/1 routes low-confidence probing through execute_plan and persists confidence updates" do
    assert {:ok, result} =
             EpistemicForager.forage_idle(
               policy: Core.MetabolismPolicy.build_policy(:low),
               memory_module: MemoryStub,
               executor_module: ExecutorStub
             )

    assert result.candidate["id"] == "community:uncertain"
    assert result.intent.action == "execute_plan"
    assert result.intent.transition_delta["foraging"]["candidate_id"] == "community:uncertain"
    assert result.intent.transition_delta["metabolism_admission"]["status"] == "admitted"

    assert_receive {:sandbox_execute_plan, intent}
    assert intent["action"] == "execute_plan"
    assert intent["params"]["steps"] |> hd() |> Map.get("action") == "probe_low_confidence_edge"

    assert_receive {:foraging_event_persisted, event}
    assert event["candidate_id"] == "community:uncertain"
    assert event["source_confidence"] == 0.22
    assert event["updated_confidence"] == 0.42
    assert event["confidence_delta"] == 0.2
    assert event["outcome_status"] == "exited"
  end

  test "forage_idle/1 refuses to probe when the organism is not idle" do
    assert {:error, :organism_not_idle} =
             EpistemicForager.forage_idle(
               policy: Core.MetabolismPolicy.build_policy(:high),
               memory_module: MemoryStub,
               executor_module: ExecutorStub
             )

    refute_received {:sandbox_execute_plan, _intent}
  end

  test "forage_idle/1 returns a bounded no-candidate error when nothing is uncertain" do
    assert {:error, :no_low_confidence_candidates} =
             EpistemicForager.forage_idle(
               policy: Core.MetabolismPolicy.build_policy(:low),
               memory_module: EmptyMemoryStub,
               executor_module: ExecutorStub
             )
  end
end
