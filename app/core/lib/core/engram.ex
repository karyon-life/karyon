defmodule Core.Engram do
  @moduledoc """
  Engram management logic.
  Handles serialization of the Rhizome graph into portable topological "Engrams".
  Used for air-gapped knowledge transfer and collective memory synchronization.
  """
  alias Rhizome.Native
  require Logger

  @engram_path "priv/engrams/"

  @doc """
  Exports the current Rhizome state to a compressed engram file.
  """
  def capture(name) do
    Logger.info("[Engram] Capturing topological state as: #{name}")
    
    # 1. Fetch all nodes and edges (simplified)
    # In production, this would use a native dump for performance
    case Native.memgraph_query("MATCH (n)-[r]->(m) RETURN n, r, m") do
      {:ok, rows} when is_list(rows) ->
        path = "#{@engram_path}#{name}.engram"
        File.mkdir_p!(@engram_path)
        
        # 2. Serialize and compress
        binary = :erlang.term_to_binary(rows, [:compressed])
        File.write!(path, binary)
        
        Logger.info("[Engram] Engram saved to #{path} (#{byte_size(binary)} bytes)")
        {:ok, path}
      
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Injects an engram's topological state into the local Rhizome.
  """
  def inject(name) do
    path = "#{@engram_path}#{name}.engram"
    Logger.info("[Engram] Injecting topological state from: #{path}")

    if File.exists?(path) do
      binary = File.read!(path)
      data = :erlang.binary_to_term(binary)
      
      # 3. Import logic
      if is_list(data) do
        Enum.each(data, fn row ->
          with {:ok, source_id, target_id} <- extract_link_endpoints(row) do
            Native.memgraph_query(
              "MERGE (n {id: '#{source_id}'}) MERGE (m {id: '#{target_id}'}) CREATE (n)-[:KNOWLEDGE_LINK]->(m)"
            )
          end
        end)
      end
      
      Logger.info("[Engram] Injection complete.")
      :ok
    else
      {:error, :engram_not_found}
    end
  end

  defp extract_link_endpoints(%{"n" => source, "m" => target}) do
    with {:ok, source_id} <- extract_entity_id(source),
         {:ok, target_id} <- extract_entity_id(target) do
      {:ok, source_id, target_id}
    end
  end

  defp extract_link_endpoints(_row), do: {:error, :invalid_engram_row}

  defp extract_entity_id(%{"id" => id}) when is_binary(id), do: {:ok, id}
  defp extract_entity_id(%{"id" => id}) when is_integer(id), do: {:ok, Integer.to_string(id)}
  defp extract_entity_id(%{"properties" => %{"id" => id}}) when is_binary(id), do: {:ok, id}
  defp extract_entity_id(%{"properties" => %{"id" => id}}) when is_integer(id), do: {:ok, Integer.to_string(id)}
  defp extract_entity_id(_entity), do: {:error, :missing_entity_id}
end
