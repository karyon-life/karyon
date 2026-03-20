defmodule OperatorEnvironment.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children =
      [
        OperatorEnvironmentWeb.Telemetry
      ] ++
        dns_cluster_children() ++
        [
          OperatorEnvironment.TelemetryBridge,
          OperatorEnvironmentWeb.Endpoint
        ]

    Supervisor.start_link(children, strategy: :one_for_one, name: OperatorEnvironment.Supervisor)
  end

  @impl true
  def config_change(changed, _new, removed) do
    OperatorEnvironmentWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp dns_cluster_children do
    if Application.get_env(:operator_environment, :start_dns_cluster, true) do
      [{DNSCluster, query: Application.get_env(:operator_environment, :dns_cluster_query) || "localhost"}]
    else
      []
    end
  end
end
