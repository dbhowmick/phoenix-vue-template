defmodule PhoenixVue.Repo do
  use Ecto.Repo,
    otp_app: :phoenix_vue_template,
    adapter: Ecto.Adapters.Postgres
end
