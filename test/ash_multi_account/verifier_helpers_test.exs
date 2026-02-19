defmodule AshMultiAccount.VerifierHelpersTest do
  use ExUnit.Case, async: true

  alias AshMultiAccount.VerifierHelpers

  describe "assert_resource_has_extension/2" do
    test "returns :ok for a resource with the correct extension" do
      assert :ok ==
               VerifierHelpers.assert_resource_has_extension(
                 AshMultiAccount.Test.LinkedAccount,
                 AshMultiAccount.LinkedAccount
               )
    end

    test "returns :ok for the user resource with AshMultiAccount" do
      assert :ok ==
               VerifierHelpers.assert_resource_has_extension(
                 AshMultiAccount.Test.User,
                 AshMultiAccount
               )
    end

    test "returns error for a resource without the extension" do
      assert {:error, message} =
               VerifierHelpers.assert_resource_has_extension(
                 AshMultiAccount.Test.User,
                 AshMultiAccount.LinkedAccount
               )

      assert message =~ "must use the"
      assert message =~ "AshMultiAccount.LinkedAccount"
    end

    test "returns error for a non-Ash module" do
      assert {:error, message} =
               VerifierHelpers.assert_resource_has_extension(
                 Enum,
                 AshMultiAccount.LinkedAccount
               )

      assert message =~ "not an Ash resource"
    end

    test "returns error for a non-existent module" do
      assert {:error, message} =
               VerifierHelpers.assert_resource_has_extension(
                 NonExistent.Module,
                 AshMultiAccount.LinkedAccount
               )

      assert message =~ "could not be compiled"
    end
  end

  describe "assert_is_resource/1" do
    test "returns :ok for an Ash resource" do
      assert :ok == VerifierHelpers.assert_is_resource(AshMultiAccount.Test.User)
    end

    test "returns error for a non-Ash module" do
      assert {:error, message} = VerifierHelpers.assert_is_resource(Enum)
      assert message =~ "not an Ash resource"
    end

    test "returns error for a non-existent module" do
      assert {:error, message} = VerifierHelpers.assert_is_resource(NonExistent.Module)
      assert message =~ "could not be compiled"
    end
  end
end
