defmodule PhoenixVueWeb.PageController do
  use PhoenixVueWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
