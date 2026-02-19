defmodule DemoWeb.Router do
  use DemoWeb, :router
  use AshAuthentication.Phoenix.Router
  use AshMultiAccount.Phoenix.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {DemoWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug AshMultiAccount.Phoenix.Plug
    plug :store_return_to
  end

  scope "/", DemoWeb do
    pipe_through :browser

    # AshAuthentication: sign-in/register LiveView + auth callbacks
    sign_in_route(
      register_path: "/register",
      reset_path: "/reset",
      auth_routes_prefix: "/auth",
      overrides: [DemoWeb.AuthOverrides, AshAuthentication.Phoenix.Overrides.DaisyUI]
    )

    auth_routes(AuthController, Demo.Accounts.User)

    # Sign out (manual route)
    get "/sign-out", AuthController, :sign_out

    # Multi-account: link and switch routes
    multi_account_routes(MultiAccountController, Demo.Accounts.User)

    # Main app routes with multi-account LiveView hook
    live_session :authenticated,
      on_mount: [
        {AshMultiAccount.Phoenix.LiveHook, {:load_multi_account, Demo.Accounts.User}}
      ] do
      live "/", HomeLive
    end
  end

  # Stores return_to query param in session so the auth controller
  # can redirect back after sign-in (needed for multi-account linking flow)
  defp store_return_to(%{query_params: %{"return_to" => "/" <> _ = return_to}} = conn, _opts) do
    # Only store relative paths (starting with /) to prevent open redirect.
    # Reject "//" which browsers interpret as protocol-relative URLs.
    if String.starts_with?(return_to, "//") do
      conn
    else
      Plug.Conn.put_session(conn, :return_to, return_to)
    end
  end

  defp store_return_to(conn, _opts), do: conn
end
