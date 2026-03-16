defmodule Core.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    # 1. Start Erlang's Process Group scope for decentralized routing without global dictionaries.
    # Handle already started case in test environments.
    case :pg.start_link() do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
    end

    # 2. Define our Supervision Tree
    children = [
      Core.EpigeneticSupervisor,
      Core.MetabolicDaemon,
      Core.StressTester
    ]

    # Use one_for_one strategy. Let it crash constraint.
    opts = [strategy: :one_for_one, name: Core.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
