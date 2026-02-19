defmodule AshMultiAccount.Phoenix.Plug do
  @moduledoc """
  A plug that ensures a `"session_token"` UUID exists in the session.

  The session token is used by the multi-account linking flow. Adding this
  plug ensures a token exists before the user reaches any multi-account
  routes, avoiding fallback token generation in the controller.

      plug AshMultiAccount.Phoenix.Plug
  """

  @behaviour Plug

  alias AshMultiAccount.Phoenix.Session

  @impl true
  @spec init(Plug.opts()) :: Plug.opts()
  def init(opts), do: opts

  @impl true
  @spec call(Plug.Conn.t(), Plug.opts()) :: Plug.Conn.t()
  def call(conn, _opts) do
    case Session.get_session_token(conn) do
      nil -> Session.put_session_token(conn, Ash.UUID.generate())
      _existing -> conn
    end
  end
end
