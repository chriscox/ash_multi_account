defmodule AshMultiAccount.Dsl do
  @moduledoc false

  @multi_account %Spark.Dsl.Section{
    name: :multi_account,
    describe: "Configure multi-account options for the User resource.",
    no_depend_modules: [:linked_account_resource],
    schema: [
      linked_account_resource: [
        type: {:behaviour, Ash.Resource},
        doc: "The LinkedAccount resource module.",
        required: true
      ],
      active_check: [
        type: {:tuple, [:atom, :any]},
        doc: """
        A `{field, value}` tuple used to check if a linked user is "active".
        When set, the `get_linked_accounts` query will filter to only include
        linked users where the given field equals the given value.
        For example: `{:status, :active}` or `{:status_id, :active}`.
        """,
        required: false
      ],
      display_fields: [
        type: {:list, :atom},
        doc: """
        Fields to load on the primary_user and linked_user when fetching
        linked accounts. These are typically the fields needed for a
        user switcher UI (e.g., `[:name, :email, :avatar_url]`).
        """,
        default: []
      ],
      max_linked_accounts: [
        type: :pos_integer,
        doc: "Maximum number of linked accounts allowed per session.",
        default: 5
      ],
      get_user_with_linked_accounts_action_name: [
        type: :atom,
        doc: "The name of the action that loads a user with their linked accounts.",
        default: :get_user_with_linked_accounts
      ],
      linked_accounts_calculation_name: [
        type: :atom,
        doc: "The name of the linked_accounts calculation on the User resource.",
        default: :linked_accounts
      ]
    ]
  }

  def dsl, do: [@multi_account]
end
