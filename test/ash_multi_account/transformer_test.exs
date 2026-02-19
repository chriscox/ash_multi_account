defmodule AshMultiAccount.TransformerTest do
  use ExUnit.Case, async: true

  alias Ash.Resource.Info
  alias AshMultiAccount.Test.User

  describe "calculations" do
    test "has linked_accounts calculation" do
      calc = Info.calculation(User, :linked_accounts)
      assert calc
      assert calc.type == {:array, Ash.Type.Struct}

      arg_names = Enum.map(calc.arguments, & &1.name)
      assert :session_token in arg_names
      refute :primary_user_id in arg_names
    end
  end

  describe "actions" do
    test "has get_user_with_linked_accounts action" do
      action = Info.action(User, :get_user_with_linked_accounts)
      assert action
      assert action.type == :read
      assert action.get? == true

      arg_names = Enum.map(action.arguments, & &1.name)
      assert :primary_user_id in arg_names
      assert :session_token in arg_names
    end
  end
end
