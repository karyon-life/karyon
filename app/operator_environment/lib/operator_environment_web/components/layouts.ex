defmodule OperatorEnvironmentWeb.Layouts do
  @moduledoc false

  use OperatorEnvironmentWeb, :html

  embed_templates "layouts/*"

  attr :flash, :map, default: %{}
  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <main>
      {render_slot(@inner_block)}
    </main>
    <.flash_group flash={@flash} />
    """
  end
end
