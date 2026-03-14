ExUnit.start()

defmodule Mint.HTTP do
  def connect(_, _, _), do: {:error, :mock}
  def request(_, _, _, _, _), do: {:error, :mock}
end
