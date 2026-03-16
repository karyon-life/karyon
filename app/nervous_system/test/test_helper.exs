ExUnit.start()
case :pg.start_link() do
  {:ok, _} -> :ok
  {:error, {:already_started, _}} -> :ok
end
