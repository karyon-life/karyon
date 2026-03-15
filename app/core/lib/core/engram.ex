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
      {:ok, data} ->
        path = "#{@engram_path}#{name}.engram"
        File.mkdir_p!(@engram_path)
        
        # 2. Serialize and compress
        binary = :erlang.term_to_binary(data, [:compressed])
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
        Enum.each(data, fn [n, _r, m] ->
          Native.memgraph_query("MERGE (n {id: '#{n["id"]}'}) MERGE (m {id: '#{m["id"]}'}) CREATE (n)-[:KNOWLEDGE_LINK]->(m)")
        end)
      end
      
      Logger.info("[Engram] Injection complete.")
      :ok
    else
      {:error, :engram_not_found}
    end
  end
end
