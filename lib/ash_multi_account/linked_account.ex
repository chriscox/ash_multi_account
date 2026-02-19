defmodule AshMultiAccount.LinkedAccount do
  @moduledoc """
  An Ash extension which generates the default linked account resource.

  The linked account resource tracks links between user accounts within a
  browser session. Each link connects a "primary user" (the account that
  initiated the session) with a "linked user" (an additional account), scoped
  to a session token.

  ## Usage

  There is no need to define attributes, relationships, or actions manually.
  The extension generates them all for you.

  ```elixir
  defmodule MyApp.Accounts.LinkedAccount do
    use Ash.Resource,
      domain: MyApp.Accounts,
      data_layer: ...,  # any Ash data layer (AshPostgres, AshSqlite, ETS, etc.)
      extensions: [AshMultiAccount.LinkedAccount]

    multi_account do
      user_resource MyApp.Accounts.User
    end
  end
  ```

  If using a database-backed data layer, add the appropriate data layer config
  (e.g. `postgres do ... end` for AshPostgres).

  ## Generated Schema

  The extension adds:

  - **Primary Key**: `id` (UUID, auto-generated if not already defined)
  - **Attributes**: `session_token` (UUID), `status` (`:active` / `:inactive`),
    `inserted_at`, `updated_at`
  - **Relationships**: `primary_user` and `linked_user` (both `belongs_to` User)
  - **Identity**: unique constraint on `[primary_user_id, linked_user_id, session_token]`
  - **Actions**: `create_linked_account`, `get_linked_accounts`, `activate`,
    `deactivate`, `read`, `destroy`
  - **Calculation**: `is_active?` (module-based, checks status attribute)

  ## Policies

  No policies are added by default. You should add your own authorization
  policies. Recommended:

  ```elixir
  policies do
    policy action_type(:read) do
      authorize_if always()
    end

    policy action_type(:create) do
      authorize_if relates_to_actor_via(:primary_user)
    end

    policy action_type([:update, :destroy]) do
      authorize_if expr(primary_user_id == ^actor(:id))
    end
  end
  ```
  """

  use Spark.Dsl.Extension,
    sections: AshMultiAccount.LinkedAccount.Dsl.dsl(),
    transformers: [
      AshMultiAccount.LinkedAccount.Transformer,
      AshMultiAccount.LinkedAccount.Verifier
    ]
end
