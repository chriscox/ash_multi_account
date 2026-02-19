defmodule AshMultiAccount.LinkedAccount.Verifier do
  @moduledoc """
  Post-compilation verifier for the LinkedAccount resource.

  Validates that the configured `user_resource` is an Ash resource with
  the `AshMultiAccount` extension applied.

  Implemented as a `Spark.Dsl.Transformer` with `after_compile?: true` rather
  than a `Spark.Dsl.Verifier` because it needs post-compilation access to check
  that the referenced resource module has been compiled with the correct extension.
  """

  use Spark.Dsl.Transformer
  alias AshMultiAccount.LinkedAccount.Info

  @impl true
  def after?(_), do: true

  @impl true
  def before?(_), do: false

  @impl true
  def after_compile?, do: true

  @impl true
  def transform(dsl_state) do
    with {:ok, user_resource} <- Info.multi_account_user_resource(dsl_state) do
      AshMultiAccount.VerifierHelpers.assert_resource_has_extension(
        user_resource,
        AshMultiAccount
      )
    end
  end
end
