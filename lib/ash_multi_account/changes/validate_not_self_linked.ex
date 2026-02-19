defmodule AshMultiAccount.Changes.ValidateNotSelfLinked do
  @moduledoc """
  Change that validates a user cannot link to themselves.
  """

  use Ash.Resource.Change

  require Logger

  @impl true
  def change(changeset, opts, context) do
    linked_user_id_attr = Keyword.fetch!(opts, :linked_user_id_attr)
    linked_user_id = Ash.Changeset.get_attribute(changeset, linked_user_id_attr)
    actor = context.actor

    cond do
      is_nil(actor) ->
        Logger.warning("AshMultiAccount: ValidateNotSelfLinked called without an actor")
        changeset

      linked_user_id && linked_user_id == actor.id ->
        Ash.Changeset.add_error(
          changeset,
          Ash.Error.Changes.InvalidChanges.exception(
            fields: [linked_user_id_attr],
            message: "cannot link a user to themselves"
          )
        )

      true ->
        changeset
    end
  end
end
