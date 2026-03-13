defmodule Core.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    # 1. Start Erlang's Process Group scope for decentralized routing without global dictionaries.
    :pg.start_link()

    # 2. Define our Supervision Tree
    children = [
      Core.EpigeneticSupervisor
    ]

    # Use one_for_one strategy. Let it crash constraint.
    opts = [strategy: :one_for_one, name: Core.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
