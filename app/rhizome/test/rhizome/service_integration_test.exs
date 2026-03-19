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
  alias Rhizome.Memory
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
             Memory.upsert_graph_node(%{
               label: "Phase2Probe",
               id: token,
               properties: %{token: token, kind: "graph_write"}
             })

    assert {:ok, [%{"token" => ^token, "kind" => "graph_write"} | _]} =
             Memory.query_working_memory(%{
               label: "Phase2Probe",
               filters: %{token: token},
               return: [:token, :kind]
             })
  end

  test "submits and queries temporal state from XTDB", %{token: token} do
    id = "xtdb_#{token}"

    assert {:ok, %{raw: _}} =
             eventually(fn ->
               Memory.write_archive_document(id, %{
                 "token" => token,
                 "kind" => "xtdb_write"
               })
             end)

    assert {:ok, results} =
             eventually(fn ->
               Memory.query_archive(%{
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
             Memory.upsert_graph_node(%{
               label: "Phase2Probe",
               id: token,
               properties: %{token: token, kind: "bridge_candidate", archived: false}
             })

    assert {:ok, [%{"token" => ^token} | _]} =
             Memory.query_working_memory(%{
               label: "Phase2Probe",
               filters: %{token: token},
               return: [:token]
             })

    assert {:ok, %{archived_count: count}} = eventually(fn -> Memory.bridge_working_memory_to_archive() end)
    assert count >= 1

    assert {:ok, results} =
             eventually(fn ->
               Memory.query_archive(%{
                 "query" => %{
                   "find" => ["(pull ?e [*])"],
                   "where" => [["?e", "token", token]]
                 }
               })
             end)

    assert Enum.any?(results, fn row -> row["token"] == token and row["kind"] == "bridge_candidate" end)
  end

  test "consolidation manager retains cells in archive instead of deleting them against real services", %{token: token} do
    stop_process(Core.MetabolicDaemon)
    stop_process(ConsolidationManager)

    assert {:ok, _} =
             Memory.upsert_graph_node(%{
               label: "Cell",
               id: token,
               properties: %{token: token, vfe: 0.95, archived: false}
             })

    result = ConsolidationManager.run_once(schedule_next?: false)

    assert {:ok, %{archived_count: count}} = result.bridge_to_xtdb
    assert count >= 1
    assert {:ok, %{pruned_count: count, retained_in_archive: true}} = result.memory_relief
    assert count >= 1

    assert {:ok, [%{"archived" => true}]} =
             eventually(fn ->
               with {:ok, [%{"archived" => true} = row]} <-
                      Memory.query_working_memory(%{
                        label: "Cell",
                        filters: %{token: token},
                        return: [:archived, :sleep_cycle_status, :retained_in_archive]
                      }) do
                 {:ok, [row]}
               else
                 _ -> {:error, :not_consolidated_yet}
               end
             end)
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

  defp eventually(fun, attempts \\ 10)

  defp eventually(fun, 1), do: fun.()

  defp eventually(fun, attempts) do
    case fun.() do
      {:ok, _} = ok ->
        ok

      {:error, _reason} ->
        Process.sleep(200)
        eventually(fun, attempts - 1)
    end
  end
end
