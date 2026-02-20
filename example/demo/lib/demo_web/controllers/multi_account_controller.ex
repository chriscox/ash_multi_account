defmodule DemoWeb.MultiAccountController do
  use DemoWeb, :controller
  use AshMultiAccount.Phoenix.Controller, user_resource: Demo.Accounts.User

  def sign_in_path(_conn, primary_user_id), do: ~p"/sign-in?return_to=/link/p/#{primary_user_id}"
  def sign_out_path(_conn), do: ~p"/sign-out"
end
