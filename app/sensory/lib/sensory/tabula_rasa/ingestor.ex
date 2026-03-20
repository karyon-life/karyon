defmodule Sensory.TabulaRasa.Ingestor do
  @moduledoc """
  Continuous raw-byte ingestion and threshold-gated sequence pooling.
  """

  use GenServer

  alias Sensory.SpatialPooler

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
    carry = carryover(state.buffer, state.window_size)
    scan_input = carry <> payload
    updated_buffer = trim_buffer(state.buffer <> payload, state.max_buffer_size)

    {activated, counts} =
      scan_input
      |> SpatialPooler.extract_windows(state.window_size)
      |> Enum.reduce({[], state.sequence_counts}, fn sequence, {acc, counts} ->
        signature = Base.encode16(sequence, case: :lower)
        previous = Map.get(counts, signature, %{sequence: sequence, occurrences: 0})
        current = %{sequence: sequence, occurrences: previous.occurrences + 1}
        next_counts = Map.put(counts, signature, current)

        if current.occurrences >= state.threshold and current.occurrences != previous.occurrences do
          case state.memory_module.persist_pooled_sequence(%{
                 sequence: sequence,
                 encoding: infer_encoding(sequence),
                 occurrences: current.occurrences,
                 activation_threshold: state.threshold,
                 window_size: state.window_size,
                 observed_at: System.system_time(:second),
                 source: "operator_environment",
                 organ: "tabula_rasa_ingestor"
               }) do
            {:ok, result} ->
              activated_sequence = %{
                sequence_id: result.sequence_id,
                signature: signature,
                occurrences: current.occurrences,
                activation_threshold: state.threshold
              }

              {[activated_sequence | acc], next_counts}

            {:error, _reason} ->
              {acc, next_counts}
          end
        else
          {acc, next_counts}
        end
      end)

    {Enum.reverse(activated), %{state | buffer: updated_buffer, sequence_counts: counts}}
  end

  defp carryover(buffer, window_size) do
    carry_size = max(window_size - 1, 0)
    size = byte_size(buffer)

    cond do
      carry_size == 0 -> <<>>
      size <= carry_size -> buffer
      true -> binary_part(buffer, size - carry_size, carry_size)
    end
  end

  defp trim_buffer(buffer, max_buffer_size) when byte_size(buffer) <= max_buffer_size, do: buffer
  defp trim_buffer(buffer, max_buffer_size), do: binary_part(buffer, byte_size(buffer) - max_buffer_size, max_buffer_size)

  defp infer_encoding(payload) do
    if String.valid?(payload), do: "utf8", else: "binary"
  end
end
