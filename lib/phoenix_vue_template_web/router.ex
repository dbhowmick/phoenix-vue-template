defmodule PhoenixVueWeb.Router do
  use PhoenixVueWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug PhoenixVueWeb.Plugs.AssignRequestHost
    plug :fetch_live_flash
    plug :put_root_layout, html: {PhoenixVueWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  # Other scopes may use custom stacks. Declare API routes here so they match
  # before the SPA catch-all below.
  # scope "/api", PhoenixVueWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development.
  # Declared BEFORE the SPA catch-all so /dev/* routes match first.
  if Application.compile_env(:phoenix_vue_template, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: PhoenixVueWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  # SPA fallback — every browser route renders the same shell so vue-router
  # survives refreshes on deep links. Declared LAST.
  scope "/", PhoenixVueWeb do
    pipe_through :browser

    get "/*path", PageController, :home
  end
end
