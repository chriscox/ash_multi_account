defmodule AshMultiAccount.Phoenix.LoadMultiAccountTest do
  use ExUnit.Case, async: false

  alias AshMultiAccount.Phoenix.LoadMultiAccount
  alias AshMultiAccount.Test.LinkedAccount
  alias AshMultiAccount.Test.User

  defp build_conn(session \\ %{}) do
    :get
    |> Plug.Test.conn("/")
    |> Plug.Test.init_test_session(session)
  end

  defp init_opts do
    LoadMultiAccount.init(user_resource: User)
  end

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

  describe "init/1" do
    test "raises without :user_resource" do
      assert_raise ArgumentError, ~r/requires the :user_resource option/, fn ->
        LoadMultiAccount.init([])
      end
    end

    test "passes through opts with :user_resource" do
      opts = LoadMultiAccount.init(user_resource: User)
      assert Keyword.get(opts, :user_resource) == User
    end
  end

  describe "call/2 - standard mode" do
    test "assigns current_user from session when not in assigns", %{primary_user: user} do
      conn =
        %{"user" => "user?id=#{user.id}"}
        |> build_conn()
        |> LoadMultiAccount.call(init_opts())

      assert conn.assigns.current_user.id == user.id
      assert conn.assigns.primary_user == nil
    end

    test "preserves existing conn.assigns[:current_user]", %{primary_user: user} do
      conn =
        %{"user" => "user?id=#{user.id}"}
        |> build_conn()
        |> Plug.Conn.assign(:current_user, user)
        |> LoadMultiAccount.call(init_opts())

      assert conn.assigns.current_user.id == user.id
      assert conn.assigns.primary_user == nil
    end

    test "loads display fields", %{primary_user: user} do
      conn =
        %{"user" => "user?id=#{user.id}"}
        |> build_conn()
        |> LoadMultiAccount.call(init_opts())

      # display_fields includes :name for test User
      assert conn.assigns.current_user.name == "Primary"
    end

    test "assigns nil when no session data" do
      conn =
        build_conn()
        |> LoadMultiAccount.call(init_opts())

      assert conn.assigns.current_user == nil
      assert conn.assigns.primary_user == nil
    end
  end

  describe "call/2 - multi-account mode" do
    test "loads both users correctly", %{
      primary_user: primary_user,
      linked_user: linked_user,
      session_token: session_token
    } do
      LinkedAccount
      |> Ash.Changeset.for_create(
        :create_linked_account,
        %{linked_user_id: linked_user.id, session_token: session_token},
        actor: primary_user
      )
      |> Ash.create!()

      conn =
        %{
          "user" => "user?id=#{primary_user.id}",
          "primary_user_id" => primary_user.id,
          "session_token" => session_token
        }
        |> build_conn()
        |> LoadMultiAccount.call(init_opts())

      assert conn.assigns.current_user.id == primary_user.id
      assert conn.assigns.primary_user.id == primary_user.id
    end

    test "resolves current user from session (overrides existing assign)", %{
      primary_user: primary_user,
      linked_user: linked_user,
      session_token: session_token
    } do
      LinkedAccount
      |> Ash.Changeset.for_create(
        :create_linked_account,
        %{linked_user_id: linked_user.id, session_token: session_token},
        actor: primary_user
      )
      |> Ash.create!()

      # Session says linked_user, conn assigns say primary_user (simulating JWT)
      conn =
        %{
          "user" => "user?id=#{linked_user.id}",
          "primary_user_id" => primary_user.id,
          "session_token" => session_token
        }
        |> build_conn()
        |> Plug.Conn.assign(:current_user, primary_user)
        |> LoadMultiAccount.call(init_opts())

      # Should use session user (linked_user), not JWT user (primary_user)
      assert conn.assigns.current_user.id == linked_user.id
      assert conn.assigns.primary_user.id == primary_user.id
    end

    test "inactive primary clears multi-account session and falls back to standard mode", %{
      linked_user: linked_user,
      session_token: session_token
    } do
      inactive_primary =
        User
        |> Ash.Changeset.for_create(:create, %{name: "Inactive Primary", status: :inactive})
        |> Ash.create!()

      LinkedAccount
      |> Ash.Changeset.for_create(
        :create_linked_account,
        %{linked_user_id: linked_user.id, session_token: session_token},
        actor: inactive_primary
      )
      |> Ash.create!()

      conn =
        %{
          "user" => "user?id=#{inactive_primary.id}",
          "primary_user_id" => inactive_primary.id,
          "session_token" => session_token
        }
        |> build_conn()
        |> LoadMultiAccount.call(init_opts())

      # Falls back to standard mode: loads user from session, clears multi-account keys
      assert conn.assigns.current_user.id == inactive_primary.id
      assert conn.assigns.primary_user == nil
    end

    test "missing primary clears stale session and falls back to standard mode", %{
      session_token: session_token
    } do
      fake_id = Ash.UUID.generate()

      conn =
        %{
          "user" => "user?id=#{fake_id}",
          "primary_user_id" => fake_id,
          "session_token" => session_token
        }
        |> build_conn()
        |> LoadMultiAccount.call(init_opts())

      assert conn.assigns.current_user == nil
      assert conn.assigns.primary_user == nil
    end
  end
end
