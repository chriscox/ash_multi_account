defmodule AshMultiAccount.Test.Endpoint do
  @moduledoc false
  use Phoenix.Endpoint, otp_app: :ash_multi_account

  @session_options [
    store: :cookie,
    key: "_ash_multi_account_test_key",
    signing_salt: "test_signing_salt",
    secret_key_base: String.duplicate("a", 64)
  ]

  plug Plug.Session, @session_options

  plug AshMultiAccount.Test.Router
end
