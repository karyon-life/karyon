defmodule NervousSystem.EndocrinePropertyTest do
  use ExUnit.Case
  use ExUnitProperties

  setup do
    # Ensure :pg is started (default scope)
    case :pg.start_link() do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
    end
    :ok
  end

  property "decentralized routing via :pg remains consistent" do
    check all topic <- StreamData.atom(:alphanumeric),
              count <- StreamData.integer(1..10) do
      
      pids = for _ <- 1..count do
        pid = spawn(fn -> receive do :stop -> :ok end end)
        :pg.join(topic, pid)
        pid
      end
      
      members = :pg.get_members(topic)
      assert length(members) == count
      
      # Clean up
      for pid <- pids, do: send(pid, :stop)
    end
  end
end
