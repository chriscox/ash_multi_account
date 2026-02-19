defmodule AshMultiAccount.Phoenix.Session do
  @moduledoc """
  Session read/write helpers for multi-account functionality.

  Provides functions that work with both `Plug.Conn` (controllers) and
  raw session maps (LiveView hooks) for reading session values, and
  `Plug.Conn` only for writing.

  ## Session Keys

  - `"user"` — AshAuthentication subject string, format `"<short_name>?id=<UUID>"`
  - `"primary_user_id"` — UUID of the primary account owner
  - `"session_token"` — UUID tying linked accounts to a browser session
  """

  import Plug.Conn, only: [get_session: 2, put_session: 3, delete_session: 2]

  @type conn_or_session :: Plug.Conn.t() | %{optional(String.t()) => term()}

  @doc """
  Parses the user ID from the session `"user"` key.

  The session stores the user subject as `"<short_name>?id=<UUID>"` (matching
  AshAuthentication's subject format). This extracts just the UUID.

  Accepts either a `Plug.Conn` or a raw session map.

  Returns the UUID string or `nil`.
  """
  @spec get_user_id(conn_or_session()) :: String.t() | nil
  def get_user_id(%Plug.Conn{} = conn) do
    conn |> get_session("user") |> parse_user_subject()
  end

  def get_user_id(%{} = session) do
    session |> Map.get("user") |> parse_user_subject()
  end

  @doc """
  Writes the user subject to the session `"user"` key.

  Constructs the subject string from the given `user_id` using the format
  `"<short_name>?id=<UUID>"`. The `short_name` parameter defaults to `"user"`,
  matching the typical Ash resource short name for User resources. If your
  resource uses a different `short_name`, pass it explicitly.

  Only works with `Plug.Conn`.
  """
  @spec put_user_id(Plug.Conn.t(), String.t(), String.t()) :: Plug.Conn.t()
  def put_user_id(%Plug.Conn{} = conn, user_id, short_name \\ "user") do
    put_session(conn, "user", "#{short_name}?id=#{user_id}")
  end

  @doc """
  Reads the `"primary_user_id"` from the session.

  Accepts either a `Plug.Conn` or a raw session map.
  """
  @spec get_primary_user_id(conn_or_session()) :: String.t() | nil
  def get_primary_user_id(%Plug.Conn{} = conn) do
    get_session(conn, "primary_user_id")
  end

  def get_primary_user_id(%{} = session) do
    Map.get(session, "primary_user_id")
  end

  @doc """
  Writes `"primary_user_id"` to the session.
  """
  @spec put_primary_user_id(Plug.Conn.t(), String.t()) :: Plug.Conn.t()
  def put_primary_user_id(%Plug.Conn{} = conn, user_id) do
    put_session(conn, "primary_user_id", user_id)
  end

  @doc """
  Reads the `"session_token"` from the session.

  Accepts either a `Plug.Conn` or a raw session map.
  """
  @spec get_session_token(conn_or_session()) :: String.t() | nil
  def get_session_token(%Plug.Conn{} = conn) do
    get_session(conn, "session_token")
  end

  def get_session_token(%{} = session) do
    Map.get(session, "session_token")
  end

  @doc """
  Writes `"session_token"` to the session.
  """
  @spec put_session_token(Plug.Conn.t(), String.t()) :: Plug.Conn.t()
  def put_session_token(%Plug.Conn{} = conn, token) do
    put_session(conn, "session_token", token)
  end

  @doc """
  Sets both `"primary_user_id"` and `"session_token"` atomically.

  These two keys must always be set together to establish a valid
  multi-account session.
  """
  @spec put_multi_account_session(Plug.Conn.t(), String.t(), String.t()) :: Plug.Conn.t()
  def put_multi_account_session(%Plug.Conn{} = conn, primary_user_id, session_token) do
    conn
    |> put_primary_user_id(primary_user_id)
    |> put_session_token(session_token)
  end

  @doc """
  Returns `true` if the session has both `"primary_user_id"` and `"session_token"` set.

  Accepts either a `Plug.Conn` or a raw session map.
  """
  @spec multi_account_session?(conn_or_session()) :: boolean()
  def multi_account_session?(conn_or_session) do
    get_primary_user_id(conn_or_session) != nil and get_session_token(conn_or_session) != nil
  end

  @doc """
  Clears multi-account session keys (`"primary_user_id"` and `"session_token"`).

  Does **not** clear the `"user"` key.

  Only works with `Plug.Conn`.
  """
  @spec clear_multi_account_session(Plug.Conn.t()) :: Plug.Conn.t()
  def clear_multi_account_session(%Plug.Conn{} = conn) do
    conn
    |> delete_session("primary_user_id")
    |> delete_session("session_token")
  end

  defp parse_user_subject(nil), do: nil
  defp parse_user_subject(""), do: nil

  defp parse_user_subject(subject) when is_binary(subject) do
    case String.split(subject, "?id=", parts: 2) do
      [_short_name, id] when id != "" -> id
      _ -> nil
    end
  end

  defp parse_user_subject(other) do
    require Logger
    Logger.warning("AshMultiAccount: Unexpected session user subject: #{inspect(other)}")
    nil
  end
end
