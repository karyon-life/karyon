defmodule Rhizome.Memory do
  @moduledoc """
  High-level interface for Tier-0 and Tier-1 memory operations.
  """

  @doc """
  Executes a topology query against Memgraph (Tier-0).
  """
  def query_memgraph(query) do
    Rhizome.Native.memgraph_query(query)
  end

  @doc """
  Submits a bitemporal transaction to XTDB (Tier-1).
  """
  def submit_xtdb(id, data) do
    Rhizome.Native.xtdb_submit(id, Jason.encode!(data))
  end
end
