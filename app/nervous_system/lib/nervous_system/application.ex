defmodule NervousSystem.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    # Currently setting up supervised communication lines.
    children = [
      NervousSystem.PainReceptor
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: NervousSystem.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
