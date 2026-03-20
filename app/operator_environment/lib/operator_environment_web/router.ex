defmodule OperatorEnvironmentWeb.Router do
  use OperatorEnvironmentWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {OperatorEnvironmentWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  scope "/", OperatorEnvironmentWeb do
    pipe_through :browser

    live "/", OperatorSandboxLive.Index, :index
  end
end
