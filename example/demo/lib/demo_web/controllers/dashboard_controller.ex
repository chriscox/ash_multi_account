defmodule DemoWeb.DashboardController do
  use DemoWeb, :controller

  def show(conn, _params) do
    render(conn, :dashboard,
      current_user: conn.assigns[:current_user],
      primary_user: conn.assigns[:primary_user]
    )
  end
end
