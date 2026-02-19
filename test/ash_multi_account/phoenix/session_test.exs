defmodule AshMultiAccount.Phoenix.SessionTest do
  use ExUnit.Case, async: true

  alias AshMultiAccount.Phoenix.Session

  defp build_conn do
    :get
    |> Plug.Test.conn("/")
    |> Plug.Test.init_test_session(%{})
  end

  describe "get_user_id/1" do
    test "parses user ID from conn session" do
      conn = build_conn() |> Plug.Conn.put_session("user", "user?id=abc-123")
      assert Session.get_user_id(conn) == "abc-123"
    end

    test "parses user ID from raw session map" do
      session = %{"user" => "user?id=abc-123"}
      assert Session.get_user_id(session) == "abc-123"
    end

    test "returns nil when no user in session" do
      assert Session.get_user_id(build_conn()) == nil
      assert Session.get_user_id(%{}) == nil
    end

    test "returns nil for malformed subject" do
      conn = build_conn() |> Plug.Conn.put_session("user", "garbage")
      assert Session.get_user_id(conn) == nil
    end

    test "handles different short names" do
      session = %{"user" => "admin?id=xyz-789"}
      assert Session.get_user_id(session) == "xyz-789"
    end

    test "returns nil for empty id" do
      session = %{"user" => "user?id="}
      assert Session.get_user_id(session) == nil
    end

    test "returns nil for empty string subject" do
      session = %{"user" => ""}
      assert Session.get_user_id(session) == nil
    end
  end

  describe "put_user_id/2" do
    test "writes user subject to session" do
      conn = build_conn() |> Session.put_user_id("abc-123")
      assert Plug.Conn.get_session(conn, "user") == "user?id=abc-123"
    end

    test "writes user subject with custom short_name" do
      conn = build_conn() |> Session.put_user_id("abc-123", "admin")
      assert Plug.Conn.get_session(conn, "user") == "admin?id=abc-123"
    end
  end

  describe "get_primary_user_id/1" do
    test "reads from conn" do
      conn = build_conn() |> Plug.Conn.put_session("primary_user_id", "p-123")
      assert Session.get_primary_user_id(conn) == "p-123"
    end

    test "reads from session map" do
      assert Session.get_primary_user_id(%{"primary_user_id" => "p-123"}) == "p-123"
    end

    test "returns nil when absent" do
      assert Session.get_primary_user_id(build_conn()) == nil
      assert Session.get_primary_user_id(%{}) == nil
    end
  end

  describe "put_primary_user_id/2" do
    test "writes to session" do
      conn = build_conn() |> Session.put_primary_user_id("p-123")
      assert Plug.Conn.get_session(conn, "primary_user_id") == "p-123"
    end
  end

  describe "get_session_token/1" do
    test "reads from conn" do
      conn = build_conn() |> Plug.Conn.put_session("session_token", "tok-1")
      assert Session.get_session_token(conn) == "tok-1"
    end

    test "reads from session map" do
      assert Session.get_session_token(%{"session_token" => "tok-1"}) == "tok-1"
    end

    test "returns nil when absent" do
      assert Session.get_session_token(build_conn()) == nil
      assert Session.get_session_token(%{}) == nil
    end
  end

  describe "put_session_token/2" do
    test "writes to session" do
      conn = build_conn() |> Session.put_session_token("tok-1")
      assert Plug.Conn.get_session(conn, "session_token") == "tok-1"
    end
  end

  describe "put_multi_account_session/3" do
    test "sets both keys atomically" do
      conn = build_conn() |> Session.put_multi_account_session("p-123", "tok-1")
      assert Plug.Conn.get_session(conn, "primary_user_id") == "p-123"
      assert Plug.Conn.get_session(conn, "session_token") == "tok-1"
    end
  end

  describe "multi_account_session?/1" do
    test "true when both keys present in conn" do
      conn =
        build_conn()
        |> Plug.Conn.put_session("primary_user_id", "p-123")
        |> Plug.Conn.put_session("session_token", "tok-1")

      assert Session.multi_account_session?(conn)
    end

    test "false when only primary_user_id present" do
      conn = build_conn() |> Plug.Conn.put_session("primary_user_id", "p-123")
      refute Session.multi_account_session?(conn)
    end

    test "false when only session_token present" do
      conn = build_conn() |> Plug.Conn.put_session("session_token", "tok-1")
      refute Session.multi_account_session?(conn)
    end

    test "works with session map" do
      assert Session.multi_account_session?(%{
               "primary_user_id" => "p-123",
               "session_token" => "tok-1"
             })

      refute Session.multi_account_session?(%{"primary_user_id" => "p-123"})
      refute Session.multi_account_session?(%{})
    end
  end

  describe "clear_multi_account_session/1" do
    test "removes both keys" do
      conn =
        build_conn()
        |> Plug.Conn.put_session("primary_user_id", "p-123")
        |> Plug.Conn.put_session("session_token", "tok-1")
        |> Plug.Conn.put_session("user", "user?id=abc")
        |> Session.clear_multi_account_session()

      refute Session.multi_account_session?(conn)
      # user key is preserved
      assert Plug.Conn.get_session(conn, "user") == "user?id=abc"
    end
  end
end
