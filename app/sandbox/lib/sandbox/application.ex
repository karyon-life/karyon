defmodule Sandbox.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Firecracker orchestration pooling will go here
    ]

    opts = [strategy: :one_for_one, name: Sandbox.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
