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

  # Auth pipelines are inserted above the next line by `mix phoenix_vue.gen.auth`.
  # phoenix_vue:gen.auth:pipelines_anchor

  # API scopes are inserted above the next line by `mix phoenix_vue.gen.auth`.
  # Declare additional scopes ABOVE that anchor so they match before the SPA
  # catch-all at the bottom of this file.
  # phoenix_vue:gen.auth:scopes_anchor

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
