defmodule Rhizome.Optimizer do
  @moduledoc """
  Background process for graph memory consolidation (Sleep Cycle).
  """
  use GenServer
  require Logger

  @interval_ms 60_000 # 1 minute for demo

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @impl true
  def init(state) do
    schedule_optimization()
    {:ok, state}
  end

  @impl true
  def handle_info(:optimize, state) do
    Logger.info("[Rhizome.Optimizer] Beginning Sleep Cycle memory consolidation...")
    result = Rhizome.Native.optimize_graph()
    Logger.info("[Rhizome.Optimizer] #{format_result(result)}")
    
    schedule_optimization()
    {:noreply, state}
  end

  defp schedule_optimization do
    Process.send_after(self(), :optimize, @interval_ms)
  end

  defp format_result({:ok, message}) when is_binary(message), do: message
  defp format_result({:error, message}) when is_binary(message), do: "error: #{message}"
  defp format_result(other), do: inspect(other)
end
