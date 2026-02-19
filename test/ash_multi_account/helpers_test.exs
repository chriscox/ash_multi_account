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
end
