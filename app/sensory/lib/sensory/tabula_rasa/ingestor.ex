defmodule Sensory.TabulaRasa.Ingestor do
  @moduledoc """
  Continuous raw-byte ingestion and threshold-gated sequence pooling.
  """

  use GenServer

  @default_window_size 5
  @default_threshold 2
  @default_max_buffer_size 256

  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  def ingest_bytes(payload, opts \\ [])

  def ingest_bytes(payload, opts) when is_binary(payload) and is_list(opts) do
    server = Keyword.get(opts, :server, __MODULE__)
    GenServer.call(server, {:ingest_bytes, payload})
  end

  def snapshot(server \\ __MODULE__) do
    GenServer.call(server, :snapshot)
  end

  @impl true
  def init(opts) do
    {:ok,
     %{
       buffer: <<>>,
       sequence_counts: %{},
       window_size: Keyword.get(opts, :window_size, @default_window_size),
       threshold: Keyword.get(opts, :threshold, @default_threshold),
       max_buffer_size: Keyword.get(opts, :max_buffer_size, @default_max_buffer_size),
       memory_module: Keyword.get(opts, :memory_module, Application.get_env(:sensory, :memory_module, Rhizome.Memory))
     }}
  end

  @impl true
  def handle_call({:ingest_bytes, payload}, _from, state) when is_binary(payload) do
    {activated, next_state} = ingest_payload(payload, state)

    {:reply,
     {:ok,
      %{
        ingested_bytes: byte_size(payload),
        window_size: state.window_size,
        activation_threshold: state.threshold,
        pooled_sequences: activated
      }}, next_state}
  end

  def handle_call(:snapshot, _from, state) do
    {:reply,
     %{
       buffer: state.buffer,
       buffer_size: byte_size(state.buffer),
       window_size: state.window_size,
       activation_threshold: state.threshold,
       sequence_count: map_size(state.sequence_counts),
       sequence_counts: state.sequence_counts
     }, state}
  end

  defp ingest_payload(payload, state) do
    # With Elixir pooling removed, the ingestor natively forwards raw buffers to the Rust NIF boundary.
    # We maintain the buffer constraint but drop SpatialPooler.
    updated_buffer = trim_buffer(state.buffer <> payload, state.max_buffer_size)

    # Return empty activated sequences as token minting now occurs asynchronously via Sensory.NifRouter
    {[], %{state | buffer: updated_buffer, sequence_counts: state.sequence_counts}}
  end

  defp trim_buffer(buffer, max_buffer_size) when byte_size(buffer) <= max_buffer_size, do: buffer
  defp trim_buffer(buffer, max_buffer_size), do: binary_part(buffer, byte_size(buffer) - max_buffer_size, max_buffer_size)
end
