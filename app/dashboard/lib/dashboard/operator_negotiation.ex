defmodule Dashboard.OperatorNegotiation do
  @moduledoc """
  Dashboard-facing adapter for sovereign refusal and negotiation briefs.
  """

  def render(event), do: Core.OperatorOutput.render_sovereign_decision(event)
end
