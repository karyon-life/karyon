ExUnit.start(exclude: [:external])
System.put_env("KARYON_MOCK_HARDWARE", "1")
# Ensure :pg is started for stigmergy/process groups
case :pg.start_link() do
  {:ok, _} -> :ok
  {:error, {:already_started, _}} -> :ok
end

Code.require_file("support/architecture_rubric.exs", __DIR__)
Code.require_file("support/chapter2_rubric.exs", __DIR__)

defmodule TestUtils do
  def wait_for_process(name, attempts \\ 10) do
    if Process.whereis(name) do
      :ok
    else
      if attempts > 0 do
        Process.sleep(100)
        wait_for_process(name, attempts - 1)
      else
        {:error, :timeout}
      end
    end
  end
end
