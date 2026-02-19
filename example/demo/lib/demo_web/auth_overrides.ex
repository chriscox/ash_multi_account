defmodule DemoWeb.AuthOverrides do
  @moduledoc false
  use AshAuthentication.Phoenix.Overrides

  override AshAuthentication.Phoenix.SignInLive do
    set :root_class, "grid min-h-screen place-items-center bg-base-200 py-12 px-4"
  end

  override AshAuthentication.Phoenix.Components.SignIn do
    set :root_class, "w-full max-w-md mx-auto card bg-base-100 shadow-sm p-8"
    set :strategy_class, "w-full"
    set :show_banner, false
  end
end
