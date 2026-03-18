defmodule Mix.Tasks.Biology.Invariants do
  use Mix.Task

  @shortdoc "Runs the umbrella biology-first invariant suite"

  @impl true
  def run(_args) do
    Mix.Task.run("loadpaths")

    test_helper = Path.expand("../../test/test_helper.exs", __DIR__)
    test_file = Path.expand("../../test/biology_first_invariants_test.exs", __DIR__)

    Code.require_file(test_helper)
    Code.require_file(test_file)

    case ExUnit.run() do
      %{failures: 0} ->
        :ok

      _results ->
        Mix.raise("Biology-first invariants failed")
    end
  end
end
