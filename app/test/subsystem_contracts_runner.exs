Code.require_file("test_helper.exs", __DIR__)
Code.require_file("subsystem_contracts_test.exs", __DIR__)

case ExUnit.run() do
  %{failures: 0} ->
    :ok

  _results ->
    Mix.raise("Subsystem contracts failed")
end
