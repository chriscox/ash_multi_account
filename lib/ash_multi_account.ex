defmodule AshMultiAccount do
  @moduledoc """
  An Ash extension for multi-account linking and switching.

  Add this extension to your User resource to enable multi-account capabilities.
  Users can link multiple accounts together and switch between them without
  re-authenticating — similar to Google/Apple's account switcher UX.

  ## Concepts

  - **Primary User**: The account that initiated the multi-account session
  - **Linked User**: An additional account linked to the primary user
  - **Session Token**: A UUID that groups all linked accounts within a browser session
  - **Session-scoped**: Links exist per browser session, not globally

  ## Usage

  ```elixir
  defmodule MyApp.Accounts.User do
    use Ash.Resource,
      domain: MyApp.Accounts,
      data_layer: ...,  # any Ash data layer (AshPostgres, AshSqlite, ETS, etc.)
      extensions: [AshMultiAccount]

    multi_account do
      linked_account_resource MyApp.Accounts.LinkedAccount
      display_fields [:name, :email, :avatar_url]
      max_linked_accounts 5
    end
  end
  ```

  ## Generated Schema

  The extension adds to your User resource:

  - **Calculation** `:linked_accounts` — resolves linked account records for a given `session_token` argument
  - **Action** `:get_user_with_linked_accounts` — a `get?` read action that accepts `primary_user_id` and `session_token` arguments, looks up the user by `id`, loads the configured `display_fields`, and loads the `linked_accounts` calculation for the given session

  ## Companion Resource

  You must also create a LinkedAccount resource using the
  `AshMultiAccount.LinkedAccount` extension. See its documentation for details.
  """

  use Spark.Dsl.Extension,
    sections: AshMultiAccount.Dsl.dsl(),
    transformers: [
      AshMultiAccount.Transformer,
      AshMultiAccount.Verifier
    ]
end
