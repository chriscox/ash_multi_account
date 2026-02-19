defmodule AshMultiAccount.Verifier do
  @moduledoc """
  Post-compilation verifier for the User resource.

  Validates that the configured `linked_account_resource` is an Ash resource
  with the `AshMultiAccount.LinkedAccount` extension applied, and that
  `display_fields` and `active_check` reference valid attributes.

  Implemented as a `Spark.Dsl.Transformer` with `after_compile?: true` rather
  than a `Spark.Dsl.Verifier` because it needs post-compilation access to check
  that the referenced resource module has been compiled with the correct extension.
  """

  use Spark.Dsl.Transformer
  alias AshMultiAccount.Info
  alias Spark.Dsl.Transformer

  @impl true
  def after?(_), do: true

  @impl true
  def before?(_), do: false

  @impl true
  def after_compile?, do: true

  @impl true
  def transform(dsl_state) do
    with {:ok, linked_account_resource} <-
           Info.multi_account_linked_account_resource(dsl_state),
         :ok <-
           AshMultiAccount.VerifierHelpers.assert_resource_has_extension(
             linked_account_resource,
             AshMultiAccount.LinkedAccount
           ),
         :ok <- validate_display_fields(dsl_state),
         :ok <- validate_active_check(dsl_state) do
      :ok
    end
  end

  defp validate_display_fields(dsl_state) do
    case Info.multi_account_display_fields(dsl_state) do
      {:ok, []} ->
        :ok

      {:ok, fields} ->
        resource = Transformer.get_persisted(dsl_state, :module)

        Enum.find_value(fields, :ok, fn field ->
          unless Ash.Resource.Info.attribute(dsl_state, field) ||
                   Ash.Resource.Info.calculation(dsl_state, field) do
            {:error, "display_fields references unknown field `#{field}` on #{inspect(resource)}"}
          end
        end)
    end
  end

  defp validate_active_check(dsl_state) do
    case Info.multi_account_active_check(dsl_state) do
      {:ok, {field, value}} ->
        resource = Transformer.get_persisted(dsl_state, :module)

        case Ash.Resource.Info.attribute(dsl_state, field) do
          nil ->
            {:error, "active_check field `#{field}` is not an attribute on #{inspect(resource)}"}

          attribute ->
            case Ash.Type.cast_input(attribute.type, value, attribute.constraints) do
              {:ok, _} ->
                :ok

              _ ->
                {:error,
                 "active_check value `#{inspect(value)}` is not valid for attribute " <>
                   "`#{field}` (type: #{inspect(attribute.type)}) on #{inspect(resource)}"}
            end
        end

      {:ok, nil} ->
        :ok
    end
  end
end
