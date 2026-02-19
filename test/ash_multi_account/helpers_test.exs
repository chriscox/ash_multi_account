defmodule AshMultiAccount.HelpersTest do
  use ExUnit.Case, async: true

  alias AshMultiAccount.Helpers

  describe "fetch_config!/2" do
    test "unwraps {:ok, value}" do
      assert Helpers.fetch_config!({:ok, :some_value}, :test_label) == :some_value
    end

    test "raises ArgumentError on :error" do
      assert_raise ArgumentError, ~r/Could not read test_label/, fn ->
        Helpers.fetch_config!(:error, :test_label)
      end
    end

    test "raises ArgumentError on {:error, reason}" do
      assert_raise ArgumentError, ~r/Could not read test_label/, fn ->
        Helpers.fetch_config!({:error, "some reason"}, :test_label)
      end
    end

    test "error message includes the unexpected value" do
      assert_raise ArgumentError, ~r/Got: :error/, fn ->
        Helpers.fetch_config!(:error, :my_config)
      end
    end
  end

  describe "validate_user_active/2" do
    test "returns :ok when user passes the active_check" do
      user = %AshMultiAccount.Test.User{status: :active}
      assert :ok = Helpers.validate_user_active(user, AshMultiAccount.Test.User)
    end

    test "returns {:error, :not_active} when user fails the active_check" do
      user = %AshMultiAccount.Test.User{status: :inactive}
      assert {:error, :not_active} = Helpers.validate_user_active(user, AshMultiAccount.Test.User)
    end

    test "returns :ok when no active_check is configured on the resource" do
      user = %AshMultiAccount.Test.UserNoActiveCheck{name: "Test"}
      assert :ok = Helpers.validate_user_active(user, AshMultiAccount.Test.UserNoActiveCheck)
    end

    test "raises BadMapError when user is nil" do
      assert_raise BadMapError, fn ->
        Helpers.validate_user_active(nil, AshMultiAccount.Test.User)
      end
    end
  end
end
