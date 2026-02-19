defmodule DemoWeb.MultiAccountController do
  use DemoWeb, :controller
  use AshMultiAccount.Phoenix.Controller, user_resource: Demo.Accounts.User

  def after_link_path(_conn), do: ~p"/"
  def after_switch_path(_conn), do: ~p"/"
  def sign_in_path(_conn, primary_user_id), do: ~p"/sign-in?return_to=/link/p/#{primary_user_id}"
  def sign_out_path(_conn), do: ~p"/sign-out"
end
