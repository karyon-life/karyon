defmodule Core.ServiceHealthTest do
  use ExUnit.Case, async: true

  alias Core.ServiceHealth

  test "check_all reports healthy dependencies when probes pass" do
    report =
      ServiceHealth.check_all(
        memgraph_probe: fn -> :ok end,
        xtdb_probe: fn -> {:ok, :reachable} end,
        nats_probe: fn -> :ok end
      )

    assert report.overall == :ok
    assert report.services.memgraph.status == :up
    assert report.services.xtdb.status == :up
    assert report.services.nats.status == :up
  end

  test "ensure_ready returns blocked services and degraded report" do
    assert {:error, {:dependencies_unready, [:xtdb], report}} =
             ServiceHealth.ensure_ready(
               [:memgraph, :xtdb],
               memgraph_probe: fn -> :ok end,
               xtdb_probe: fn -> {:error, :refused} end,
               nats_probe: fn -> :ok end
             )

    assert report.overall == :degraded
    assert report.services.memgraph.status == :up
    assert report.services.xtdb.status == :down
    assert report.services.xtdb.detail == :refused
  end
end
