defmodule Rhizome.Xtdb do
  @moduledoc false

  @table "karyon_documents"
  @document_column "karyon_doc"

  def submit(id, document, opts \\ [])

  def submit(id, document, opts) when is_binary(id) and is_map(document) and is_list(opts) do
    with {:ok, conn} <- connect(),
         {:ok, _} <- ensure_table(conn),
         {:ok, enriched_document} <- enrich_document(conn, id, document, opts),
         {:ok, encoded} <- Jason.encode(enriched_document),
         {:ok, _result} <- insert_document(conn, storage_id(enriched_document), encoded) do
      GenServer.stop(conn)
      {:ok,
       %{
         "table" => @table,
         "xt/id" => enriched_document["xt/id"],
         "xt/revision" => enriched_document["xt/revision"],
         "xt/valid_time" => enriched_document["xt/valid_time"],
         "xt/tx_time" => enriched_document["xt/tx_time"]
       }}
    else
      {:error, reason} -> {:error, format_error(reason)}
    end
  end

  def query(%{"query" => %{} = query_map} = request) do
    with {:ok, conn} <- connect(),
         {:ok, _} <- ensure_table(conn),
         {:ok, rows} <- fetch_documents(conn, query_map, Map.get(request, "opts", %{})) do
      GenServer.stop(conn)
      {:ok, rows}
    else
      {:error, reason} -> {:error, format_error(reason)}
    end
  end

  def query(_query), do: {:error, :invalid_xtdb_query}

  defp connect do
    xtdb_config()
    |> Postgrex.start_link()
  end

  defp ensure_table(conn) do
    sql = """
    INSERT INTO #{@table} RECORDS {_id: '__karyon_bootstrap__', #{@document_column}: '{}'}
    """

    case Postgrex.query(conn, sql, []) do
      {:ok, _result} -> {:ok, :ready}
      {:error, %Postgrex.Error{postgres: %{code: :unique_violation}}} -> {:ok, :ready}
      {:error, error} -> {:error, error}
    end
  end

  defp enrich_document(conn, id, document, opts) do
    valid_time =
      document["xt/valid_time"] ||
        document[:valid_time] ||
        Keyword.get(opts, :valid_time) ||
        timestamp_now()

    revision = next_revision(conn, id)
    tx_time = timestamp_now()

    {:ok,
     document
     |> Map.put("xt/id", id)
     |> Map.put("xt/revision", revision)
     |> Map.put("xt/valid_time", valid_time)
     |> Map.put("xt/tx_time", tx_time)}
  end

  defp insert_document(conn, id, encoded_document) do
    sql = """
    INSERT INTO #{@table} RECORDS {_id: #{sql_string(id)}, #{@document_column}: #{sql_string(encoded_document)}}
    """

    case Postgrex.query(conn, sql, []) do
      {:ok, result} -> {:ok, result}
      {:error, error} -> {:error, error}
    end
  end

  defp fetch_documents(conn, query_map, opts) do
    sql = """
    SELECT _id, #{@document_column}
    FROM #{@table}
    """

    case Postgrex.query(conn, sql, []) do
      {:ok, %Postgrex.Result{rows: rows}} ->
        rows
        |> Enum.map(&row_to_document/1)
        |> Enum.reject(&bootstrap_document?/1)
        |> apply_where(query_map)
        |> apply_as_of(opts)
        |> collapse_history(opts)
        |> sort_rows()
        |> project_find(query_map)
        |> then(&{:ok, &1})

      {:error, error} ->
        {:error, error}
    end
  end

  defp row_to_document([id, encoded_document]) do
    document =
      case Jason.decode(encoded_document) do
        {:ok, decoded} when is_map(decoded) -> decoded
        _ -> %{}
      end

    document
    |> Map.put_new("xt/id", id)
    |> Map.put_new("xt/revision", 0)
    |> Map.put_new("xt/tx_time", timestamp_now())
    |> Map.put_new("xt/valid_time", timestamp_now())
  end

  defp apply_where(rows, %{"where" => clauses}) when is_list(clauses) do
    Enum.filter(rows, fn row ->
      Enum.all?(clauses, fn
        [_var, "xt/id", value] -> row["xt/id"] == value
        [_var, "xt/revision", value] -> row["xt/revision"] == value
        [_var, attribute, value] -> row[attribute] == value
        _ -> false
      end)
    end)
  end

  defp apply_where(rows, _query_map), do: rows

  defp apply_as_of(rows, %{"as_of" => as_of}) when is_binary(as_of) do
    Enum.filter(rows, fn row ->
      compare_timestamps(row["xt/valid_time"], as_of) != :gt
    end)
  end

  defp apply_as_of(rows, _opts), do: rows

  defp collapse_history(rows, %{"history" => true}), do: rows

  defp collapse_history(rows, _opts) do
    rows
    |> Enum.group_by(& &1["xt/id"])
    |> Enum.map(fn {_id, versions} -> Enum.max_by(versions, &version_sort_key/1) end)
  end

  defp sort_rows(rows) do
    Enum.sort_by(rows, &version_sort_key/1)
  end

  defp project_find(rows, %{"find" => [pull | _rest]}) when is_binary(pull) do
    case parse_pull_fields(pull) do
      :all -> rows
      fields -> Enum.map(rows, &Map.take(&1, fields))
    end
  end

  defp project_find(rows, _query_map), do: rows

  defp parse_pull_fields("(pull " <> rest) do
    case Regex.run(~r/\[(.*?)\]/, rest, capture: :all_but_first) do
      ["*"] -> :all
      [fields] -> String.split(fields, ~r/\s+/, trim: true)
      _ -> :all
    end
  end

  defp parse_pull_fields(_other), do: :all

  defp bootstrap_document?(%{"xt/id" => "__karyon_bootstrap__"}), do: true
  defp bootstrap_document?(_row), do: false

  defp next_revision(conn, id) do
    case fetch_documents(
           conn,
           %{"where" => [["?e", "xt/id", id]]},
           %{"history" => true}
         ) do
      {:ok, []} ->
        1

      {:ok, rows} ->
        rows
        |> Enum.map(&(&1["xt/revision"] || 0))
        |> Enum.max(fn -> 0 end)
        |> Kernel.+(1)

      {:error, _reason} ->
        1
    end
  end

  defp storage_id(%{"xt/id" => id, "xt/revision" => revision, "xt/tx_time" => tx_time}) do
    "#{id}::rev::#{revision}::tx::#{tx_time}"
  end

  defp version_sort_key(row) do
    {
      row["xt/revision"] || 0,
      row["xt/valid_time"] || "",
      row["xt/tx_time"] || ""
    }
  end

  defp compare_timestamps(left, right) do
    case {DateTime.from_iso8601(left), DateTime.from_iso8601(right)} do
      {{:ok, left_dt, _}, {:ok, right_dt, _}} -> DateTime.compare(left_dt, right_dt)
      _ -> :eq
    end
  end

  defp timestamp_now do
    DateTime.utc_now() |> DateTime.truncate(:microsecond) |> DateTime.to_iso8601()
  end

  defp xtdb_config do
    url =
      :karyon
      |> Application.get_env(:services, [])
      |> Keyword.get(:xtdb, [])
      |> Keyword.get(:url, "postgres://127.0.0.1:5432/xtdb")

    uri = URI.parse(url)
    {username, password} = credentials(uri.userinfo)

    [
      hostname: uri.host || "127.0.0.1",
      port: uri.port || 5432,
      database: database_name(uri.path),
      username: username,
      password: password
    ]
    |> Enum.reject(fn {_key, value} -> is_nil(value) or value == "" end)
  end

  defp database_name(nil), do: "xtdb"
  defp database_name("/"), do: "xtdb"
  defp database_name(path), do: String.trim_leading(path, "/")

  defp credentials(nil), do: {nil, nil}

  defp credentials(userinfo) do
    case String.split(userinfo, ":", parts: 2) do
      [username, password] -> {username, password}
      [username] -> {username, nil}
    end
  end

  defp sql_string(value) do
    escaped = String.replace(value, "'", "''")
    "'#{escaped}'"
  end

  defp format_error(%Postgrex.Error{} = error), do: "XTDB Error: #{Exception.message(error)}"
  defp format_error(reason), do: "XTDB Error: #{inspect(reason)}"
end
