defmodule Sensory.Native do
  @moduledoc """
  Mock implementation of Sensory.Native for tests.
  """
  def parse_code(_lang, _code) do
    ~s({"nodes": [], "edges": []})
  end
end

defmodule Rhizome.Native do
  @moduledoc """
  Mock implementation of Rhizome.Native for tests.
  """
  def xtdb_submit(_id, _data) do
    {:ok, "tx_123"}
  end
end
