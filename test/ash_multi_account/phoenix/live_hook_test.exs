defmodule AshMultiAccount.Phoenix.LiveHookTest do
  use ExUnit.Case, async: false

  alias AshMultiAccount.Phoenix.LiveHook
  alias AshMultiAccount.Test.LinkedAccount
  alias AshMultiAccount.Test.User

  defp build_socket(assigns \\ %{}) do
    %Phoenix.LiveView.Socket{
      assigns: Map.merge(%{__changed__: %{}, flash: %{}}, assigns)
    }
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

  describe "on_mount {:load_multi_account, user_resource} - standard mode" do
    test "assigns current_user from socket assigns when no multi-account session", %{
      primary_user: user
    } do
      session = %{"user" => "user?id=#{user.id}"}
      socket = build_socket(%{current_user: user})

      {:cont, socket} =
        LiveHook.on_mount({:load_multi_account, User}, %{}, session, socket)

      assert socket.assigns.current_user.id == user.id
      assert socket.assigns.primary_user == nil
    end

    test "loads user from session when not in assigns" do
      user =
        User
        |> Ash.Changeset.for_create(:create, %{name: "SessionUser", status: :active})
        |> Ash.create!()

      session = %{"user" => "user?id=#{user.id}"}
      socket = build_socket()

      {:cont, socket} =
        LiveHook.on_mount({:load_multi_account, User}, %{}, session, socket)

      assert socket.assigns.current_user.id == user.id
      assert socket.assigns.primary_user == nil
    end

    test "assigns nil current_user when no session data" do
      session = %{}
      socket = build_socket()

      {:cont, socket} =
        LiveHook.on_mount({:load_multi_account, User}, %{}, session, socket)

      assert socket.assigns.current_user == nil
      assert socket.assigns.primary_user == nil
    end
  end

  describe "on_mount {:load_multi_account, user_resource} - multi-account mode" do
    test "loads primary user and linked accounts", %{
      primary_user: primary_user,
      linked_user: linked_user,
      session_token: session_token
    } do
      # Create link
      LinkedAccount
      |> Ash.Changeset.for_create(
        :create_linked_account,
        %{linked_user_id: linked_user.id, session_token: session_token},
        actor: primary_user
      )
      |> Ash.create!()

      session = %{
        "user" => "user?id=#{primary_user.id}",
        "primary_user_id" => primary_user.id,
        "session_token" => session_token
      }

      socket = build_socket(%{current_user: primary_user})

      {:cont, socket} =
        LiveHook.on_mount({:load_multi_account, User}, %{}, session, socket)

      assert socket.assigns.current_user.id == primary_user.id
      assert socket.assigns.primary_user.id == primary_user.id
    end

    test "resolves current user from session (override JWT)", %{
      primary_user: primary_user,
      linked_user: linked_user,
      session_token: session_token
    } do
      # Create link
      LinkedAccount
      |> Ash.Changeset.for_create(
        :create_linked_account,
        %{linked_user_id: linked_user.id, session_token: session_token},
        actor: primary_user
      )
      |> Ash.create!()

      # Session says linked_user, socket assigns say primary_user (simulating JWT)
      session = %{
        "user" => "user?id=#{linked_user.id}",
        "primary_user_id" => primary_user.id,
        "session_token" => session_token
      }

      socket = build_socket(%{current_user: primary_user})

      {:cont, socket} =
        LiveHook.on_mount({:load_multi_account, User}, %{}, session, socket)

      # Should use session user (linked_user), not JWT user (primary_user)
      assert socket.assigns.current_user.id == linked_user.id
      assert socket.assigns.primary_user.id == primary_user.id
    end

    test "halts when primary user is not active", %{
      linked_user: linked_user,
      session_token: session_token
    } do
      inactive_primary =
        User
        |> Ash.Changeset.for_create(:create, %{name: "Inactive Primary", status: :inactive})
        |> Ash.create!()

      # Create link
      LinkedAccount
      |> Ash.Changeset.for_create(
        :create_linked_account,
        %{linked_user_id: linked_user.id, session_token: session_token},
        actor: inactive_primary
      )
      |> Ash.create!()

      session = %{
        "user" => "user?id=#{inactive_primary.id}",
        "primary_user_id" => inactive_primary.id,
        "session_token" => session_token
      }

      socket = build_socket(%{current_user: inactive_primary})

      {:halt, socket} =
        LiveHook.on_mount({:load_multi_account, User}, %{}, session, socket)

      assert {:redirect, %{to: "/sign-out"}} = socket.redirected
    end

    test "halts with custom sign_out_path when primary user is not active", %{
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

      session = %{
        "user" => "user?id=#{inactive_primary.id}",
        "primary_user_id" => inactive_primary.id,
        "session_token" => session_token
      }

      socket = build_socket(%{current_user: inactive_primary})

      {:halt, socket} =
        LiveHook.on_mount(
          {:load_multi_account, User, sign_out_path: "/custom-logout"},
          %{},
          session,
          socket
        )

      assert {:redirect, %{to: "/custom-logout"}} = socket.redirected
    end

    test "falls back to standard mode when primary user not found", %{
      session_token: session_token
    } do
      fake_id = Ash.UUID.generate()

      session = %{
        "user" => "user?id=#{fake_id}",
        "primary_user_id" => fake_id,
        "session_token" => session_token
      }

      socket = build_socket()

      # Falls back to standard mode: session user also not found, so nil assigns
      {:cont, socket} =
        LiveHook.on_mount({:load_multi_account, User}, %{}, session, socket)

      assert socket.assigns.current_user == nil
      assert socket.assigns.primary_user == nil
    end
  end
end
