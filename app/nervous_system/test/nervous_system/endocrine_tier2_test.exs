defmodule NervousSystem.EndocrineTier2Test do
  use ExUnit.Case
  alias NervousSystem.Endocrine

  # Note: This test requires a running NATS server or a mock.
  # If NATS isn't available, we'll test the Elixir interface logic.
  
  setup do
    Application.ensure_all_started(:kernel)
    :ok
  end

  test "Endocrine: Connection and broadcast interface" do
    Code.ensure_loaded(Endocrine)
    assert function_exported?(Endocrine, :start_connection, 1)
    assert function_exported?(Endocrine, :start_connection, 2)
    assert function_exported?(Endocrine, :publish_gradient, 3)
  end
end
