defmodule AshMultiAccount.Preparations.FilterLinkedAccounts do
  @moduledoc """
  Preparation that filters the `get_linked_accounts` query by primary_user_id,
  session_token, and the linked account's own active status.

  Additionally, when the User resource has an `active_check` configured (e.g.,
  `{:status, :active}`), this preparation also filters to only include records
  whose linked user satisfies that field/value check.
  """

  use Ash.Resource.Preparation
  import Ash.Expr, only: [ref: 1]
  require Ash.Query

  @impl true
  def prepare(query, _opts, _context) do
    primary_user_id = Ash.Query.get_argument(query, :primary_user_id)
    session_token = Ash.Query.get_argument(query, :session_token)

    config = AshMultiAccount.Helpers.linked_account_config!(query.resource)
    primary_user_id_attr = :"#{config.primary_user_rel}_id"
    active = AshMultiAccount.Helpers.active_status()

    query =
      query
      |> Ash.Query.filter(^ref(primary_user_id_attr) == ^primary_user_id)
      |> Ash.Query.filter(^ref(config.session_token_attr) == ^session_token)
      |> Ash.Query.filter(^ref(config.status_attr) == ^active)
      |> Ash.Query.sort(inserted_at: :asc)

    apply_active_check(query, config)
  end

  defp apply_active_check(query, config) do
    case AshMultiAccount.Info.multi_account_active_check(config.user_resource) do
      {:ok, {field, value}} ->
        # Build a Ref struct to filter through the relationship path dynamically.
        # We can't use the `ref/2` macro here because both the field name and
        # relationship path are runtime values resolved from DSL configuration.
        active_ref = %Ash.Query.Ref{
          attribute: field,
          relationship_path: [config.linked_user_rel]
        }

        Ash.Query.filter(query, ^active_ref == ^value)

      :error ->
        query
    end
  end
end
