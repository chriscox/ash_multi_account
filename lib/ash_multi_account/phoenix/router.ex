defmodule AshMultiAccount.Phoenix.Router do
  @moduledoc """
  Provides the `multi_account_routes/3` macro for generating multi-account routes.

  ## Usage

      defmodule MyAppWeb.Router do
        use Phoenix.Router
        use AshMultiAccount.Phoenix.Router

        scope "/", MyAppWeb do
          pipe_through :browser
          multi_account_routes MultiAccountController, MyApp.Accounts.User
        end
      end

  This generates:

      get "/link/p/:primary_user_id", MultiAccountController, :link_account
      get "/link/switch_to/:user_id", MultiAccountController, :switch_to_account

  ## Custom Paths

      multi_account_routes MyController, MyUser,
        link_path: "/accounts/link/:primary_user_id",
        switch_path: "/accounts/switch/:user_id"
  """

  defmacro __using__(_opts) do
    quote do
      import AshMultiAccount.Phoenix.Router,
        only: [multi_account_routes: 2, multi_account_routes: 3]
    end
  end

  @doc """
  Generates routes for multi-account link and switch actions.
  """
  # user_resource is accepted for API consistency with Controller's use-site
  # but currently unused. Reserved for future route-level resource validation.
  defmacro multi_account_routes(controller, _user_resource, opts \\ []) do
    link_path = Keyword.get(opts, :link_path, "/link/p/:primary_user_id")
    switch_path = Keyword.get(opts, :switch_path, "/link/switch_to/:user_id")

    quote do
      get unquote(link_path), unquote(controller), :link_account
      get unquote(switch_path), unquote(controller), :switch_to_account
    end
  end
end
