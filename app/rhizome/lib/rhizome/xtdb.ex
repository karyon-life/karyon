defmodule Rhizome.Xtdb do
  @moduledoc false

  @table "karyon_documents"
  @document_column "karyon_doc"

  def submit(id, document) when is_binary(id) and is_map(document) do
    with {:ok, conn} <- connect(),
         {:ok, _} <- ensure_table(conn),
         {:ok, encoded} <- Jason.encode(document),
         {:ok, _result} <- insert_document(conn, id, encoded) do
      GenServer.stop(conn)
      {:ok, %{"table" => @table, "xt/id" => id}}
    else
      {:error, reason} -> {:error, format_error(reason)}
    end
  end

  def query(%{"query" => %{} = query_map}) do
    with {:ok, conn} <- connect(),
         {:ok, _} <- ensure_table(conn),
         {:ok, rows} <- fetch_documents(conn, query_map) do
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

  defp insert_document(conn, id, encoded_document) do
    sql = """
    INSERT INTO #{@table} RECORDS {_id: #{sql_string(id)}, #{@document_column}: #{sql_string(encoded_document)}}
    """

    case Postgrex.query(conn, sql, []) do
      {:ok, result} -> {:ok, result}
      {:error, error} -> {:error, error}
    end
  end

  defp fetch_documents(conn, query_map) do
    sql = """
    SELECT _id, #{@document_column}
    FROM #{@table}
    """

    case Postgrex.query(conn, sql, []) do
      {:ok, %Postgrex.Result{rows: rows}} ->
        rows
        |> Enum.map(&row_to_document/1)
        |> apply_where(query_map)
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

    Map.put(document, "xt/id", id)
  end

  defp apply_where(rows, %{"where" => clauses}) when is_list(clauses) do
    Enum.filter(rows, fn row ->
      Enum.all?(clauses, fn
        [_var, "xt/id", value] -> row["xt/id"] == value
        [_var, attribute, value] -> row[attribute] == value
        _ -> false
      end)
    end)
  end

  defp apply_where(rows, _query_map), do: rows

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
