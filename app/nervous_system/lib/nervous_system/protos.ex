defmodule NervousSystem.Protos do
  @moduledoc """
  Managed Protocol Buffer modules generated via protox.
  Strictly enforces Tier-2 synaptic schema integrity.
  """

  # Generate modules for internal signaling
  use Protox,
    files: [
      "./priv/proto/prediction_error.proto",
      "./priv/proto/metabolic_spike.proto"
    ]

  # Re-export or alias for convenience if needed, 
  # but protox will generate Karyon.NervousSystem.PredictionError etc.
end
