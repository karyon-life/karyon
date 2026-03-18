defmodule Core.ServiceHealth do
  @moduledoc """
  Dependency health checks for service-backed organism paths.
  """

  alias Core.MetabolismPolicy
  alias NervousSystem.Endocrine
  alias Rhizome.Native

  @type status :: :up | :down

  def check_all(opts \\ []) do
    checks = %{
      memgraph: run_probe(opts, :memgraph_probe, &memgraph_probe/0),
      xtdb: run_probe(opts, :xtdb_probe, &xtdb_probe/0),
      nats: run_probe(opts, :nats_probe, &nats_probe/0)
    }

    %{
      overall: overall_status(checks),
      services: checks,
      runtime: runtime_status(opts)
    }
  end

  def ensure_ready(required_services \\ [:memgraph, :xtdb, :nats], opts \\ []) do
    report = check_all(opts)

    case Enum.filter(required_services, &(service_down?(report, &1))) do
      [] -> :ok
      blocked -> {:error, {:dependencies_unready, blocked, report}}
    end
  end

  defp run_probe(opts, key, fallback) do
    probe = Keyword.get(opts, key, fallback)

    case probe.() do
      :ok -> %{status: :up, detail: :ok}
      {:ok, detail} -> %{status: :up, detail: detail}
      {:error, reason} -> %{status: :down, detail: reason}
      other -> %{status: :down, detail: {:invalid_probe_result, other}}
    end
  end

  defp overall_status(checks) do
    if Enum.all?(checks, fn {_service, %{status: status}} -> status == :up end) do
      :ok
    else
      :degraded
    end
  end

  defp service_down?(report, service) do
    get_in(report, [:services, service, :status]) != :up
  end

  defp runtime_status(opts) do
    policy =
      opts
      |> Keyword.get(:metabolism_policy, &MetabolismPolicy.current_policy/0)
      |> then(& &1.())

    %{
      metabolism: MetabolismPolicy.to_map(policy),
      admission: %{
        "spawn_budget" => Map.get(policy, :atp, 1.0),
        "pressure" => policy |> Map.get(:pressure, :low) |> to_string()
      }
    }
  end

  defp memgraph_probe do
    case Native.memgraph_query("RETURN 1 AS health") do
      {:ok, _rows} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp xtdb_probe do
    query = %{
      "query" => %{
        "find" => ["(pull ?e [xt/id])"],
        "where" => []
      }
    }

    case Native.xtdb_query(query) do
      {:ok, _rows} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp nats_probe do
    client_id = "health_probe_#{System.unique_integer([:positive])}"

    case Endocrine.start_connection(client_id) do
      {:ok, pid} ->
        GenServer.stop(pid)
        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end
end
