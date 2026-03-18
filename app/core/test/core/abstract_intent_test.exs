defmodule Core.AbstractIntentTest do
  use ExUnit.Case, async: true

  alias Core.AbstractIntent

  defmodule MemoryStub do
    def submit_abstract_intent_event(event) do
      send(self(), {:abstract_intent_persisted, event})
      {:ok, %{id: event["intent_bundle_id"]}}
    end
  end

  test "ingest_sources/2 converts docs and git history into directives plus drift evidence" do
    source =
      write_fixture!(
        "abstract_intent_source.md",
        """
        # Monorepo Intent

        The repository root is the engine workspace and is treated as read-only control plane state.
        The teacher daemon must execute synthetic exams through sandbox validation.
        """
      )

    assert {:ok, bundle} =
             AbstractIntent.ingest_sources(
               [source],
               memory_module: MemoryStub,
               git_history: [
                 %{"sha" => "abc123", "timestamp" => "1773869520", "subject" => "Updates to the PLAN and TASKS files."}
               ],
               observed_signals: %{
                 "engine_workspace_boundary" => true,
                 "teacher_daemon" => false,
                 "execution_telemetry" => true,
                 "objective_manifest" => true
               }
             )

    assert bundle["schema"] == "karyon.abstract-intent.v1"
    assert length(bundle["source_documents"]) == 1
    assert length(bundle["directives"]) == 2
    assert [%{"sha" => "abc123"}] = bundle["git_history"]
    assert length(bundle["drift_events"]) == 1
    assert hd(bundle["drift_events"])["expected_signal"] == "teacher_daemon"
    assert_received {:abstract_intent_persisted, persisted}
    assert persisted["intent_bundle_id"] == bundle["intent_bundle_id"]
  end

  test "ingest_sources/2 rejects invalid source lists" do
    assert {:error, :invalid_abstract_intent_sources} = AbstractIntent.ingest_sources("bad")
  end

  defp write_fixture!(name, body) do
    path = Path.join(System.tmp_dir!(), "#{name}-#{System.unique_integer([:positive])}")
    File.write!(path, body)
    on_exit(fn -> File.rm(path) end)
    path
  end
end
