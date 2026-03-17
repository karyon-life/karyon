defmodule Rhizome.ServiceIntegrationTest.MockMetabolicDaemon do
  use GenServer

  def start_link(pressure), do: GenServer.start_link(__MODULE__, pressure, name: Core.MetabolicDaemon)
  def init(pressure), do: {:ok, pressure}
  def handle_call(:get_pressure, _from, pressure), do: {:reply, pressure, pressure}
end

defmodule Rhizome.ServiceIntegrationTest do
  use ExUnit.Case, async: false
  @moduletag :external

  alias Rhizome.ConsolidationManager
  alias Rhizome.Native

  setup_all do
    case ensure_services_available() do
      :ok -> :ok
      {:error, reason} -> {:ok, skip: "Rhizome integration services unavailable: #{inspect(reason)}"}
    end
  end

  setup do
    token = "phase2_#{System.unique_integer([:positive])}"

    on_exit(fn ->
      cleanup_memgraph(token)
      cleanup_xtdb(token)
      stop_process(Core.MetabolicDaemon)
      stop_process(ConsolidationManager)
    end)

    {:ok, token: token}
  end

  test "writes and reads graph state from Memgraph", %{token: token} do
    assert {:ok, _} =
             Native.memgraph_query(
               "CREATE (:Phase2Probe {token: '#{token}', kind: 'graph_write'})"
             )

    assert {:ok, [%{"token" => ^token, "kind" => "graph_write"}]} =
             Native.memgraph_query(
               "MATCH (n:Phase2Probe {token: '#{token}'}) RETURN n.token AS token, n.kind AS kind"
             )
  end

  test "submits and queries temporal state from XTDB", %{token: token} do
    id = "xtdb_#{token}"

    assert {:ok, %{raw: _}} =
             eventually(fn ->
               Native.xtdb_submit(id, %{
                 "token" => token,
                 "kind" => "xtdb_write"
               })
             end)

    assert {:ok, results} =
             eventually(fn ->
               Native.xtdb_query(%{
                 "query" => %{
                   "find" => ["(pull ?e [*])"],
                   "where" => [["?e", "token", token]]
                 }
               })
             end)

    assert Enum.any?(results, fn row ->
             row["xt/id"] == id and row["token"] == token and row["kind"] == "xtdb_write"
           end)
  end

  test "bridges Memgraph state into XTDB", %{token: token} do
    assert {:ok, _} =
             Native.memgraph_query(
               "CREATE (:Phase2Probe {token: '#{token}', kind: 'bridge_candidate', archived: false})"
             )

    assert {:ok, [%{"count" => 1}]} =
             Native.memgraph_query(
               "MATCH (n:Phase2Probe {token: '#{token}'}) RETURN count(n) AS count"
             )

    assert {:ok, %{archived_count: count}} = eventually(fn -> Native.bridge_to_xtdb() end)
    assert count >= 1

    assert {:ok, results} =
             eventually(fn ->
               Native.xtdb_query(%{
                 "query" => %{
                   "find" => ["(pull ?e [*])"],
                   "where" => [["?e", "token", token]]
                 }
               })
             end)

    assert Enum.any?(results, fn row -> row["token"] == token and row["kind"] == "bridge_candidate" end)
  end

  test "consolidation manager prunes high-vfe cells against real services", %{token: token} do
    stop_process(Core.MetabolicDaemon)
    stop_process(ConsolidationManager)
    {:ok, _daemon} = Rhizome.ServiceIntegrationTest.MockMetabolicDaemon.start_link(:low)

    assert {:ok, _} =
             Native.memgraph_query(
               "CREATE (:Cell {token: '#{token}', vfe: 0.95, archived: false})"
             )

    manager =
      case ConsolidationManager.start_link() do
        {:ok, pid} -> pid
        {:error, {:already_started, pid}} -> pid
      end

    send(manager, :check_consolidation_window)
    Process.sleep(300)

    assert {:ok, [%{"count" => 0}]} =
             Native.memgraph_query(
               "MATCH (c:Cell {token: '#{token}'}) RETURN count(c) AS count"
             )
  end

  defp ensure_services_available do
    with {:ok, _} <- Native.memgraph_query("RETURN 1 AS health"),
         {:ok, _} <-
           eventually(fn ->
             Native.xtdb_query(%{
               "query" => %{
                 "find" => ["(pull ?e [xt/id])"],
                 "where" => []
               }
             })
           end) do
      :ok
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp cleanup_memgraph(token) do
    _ = Native.memgraph_query("MATCH (n {token: '#{token}'}) DETACH DELETE n")
  end

  defp cleanup_xtdb(token) do
    id = "xtdb_#{token}"
    _ = eventually(fn -> Native.xtdb_submit(id, %{"token" => token, "deleted" => true}) end)
  end

  defp stop_process(name) do
    case GenServer.whereis(name) do
      nil ->
        :ok

      pid ->
        Process.unlink(pid)
        ref = Process.monitor(pid)
        GenServer.stop(pid)

        receive do
          {:DOWN, ^ref, :process, ^pid, _reason} -> :ok
        after
          1_000 -> :ok
        end
    end
  end

  defp eventually(fun, attempts \\ 3)

  defp eventually(fun, 1), do: fun.()

  defp eventually(fun, attempts) do
    case fun.() do
      {:ok, _} = ok ->
        ok

      {:error, _reason} ->
        Process.sleep(100)
        eventually(fun, attempts - 1)
    end
  end
end
