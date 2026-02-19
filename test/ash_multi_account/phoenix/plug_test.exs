defmodule AshMultiAccount.Phoenix.PlugTest do
  use ExUnit.Case, async: true

  alias AshMultiAccount.Phoenix.Plug, as: SessionPlug

  defp build_conn do
    :get
    |> Plug.Test.conn("/")
    |> Plug.Test.init_test_session(%{})
  end

  describe "call/2" do
    test "generates a session_token when none exists" do
      opts = SessionPlug.init([])
      conn = SessionPlug.call(build_conn(), opts)

      token = Plug.Conn.get_session(conn, "session_token")
      assert is_binary(token)
      assert String.length(token) > 0
    end

    test "preserves existing session_token" do
      opts = SessionPlug.init([])

      conn =
        build_conn()
        |> Plug.Conn.put_session("session_token", "existing-token")
        |> SessionPlug.call(opts)

      assert Plug.Conn.get_session(conn, "session_token") == "existing-token"
    end

    test "generated token is a valid UUID format" do
      opts = SessionPlug.init([])
      conn = SessionPlug.call(build_conn(), opts)

      token = Plug.Conn.get_session(conn, "session_token")
      # UUID format: 8-4-4-4-12 hex chars
      assert Regex.match?(
               ~r/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/,
               token
             )
    end
  end
end
