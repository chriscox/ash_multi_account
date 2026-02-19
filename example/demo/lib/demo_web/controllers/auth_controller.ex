defmodule DemoWeb.AuthController do
  use DemoWeb, :controller
  use AshAuthentication.Phoenix.Controller

  def success(conn, _activity, user, _token) do
    return_to = get_session(conn, :return_to) || ~p"/"

    conn
    |> delete_session(:return_to)
    |> store_in_session(user)
    |> AshMultiAccount.Phoenix.Session.put_user_id(user.id)
    |> assign(:current_user, user)
    |> redirect(to: return_to)
  end

  def failure(conn, activity, reason) do
    require Logger
    Logger.warning("Authentication failure for #{inspect(activity)}: #{inspect(reason)}")

    conn
    |> put_flash(:error, "Incorrect email or password")
    |> redirect(to: ~p"/sign-in")
  end

  def sign_out(conn, _params) do
    conn
    |> clear_session(:demo)
    |> redirect(to: ~p"/")
  end
end
