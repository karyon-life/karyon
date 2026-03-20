defmodule Dashboard.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children =
      [
        DashboardWeb.Telemetry,
        {Phoenix.PubSub, name: Dashboard.PubSub}
      ] ++
        dns_cluster_children() ++
        [
          Dashboard.TelemetryBridge,
          {Finch, name: Dashboard.Finch},
          DashboardWeb.Endpoint
        ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Dashboard.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    DashboardWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp dns_cluster_children do
    if Application.get_env(:dashboard, :start_dns_cluster, true) do
      [{DNSCluster, query: Application.get_env(:dashboard, :dns_cluster_query) || "localhost"}]
    else
      []
    end
  end
end
