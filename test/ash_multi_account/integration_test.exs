defmodule AshMultiAccount.IntegrationTest do
  use ExUnit.Case, async: true

  alias AshMultiAccount.Test.LinkedAccount
  alias AshMultiAccount.Test.User

  setup do
    session_token = Ash.UUID.generate()

    primary_user =
      User
      |> Ash.Changeset.for_create(:create, %{name: "Primary User"})
      |> Ash.create!()

    linked_user =
      User
      |> Ash.Changeset.for_create(:create, %{name: "Linked User"})
      |> Ash.create!()

    %{
      session_token: session_token,
      primary_user: primary_user,
      linked_user: linked_user
    }
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

  describe "create linked account" do
    test "creates a linked account", %{
      session_token: session_token,
      primary_user: primary_user,
      linked_user: linked_user
    } do
      linked_account = create_link!(primary_user, linked_user, session_token)

      assert linked_account.primary_user_id == primary_user.id
      assert linked_account.linked_user_id == linked_user.id
      assert linked_account.session_token == session_token
      assert linked_account.status == :active
    end
  end

  describe "self-linking prevention" do
    test "prevents a user from linking to themselves", %{
      session_token: session_token,
      primary_user: primary_user
    } do
      assert_raise Ash.Error.Invalid, ~r/cannot link a user to themselves/, fn ->
        create_link!(primary_user, primary_user, session_token)
      end
    end
  end

  describe "get_linked_accounts" do
    test "returns linked accounts for a session", %{
      session_token: session_token,
      primary_user: primary_user,
      linked_user: linked_user
    } do
      create_link!(primary_user, linked_user, session_token)

      results =
        LinkedAccount
        |> Ash.Query.for_read(:get_linked_accounts, %{
          primary_user_id: primary_user.id,
          session_token: session_token
        })
        |> Ash.read!()

      assert length(results) == 1
      [result] = results
      assert result.primary_user_id == primary_user.id
      assert result.linked_user_id == linked_user.id
    end

    test "does not return inactive linked accounts", %{
      session_token: session_token,
      primary_user: primary_user,
      linked_user: linked_user
    } do
      linked_account = create_link!(primary_user, linked_user, session_token)

      # Deactivate the linked account
      linked_account
      |> Ash.Changeset.for_update(:deactivate, %{id: linked_account.id})
      |> Ash.update!()

      results =
        LinkedAccount
        |> Ash.Query.for_read(:get_linked_accounts, %{
          primary_user_id: primary_user.id,
          session_token: session_token
        })
        |> Ash.read!()

      assert results == []
    end
  end

  describe "session isolation" do
    test "linked accounts from one session are not visible in another", %{
      primary_user: primary_user,
      linked_user: linked_user
    } do
      session_a = Ash.UUID.generate()
      session_b = Ash.UUID.generate()

      create_link!(primary_user, linked_user, session_a)

      # Query with session B should return empty
      results_b =
        LinkedAccount
        |> Ash.Query.for_read(:get_linked_accounts, %{
          primary_user_id: primary_user.id,
          session_token: session_b
        })
        |> Ash.read!()

      assert results_b == []

      # Query with session A should return the linked account
      results_a =
        LinkedAccount
        |> Ash.Query.for_read(:get_linked_accounts, %{
          primary_user_id: primary_user.id,
          session_token: session_a
        })
        |> Ash.read!()

      assert length(results_a) == 1
    end
  end

  describe "activate/deactivate" do
    test "deactivates and reactivates a linked account", %{
      session_token: session_token,
      primary_user: primary_user,
      linked_user: linked_user
    } do
      linked_account = create_link!(primary_user, linked_user, session_token)
      assert linked_account.status == :active

      # Deactivate
      deactivated =
        linked_account
        |> Ash.Changeset.for_update(:deactivate, %{id: linked_account.id})
        |> Ash.update!()

      assert deactivated.status == :inactive

      # Reactivate
      reactivated =
        deactivated
        |> Ash.Changeset.for_update(:activate, %{id: deactivated.id})
        |> Ash.update!()

      assert reactivated.status == :active
    end
  end

  describe "is_active? calculation" do
    test "returns true for active linked accounts", %{
      session_token: session_token,
      primary_user: primary_user,
      linked_user: linked_user
    } do
      linked_account = create_link!(primary_user, linked_user, session_token)

      loaded = Ash.load!(linked_account, :is_active?)
      assert loaded.is_active? == true
    end

    test "returns false for inactive linked accounts", %{
      session_token: session_token,
      primary_user: primary_user,
      linked_user: linked_user
    } do
      linked_account = create_link!(primary_user, linked_user, session_token)

      deactivated =
        linked_account
        |> Ash.Changeset.for_update(:deactivate, %{id: linked_account.id})
        |> Ash.update!()

      loaded = Ash.load!(deactivated, :is_active?)
      assert loaded.is_active? == false
    end
  end

  describe "max_linked_accounts" do
    test "enforces max linked accounts limit", %{
      session_token: session_token,
      primary_user: primary_user
    } do
      # max_linked_accounts is set to 3 in test_user.ex
      # Create 3 linked accounts (should succeed)
      for i <- 1..3 do
        user =
          User
          |> Ash.Changeset.for_create(:create, %{name: "User #{i}"})
          |> Ash.create!()

        create_link!(primary_user, user, session_token)
      end

      # 4th should fail
      extra_user =
        User
        |> Ash.Changeset.for_create(:create, %{name: "Extra User"})
        |> Ash.create!()

      assert_raise Ash.Error.Invalid, ~r/maximum of 3 linked accounts exceeded/, fn ->
        create_link!(primary_user, extra_user, session_token)
      end
    end

    test "deactivated accounts do not count toward the limit", %{
      session_token: session_token,
      primary_user: primary_user
    } do
      # max_linked_accounts is set to 3 in test_user.ex
      users =
        for i <- 1..3 do
          User
          |> Ash.Changeset.for_create(:create, %{name: "User #{i}"})
          |> Ash.create!()
        end

      linked_accounts = Enum.map(users, &create_link!(primary_user, &1, session_token))

      # Deactivate one — only 2 active remain
      first = hd(linked_accounts)

      first
      |> Ash.Changeset.for_update(:deactivate, %{id: first.id})
      |> Ash.update!()

      # 4th should succeed since only 2 are active
      extra_user =
        User
        |> Ash.Changeset.for_create(:create, %{name: "Extra User"})
        |> Ash.create!()

      linked_account = create_link!(primary_user, extra_user, session_token)
      assert linked_account.status == :active
    end
  end

  describe "display_fields loading" do
    test "get_linked_accounts loads primary_user and linked_user with display_fields", %{
      session_token: session_token,
      primary_user: primary_user,
      linked_user: linked_user
    } do
      create_link!(primary_user, linked_user, session_token)

      [result] =
        LinkedAccount
        |> Ash.Query.for_read(:get_linked_accounts, %{
          primary_user_id: primary_user.id,
          session_token: session_token
        })
        |> Ash.read!()

      # display_fields is [:name] in test_user.ex
      assert result.primary_user.name == "Primary User"
      assert result.linked_user.name == "Linked User"
    end

    test "get_user_with_linked_accounts loads linked account relationships", %{
      session_token: session_token,
      primary_user: primary_user,
      linked_user: linked_user
    } do
      create_link!(primary_user, linked_user, session_token)

      user =
        User
        |> Ash.Query.for_read(:get_user_with_linked_accounts, %{
          primary_user_id: primary_user.id,
          session_token: session_token
        })
        |> Ash.read_one!()

      assert user.name == "Primary User"
      assert [linked_account] = user.linked_accounts
      assert linked_account.primary_user.name == "Primary User"
      assert linked_account.linked_user.name == "Linked User"
    end
  end

  describe "get_user_with_linked_accounts" do
    test "loads user with linked accounts calculation", %{
      session_token: session_token,
      primary_user: primary_user,
      linked_user: linked_user
    } do
      create_link!(primary_user, linked_user, session_token)

      user =
        User
        |> Ash.Query.for_read(:get_user_with_linked_accounts, %{
          primary_user_id: primary_user.id,
          session_token: session_token
        })
        |> Ash.read_one!()

      assert user.id == primary_user.id
      assert user.name == "Primary User"
      assert is_list(user.linked_accounts)
      assert length(user.linked_accounts) == 1
    end

    test "returns empty linked accounts for user with no links", %{
      session_token: session_token,
      primary_user: primary_user
    } do
      user =
        User
        |> Ash.Query.for_read(:get_user_with_linked_accounts, %{
          primary_user_id: primary_user.id,
          session_token: session_token
        })
        |> Ash.read_one!()

      assert user.linked_accounts == []
    end
  end

  describe "active_check" do
    test "filters out linked accounts whose linked user is inactive", %{
      session_token: session_token,
      primary_user: primary_user
    } do
      # active_check is {:status, :active} in test_user.ex
      active_user =
        User
        |> Ash.Changeset.for_create(:create, %{name: "Active User"})
        |> Ash.create!()

      inactive_user =
        User
        |> Ash.Changeset.for_create(:create, %{name: "Inactive User"})
        |> Ash.create!()

      # Set user status to inactive
      inactive_user =
        inactive_user
        |> Ash.Changeset.for_update(:update, %{status: :inactive})
        |> Ash.update!()

      assert inactive_user.status == :inactive

      # Link both
      create_link!(primary_user, active_user, session_token)
      create_link!(primary_user, inactive_user, session_token)

      # Query should only return the active user's link
      results =
        LinkedAccount
        |> Ash.Query.for_read(:get_linked_accounts, %{
          primary_user_id: primary_user.id,
          session_token: session_token
        })
        |> Ash.read!()

      assert length(results) == 1
      [result] = results
      assert result.linked_user_id == active_user.id
    end
  end

  describe "linked_accounts calculation without session_token" do
    test "returns an error when session_token argument is missing", %{
      primary_user: primary_user
    } do
      assert {:error, error} =
               User
               |> Ash.Query.for_read(:get_user_with_linked_accounts, %{
                 primary_user_id: primary_user.id
               })
               |> Ash.read_one()

      assert Exception.message(error) =~ "session_token"
    end
  end

  describe "create without actor" do
    test "creating a linked account without an actor fails", %{
      session_token: session_token,
      linked_user: linked_user
    } do
      assert_raise Ash.Error.Invalid, fn ->
        LinkedAccount
        |> Ash.Changeset.for_create(
          :create_linked_account,
          %{linked_user_id: linked_user.id, session_token: session_token}
        )
        |> Ash.create!()
      end
    end
  end

  describe "destroy" do
    test "destroys a linked account", %{
      session_token: session_token,
      primary_user: primary_user,
      linked_user: linked_user
    } do
      linked_account = create_link!(primary_user, linked_user, session_token)

      assert :ok =
               linked_account
               |> Ash.Changeset.for_destroy(:destroy)
               |> Ash.destroy!()

      results = Ash.read!(LinkedAccount)
      assert results == []
    end
  end
end
