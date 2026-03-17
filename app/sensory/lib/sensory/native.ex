defmodule Sensory.Native do
  @moduledoc """
  NIF bridge for the Sensory layer (Tree-sitter).
  """
  alias Sensory.Raw

  def parse_code(lang, code), do: Raw.parse_code(lang, code)
  def parse_to_graph(lang, code), do: Raw.parse_to_graph(lang, code)
  def zmq_publish_tensor(topic, payload), do: Raw.zmq_publish_tensor(topic, payload)
  def zmq_subscribe_sensory(topic), do: Raw.zmq_subscribe_sensory(topic)

  def ingest_to_memgraph(lang, code) do
    Raw.ingest_to_memgraph(lang, code, memgraph_config_json())
  end

  defp memgraph_config_json do
    :karyon
    |> Application.get_env(:services, [])
    |> Keyword.get(:memgraph, [])
    |> Enum.into(%{})
    |> Jason.encode!()
  end
end
