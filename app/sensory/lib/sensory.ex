defmodule Sensory do
  @moduledoc """
  The Sensory Perimeter for Karyon.
  Raw-byte ingestion and bounded sensory discovery for a tabula rasa organism.
  """

  alias Sensory.Perimeter

  defdelegate perimeter_contract(), to: Perimeter, as: :contract
  defdelegate allowed_organs(), to: Perimeter
  defdelegate allowed_surfaces(), to: Perimeter
  defdelegate validate_ingestion(spec), to: Perimeter
end
