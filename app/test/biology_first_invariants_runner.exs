Code.require_file("test_helper.exs", __DIR__)
Code.require_file("biology_first_invariants_test.exs", __DIR__)

case ExUnit.run() do
  %{failures: 0} ->
    :ok

  _results ->
    Mix.raise("Biology-first invariants failed")
end
