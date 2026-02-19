defmodule AshMultiAccount.Preparations.LoadLinkedAccounts do
  @moduledoc """
  Preparation for the User resource's `get_user_with_linked_accounts` action
  (a `get?` read that returns a single user).

  Filters by the `primary_user_id` argument, loads the configured
  `display_fields`, and loads the `linked_accounts` calculation with the
  session token passed through.
  """

  use Ash.Resource.Preparation
  import AshMultiAccount.Helpers, only: [fetch_config!: 2]
  require Ash.Query

  @impl true
  def prepare(query, _opts, _context) do
    user_resource = query.resource
    primary_user_id = Ash.Query.get_argument(query, :primary_user_id)
    session_token = Ash.Query.get_argument(query, :session_token)

    calc_name =
      fetch_config!(
        AshMultiAccount.Info.multi_account_linked_accounts_calculation_name(user_resource),
        :linked_accounts_calculation_name
      )

    display_fields =
      fetch_config!(
        AshMultiAccount.Info.multi_account_display_fields(user_resource),
        :display_fields
      )

    query
    |> Ash.Query.filter(id == ^primary_user_id)
    |> Ash.Query.load(display_fields ++ [{calc_name, %{session_token: session_token}}])
  end
end
