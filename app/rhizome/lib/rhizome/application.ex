defmodule Rhizome.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Memory layer supervisors will go here
    ]

    opts = [strategy: :one_for_one, name: Rhizome.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
