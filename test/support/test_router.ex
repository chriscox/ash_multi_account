defmodule AshMultiAccount.Test.Router do
  @moduledoc false
  use Phoenix.Router
  use AshMultiAccount.Phoenix.Router

  import Phoenix.Controller, only: [fetch_flash: 2]

  pipeline :browser do
    plug :fetch_session
    plug :fetch_flash
    plug AshMultiAccount.Phoenix.Plug
  end

  scope "/" do
    pipe_through :browser
    multi_account_routes(AshMultiAccount.Test.Controller, AshMultiAccount.Test.User)
  end
end
