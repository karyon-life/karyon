defmodule OperatorEnvironmentWeb.CoreComponents do
  @moduledoc false

  use Phoenix.Component

  attr :flash, :map, default: %{}

  def flash_group(assigns) do
    ~H"""
    <div aria-live="polite">
      <div :for={{kind, msg} <- @flash} class={"flash #{kind}"}>{msg}</div>
    </div>
    """
  end

  attr :rest, :global
  slot :inner_block, required: true

  def button(assigns) do
    ~H"""
    <button {@rest}>{render_slot(@inner_block)}</button>
    """
  end
end
