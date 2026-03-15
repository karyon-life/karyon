defmodule Rhizome.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      Rhizome.Optimizer,
      Rhizome.Archiver
    ]

    opts = [strategy: :one_for_one, name: Rhizome.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
