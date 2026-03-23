defmodule Sensory.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Sensory.StreamSupervisor, []},
      {Sensory.NifRouter, []}
    ]
    opts = [strategy: :one_for_one, name: Sensory.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
