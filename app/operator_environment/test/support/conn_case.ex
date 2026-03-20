defmodule OperatorEnvironmentWeb.ConnCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      @endpoint OperatorEnvironmentWeb.Endpoint

      use OperatorEnvironmentWeb, :verified_routes

      import Plug.Conn
      import Phoenix.ConnTest
      import OperatorEnvironmentWeb.ConnCase
    end
  end

  setup _tags do
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end
end
