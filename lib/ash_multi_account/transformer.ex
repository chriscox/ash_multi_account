defmodule AshMultiAccount.Transformer do
  @moduledoc """
  The User resource transformer.

  Adds the `linked_accounts` calculation and `get_user_with_linked_accounts`
  action to the User resource.
  """

  use Spark.Dsl.Transformer
  alias Ash.Resource
  alias AshMultiAccount.Info
  alias Spark.Dsl.Transformer

  @doc false
  @impl true
  def after?(Resource.Transformers.ValidatePrimaryActions), do: true
  def after?(_), do: false

  @doc false
  @impl true
  def before?(Resource.Transformers.DefaultAccept), do: true
  def before?(_), do: false

  @doc false
  @impl true
  def transform(dsl_state) do
    with {:ok, calc_name} <- Info.multi_account_linked_accounts_calculation_name(dsl_state),
         {:ok, action_name} <-
           Info.multi_account_get_user_with_linked_accounts_action_name(dsl_state),
         {:ok, dsl_state} <- maybe_build_linked_accounts_calculation(dsl_state, calc_name),
         {:ok, dsl_state} <- maybe_build_get_user_action(dsl_state, action_name) do
      {:ok, dsl_state}
    end
  end

  defp maybe_build_linked_accounts_calculation(dsl_state, calc_name) do
    if Resource.Info.calculation(dsl_state, calc_name) do
      {:ok, dsl_state}
    else
      arguments = [
        Transformer.build_entity!(Resource.Dsl, [:calculations, :calculate], :argument,
          name: :session_token,
          type: :uuid,
          allow_nil?: false
        )
      ]

      calc =
        Transformer.build_entity!(Resource.Dsl, [:calculations], :calculate,
          name: calc_name,
          type: {:array, :struct},
          calculation: AshMultiAccount.Calculations.LinkedAccountSessions,
          arguments: arguments
        )

      {:ok, Transformer.add_entity(dsl_state, [:calculations], calc)}
    end
  end

  defp maybe_build_get_user_action(dsl_state, action_name) do
    case Resource.Info.action(dsl_state, action_name) do
      nil ->
        arguments = [
          Transformer.build_entity!(Resource.Dsl, [:actions, :read], :argument,
            name: :primary_user_id,
            type: :uuid,
            allow_nil?: false
          ),
          Transformer.build_entity!(Resource.Dsl, [:actions, :read], :argument,
            name: :session_token,
            type: :uuid,
            allow_nil?: false
          )
        ]

        preparations = [
          Transformer.build_entity!(Resource.Dsl, [:actions, :read], :prepare,
            preparation: AshMultiAccount.Preparations.LoadLinkedAccounts
          )
        ]

        with {:ok, action} <-
               Transformer.build_entity(Resource.Dsl, [:actions], :read,
                 name: action_name,
                 get?: true,
                 arguments: arguments,
                 preparations: preparations
               ) do
          {:ok, Transformer.add_entity(dsl_state, [:actions], action)}
        end

      _action ->
        {:ok, dsl_state}
    end
  end
end
