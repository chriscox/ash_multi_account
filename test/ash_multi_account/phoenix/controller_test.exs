defmodule AshMultiAccount.Phoenix.ControllerTest do
  use ExUnit.Case, async: false

  import Phoenix.ConnTest
  import Plug.Conn, only: [get_session: 2]

  alias AshMultiAccount.Test.LinkedAccount
  alias AshMultiAccount.Test.User

  @endpoint AshMultiAccount.Test.Endpoint

  setup do
    session_token = Ash.UUID.generate()

    primary_user =
      User
      |> Ash.Changeset.for_create(:create, %{name: "Primary", status: :active})
      |> Ash.create!()

    linked_user =
      User
      |> Ash.Changeset.for_create(:create, %{name: "Linked", status: :active})
      |> Ash.create!()

    %{
      session_token: session_token,
      primary_user: primary_user,
      linked_user: linked_user
    }
  end

  defp conn_with_user(user, opts \\ []) do
    build_conn()
    |> Plug.Test.init_test_session(%{
      "user" => "user?id=#{user.id}",
      "primary_user_id" => opts[:primary_user_id],
      "session_token" => opts[:session_token]
    })
    |> Plug.Conn.assign(:current_user, user)
  end

  defp create_link!(primary_user, linked_user, session_token) do
    LinkedAccount
    |> Ash.Changeset.for_create(
      :create_linked_account,
      %{linked_user_id: linked_user.id, session_token: session_token},
      actor: primary_user
    )
    |> Ash.create!()
  end

  defp flash(conn, key) do
    Phoenix.Flash.get(conn.assigns[:flash] || %{}, key)
  end

  describe "link_account/2" do
    test "redirects to sign-in when no user in session" do
      conn = build_conn() |> Plug.Test.init_test_session(%{})
      conn = get(conn, "/link/p/#{Ash.UUID.generate()}")

      assert redirected_to(conn) =~ "/sign-in"
    end

    test "sets up multi-account session when user links to self", %{
      primary_user: primary_user,
      session_token: session_token
    } do
      conn = conn_with_user(primary_user, session_token: session_token)
      conn = get(conn, "/link/p/#{primary_user.id}")

      assert redirected_to(conn) =~ "/sign-in"
      assert get_session(conn, "primary_user_id") == primary_user.id
      assert get_session(conn, "session_token") != nil
    end

    test "creates linked account for cross-user link", %{
      primary_user: primary_user,
      linked_user: linked_user,
      session_token: session_token
    } do
      conn =
        conn_with_user(linked_user,
          primary_user_id: primary_user.id,
          session_token: session_token
        )

      conn = get(conn, "/link/p/#{primary_user.id}")

      assert redirected_to(conn) == "/"
      assert flash(conn, :info) =~ "successfully linked"

      # Verify linked account was created
      accounts =
        LinkedAccount
        |> Ash.Query.for_read(:get_linked_accounts, %{
          primary_user_id: primary_user.id,
          session_token: session_token
        })
        |> Ash.read!()

      assert length(accounts) == 1
      assert hd(accounts).linked_user_id == linked_user.id
    end

    test "handles nonexistent primary user", %{
      linked_user: linked_user,
      session_token: session_token
    } do
      fake_id = Ash.UUID.generate()
      conn = conn_with_user(linked_user, session_token: session_token)
      conn = get(conn, "/link/p/#{fake_id}")

      assert redirected_to(conn) =~ "/sign-out"
      assert flash(conn, :error) =~ "could not be found"
    end

    test "handles missing session token on cross-user link", %{
      primary_user: primary_user,
      linked_user: linked_user
    } do
      conn = conn_with_user(linked_user)
      conn = get(conn, "/link/p/#{primary_user.id}")

      # Should set up session token and redirect back
      assert get_session(conn, "session_token") != nil
      assert get_session(conn, "primary_user_id") == primary_user.id
    end
  end

  describe "switch_to_account/2" do
    test "redirects when no user in session" do
      conn = build_conn() |> Plug.Test.init_test_session(%{})
      conn = get(conn, "/link/switch_to/#{Ash.UUID.generate()}")

      assert redirected_to(conn) =~ "/sign-out"
    end

    test "rejects switch when multi-account session keys are missing", %{
      primary_user: primary_user,
      linked_user: linked_user
    } do
      # User is authenticated but no primary_user_id/session_token in session
      conn = conn_with_user(primary_user)
      conn = get(conn, "/link/switch_to/#{linked_user.id}")

      assert redirected_to(conn) == "/"
      assert flash(conn, :error) =~ "Multi-account session not found"
    end

    test "switches to linked account", %{
      primary_user: primary_user,
      linked_user: linked_user,
      session_token: session_token
    } do
      create_link!(primary_user, linked_user, session_token)

      conn =
        conn_with_user(primary_user,
          primary_user_id: primary_user.id,
          session_token: session_token
        )

      conn = get(conn, "/link/switch_to/#{linked_user.id}")

      assert redirected_to(conn) == "/"
      assert get_session(conn, "user") == "user?id=#{linked_user.id}"
    end

    test "rejects switch to unauthorized user", %{
      primary_user: primary_user,
      session_token: session_token
    } do
      other_user =
        User
        |> Ash.Changeset.for_create(:create, %{name: "Other", status: :active})
        |> Ash.create!()

      conn =
        conn_with_user(primary_user,
          primary_user_id: primary_user.id,
          session_token: session_token
        )

      conn = get(conn, "/link/switch_to/#{other_user.id}")

      assert redirected_to(conn) == "/"
      assert flash(conn, :error) =~ "not authorized"
    end

    test "rejects switch to inactive user", %{
      primary_user: primary_user,
      session_token: session_token
    } do
      inactive_user =
        User
        |> Ash.Changeset.for_create(:create, %{name: "Inactive", status: :inactive})
        |> Ash.create!()

      create_link!(primary_user, inactive_user, session_token)

      conn =
        conn_with_user(primary_user,
          primary_user_id: primary_user.id,
          session_token: session_token
        )

      conn = get(conn, "/link/switch_to/#{inactive_user.id}")

      assert redirected_to(conn) == "/"
      assert flash(conn, :error) =~ "no longer active"
    end

    test "rejects switch to nonexistent user", %{
      primary_user: primary_user,
      session_token: session_token
    } do
      fake_id = Ash.UUID.generate()

      conn =
        conn_with_user(primary_user,
          primary_user_id: primary_user.id,
          session_token: session_token
        )

      conn = get(conn, "/link/switch_to/#{fake_id}")

      assert redirected_to(conn) == "/"
      assert flash(conn, :error) =~ "could not be found"
    end

    test "allows primary user to switch back to themselves", %{
      primary_user: primary_user,
      linked_user: linked_user,
      session_token: session_token
    } do
      create_link!(primary_user, linked_user, session_token)

      conn =
        conn_with_user(linked_user,
          primary_user_id: primary_user.id,
          session_token: session_token
        )

      conn = get(conn, "/link/switch_to/#{primary_user.id}")

      assert redirected_to(conn) == "/"
      assert get_session(conn, "user") == "user?id=#{primary_user.id}"
    end

    test "switch redirects to referer when present", %{
      primary_user: primary_user,
      linked_user: linked_user,
      session_token: session_token
    } do
      create_link!(primary_user, linked_user, session_token)

      conn =
        conn_with_user(primary_user,
          primary_user_id: primary_user.id,
          session_token: session_token
        )
        |> Plug.Conn.put_req_header("referer", "http://localhost:4000/controller")

      conn = get(conn, "/link/switch_to/#{linked_user.id}")

      assert redirected_to(conn) == "/controller"
    end

    test "switch preserves query string from referer", %{
      primary_user: primary_user,
      linked_user: linked_user,
      session_token: session_token
    } do
      create_link!(primary_user, linked_user, session_token)

      conn =
        conn_with_user(primary_user,
          primary_user_id: primary_user.id,
          session_token: session_token
        )
        |> Plug.Conn.put_req_header("referer", "http://localhost:4000/page?tab=settings")

      conn = get(conn, "/link/switch_to/#{linked_user.id}")

      assert redirected_to(conn) == "/page?tab=settings"
    end
  end

  describe "origin_path/1" do
    test "extracts path from valid referer" do
      conn =
        build_conn()
        |> Plug.Conn.put_req_header("referer", "http://localhost:4000/dashboard")

      assert AshMultiAccount.Phoenix.Controller.origin_path(conn) == "/dashboard"
    end

    test "includes query string from referer" do
      conn =
        build_conn()
        |> Plug.Conn.put_req_header(
          "referer",
          "http://localhost:4000/page?tab=settings&view=grid"
        )

      assert AshMultiAccount.Phoenix.Controller.origin_path(conn) ==
               "/page?tab=settings&view=grid"
    end

    test "returns nil when no referer header" do
      conn = build_conn()
      assert AshMultiAccount.Phoenix.Controller.origin_path(conn) == nil
    end

    test "rejects protocol-relative paths (open redirect prevention)" do
      conn =
        build_conn()
        |> Plug.Conn.put_req_header("referer", "http://localhost:4000//evil.com")

      assert AshMultiAccount.Phoenix.Controller.origin_path(conn) == nil
    end

    test "returns nil for referer without path" do
      conn =
        build_conn()
        |> Plug.Conn.put_req_header("referer", "not-a-url")

      assert AshMultiAccount.Phoenix.Controller.origin_path(conn) == nil
    end
  end
end
