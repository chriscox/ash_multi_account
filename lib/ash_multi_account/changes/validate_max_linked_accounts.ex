defmodule AshMultiAccount.Changes.ValidateMaxLinkedAccounts do
  @moduledoc """
  Change that enforces the `max_linked_accounts` limit configured on the
  User resource.

  Applied as a before-action hook on the `create_linked_account` action.
  Before the linked account is created, it counts existing active links for
  the same primary_user and session_token. If creating the record would
  exceed the configured maximum, the action is prevented with an error.
  """

  use Ash.Resource.Change
  import Ash.Expr, only: [ref: 1]
  import AshMultiAccount.Helpers, only: [fetch_config!: 2]
  require Ash.Query

  @impl true
  def change(changeset, _opts, context) do
    config = AshMultiAccount.Helpers.linked_account_config!(changeset.resource)

    max =
      fetch_config!(
        AshMultiAccount.Info.multi_account_max_linked_accounts(config.user_resource),
        :max_linked_accounts
      )

    primary_user_id_attr = :"#{config.primary_user_rel}_id"
    linked_user_id_attr = :"#{config.linked_user_rel}_id"
    active = AshMultiAccount.Helpers.active_status()

    Ash.Changeset.before_action(changeset, fn changeset ->
      # Read primary_user_id from the actor (the primary user) since
      # RelateActor's before_action hook may not have set the attribute yet.
      primary_user_id = if context.actor, do: context.actor.id
      session_token = Ash.Changeset.get_attribute(changeset, config.session_token_attr)

      if is_nil(primary_user_id) or is_nil(session_token) do
        # Can't validate without these values; let downstream validations handle it
        changeset
      else
        query =
          changeset.resource
          |> Ash.Query.filter(^ref(primary_user_id_attr) == ^primary_user_id)
          |> Ash.Query.filter(^ref(config.session_token_attr) == ^session_token)
          |> Ash.Query.filter(^ref(config.status_attr) == ^active)

        case Ash.count(query, authorize?: false) do
          {:ok, count} when count >= max ->
            {:error,
             Ash.Error.Changes.InvalidChanges.exception(
               fields: [linked_user_id_attr],
               message: "maximum of #{max} linked accounts exceeded"
             )}

          {:ok, _count} ->
            changeset

          {:error, error} ->
            {:error, error}
        end
      end
    end)
  end
end
