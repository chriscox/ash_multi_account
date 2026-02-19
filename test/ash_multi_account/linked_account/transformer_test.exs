defmodule AshMultiAccount.LinkedAccount.TransformerTest do
  use ExUnit.Case, async: true

  alias Ash.Resource.Info
  alias AshMultiAccount.Test.LinkedAccount

  describe "attributes" do
    test "has session_token attribute" do
      attr = Info.attribute(LinkedAccount, :session_token)
      assert attr
      assert attr.type == Ash.Type.UUID
      assert attr.allow_nil? == false
    end

    test "has status attribute" do
      attr = Info.attribute(LinkedAccount, :status)
      assert attr
      assert attr.type == Ash.Type.Atom
      assert attr.default == :active
    end
  end

  describe "relationships" do
    test "has primary_user belongs_to" do
      rel = Info.relationship(LinkedAccount, :primary_user)
      assert rel
      assert rel.type == :belongs_to
      assert rel.destination == AshMultiAccount.Test.User
      assert rel.allow_nil? == false
    end

    test "has linked_user belongs_to" do
      rel = Info.relationship(LinkedAccount, :linked_user)
      assert rel
      assert rel.type == :belongs_to
      assert rel.destination == AshMultiAccount.Test.User
      assert rel.allow_nil? == false
    end
  end

  describe "identity" do
    test "has unique_linked_user_session identity" do
      identities = Info.identities(LinkedAccount)

      identity =
        Enum.find(identities, fn i -> i.name == :unique_linked_user_session end)

      assert identity

      assert MapSet.new(identity.keys) ==
               MapSet.new([:primary_user_id, :linked_user_id, :session_token])
    end
  end

  describe "actions" do
    test "has create_linked_account action" do
      action = Info.action(LinkedAccount, :create_linked_account)
      assert action
      assert action.type == :create
    end

    test "has get_linked_accounts action" do
      action = Info.action(LinkedAccount, :get_linked_accounts)
      assert action
      assert action.type == :read

      arg_names = Enum.map(action.arguments, & &1.name)
      assert :primary_user_id in arg_names
      assert :session_token in arg_names
    end

    test "has activate action" do
      action = Info.action(LinkedAccount, :activate)
      assert action
      assert action.type == :update
    end

    test "has deactivate action" do
      action = Info.action(LinkedAccount, :deactivate)
      assert action
      assert action.type == :update
    end

    test "has default read action" do
      action = Info.action(LinkedAccount, :read)
      assert action
      assert action.type == :read
      assert action.primary? == true
    end

    test "has default destroy action" do
      action = Info.action(LinkedAccount, :destroy)
      assert action
      assert action.type == :destroy
      assert action.primary? == true
    end
  end

  describe "calculations" do
    test "has is_active? calculation" do
      calc = Info.calculation(LinkedAccount, :is_active?)
      assert calc
      assert calc.type == Ash.Type.Boolean
    end
  end
end
