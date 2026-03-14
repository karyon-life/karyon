ExUnit.start()

defmodule Sensory.Native do
  def parse_code(_lang, _code), do: ~s({"nodes": [], "edges": []})
end

defmodule Rhizome.Native do
  def xtdb_submit(_id, _data), do: {:ok, "tx_123"}
end
