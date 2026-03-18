defmodule Dashboard.OperatorFeedback do
  @moduledoc """
  Dashboard-facing adapter for bounded operator feedback capture.
  """

  def submit(event), do: Core.OperatorFeedback.record_event(event)
end
