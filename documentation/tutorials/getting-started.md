# Getting Started

This guide walks you through adding multi-account linking and switching to an existing Ash + AshAuthentication + Phoenix app. By the end, your users will be able to link multiple accounts to a single browser session and switch between them without re-authenticating.

## Requirements

| Dependency | Version | Required? |
|------------|---------|-----------|
| Elixir | >= 1.17 | Yes |
| Ash | ~> 3.0 | Yes |
| Spark | ~> 2.0 | Yes (pulled in by Ash) |
| AshAuthentication | ~> 4.0 | Yes (for Phoenix integration) |
| Phoenix | ~> 1.7 | Yes (for web layer) |
| Phoenix LiveView | ~> 1.0 | Yes (for LiveView hook + components) |

You need an existing Ash app with AshAuthentication configured and a User resource with at least one authentication strategy.

### Data Layer

AshMultiAccount is **data layer agnostic**. It works with any Ash data layer — AshPostgres, AshSqlite, ETS, or others. The library generates standard Ash resources with attributes, relationships, and actions that work on any data layer. Both the demo app and the library's own test suite use ETS.

### Authentication Strategy

AshMultiAccount is **strategy-agnostic**. It works with any AshAuthentication strategy — password, OAuth2, magic links, API keys, or any combination. The library hooks into the session layer *after* authentication completes, so it doesn't care how the user originally signed in. The demo app uses password authentication for simplicity, but the same setup works with any strategy.

## Installation

> **Igniter installer coming soon.** A `mix igniter.install ash_multi_account` task is planned that will automate the setup below. For now, follow the manual steps.

AshMultiAccount is not yet published to Hex. Use a path or git dependency:

```elixir
# mix.exs
def deps do
  [
    {:ash_multi_account, path: "../ash_multi_account"}
    # or
    # {:ash_multi_account, github: "chriscox/ash_multi_account"}
  ]
end
```

Run `mix deps.get` to fetch the dependency.

## Step 1: Add the Extension to Your User Resource

Add `AshMultiAccount` to your User resource's extensions and configure the `multi_account` section:

```elixir
defmodule MyApp.Accounts.User do
  use Ash.Resource,
    domain: MyApp.Accounts,
    data_layer: ...,  # any Ash data layer (AshPostgres, AshSqlite, ETS, etc.)
    extensions: [AshAuthentication, AshMultiAccount]

  multi_account do
    linked_account_resource MyApp.Accounts.LinkedAccount
    active_check {:status, :active}
    display_fields [:name, :email, :avatar_url]
    max_linked_accounts 5
  end

  # ... your existing attributes, actions, etc.
end
```

### Configuration Options

| Option | Required | Default | Description |
|--------|----------|---------|-------------|
| `linked_account_resource` | Yes | — | The LinkedAccount resource module |
| `active_check` | No | `nil` | `{field, value}` tuple — only active users can be linked/switched to |
| `display_fields` | No | `[]` | Fields loaded on users for the switcher UI |
| `max_linked_accounts` | No | `5` | Maximum linked accounts per session |

The extension's transformer will automatically add:
- A `:linked_accounts` calculation that resolves linked account records for a session
- A `:get_user_with_linked_accounts` read action used by the LiveView hook

## Step 2: Create the LinkedAccount Resource

Create a new resource with the `AshMultiAccount.LinkedAccount` extension:

```elixir
defmodule MyApp.Accounts.LinkedAccount do
  use Ash.Resource,
    domain: MyApp.Accounts,
    data_layer: ...,  # any Ash data layer (AshPostgres, AshSqlite, ETS, etc.)
    extensions: [AshMultiAccount.LinkedAccount]

  multi_account do
    user_resource MyApp.Accounts.User
  end

  # If using a database-backed data layer, add its config here.
  # For example, with AshPostgres:
  #   postgres do
  #     table "linked_accounts"
  #     repo MyApp.Repo
  #   end
end
```

The transformer generates the full schema automatically:
- **Attributes**: `session_token`, `status` (`:active`/`:inactive`), timestamps
- **Relationships**: `primary_user` and `linked_user` (both `belongs_to` your User)
- **Actions**: `create_linked_account`, `get_linked_accounts`, `activate`, `deactivate`, `read`, `destroy`
- **Calculations**: `is_active?`
- **Identity**: unique constraint on `{primary_user_id, linked_user_id, session_token}`

If using a database-backed data layer, generate and run the migration:

```bash
mix ash.codegen create_linked_accounts
mix ash.migrate
```

> **Note:** In-memory data layers like ETS require no migration step.

## Step 3: Register in Your Domain

Add the LinkedAccount resource to your domain:

```elixir
defmodule MyApp.Accounts do
  use Ash.Domain

  resources do
    resource MyApp.Accounts.User
    resource MyApp.Accounts.LinkedAccount
  end
end
```

## Step 4: Update the Auth Controller

Your AshAuthentication auth controller needs to write the user ID to the session in a format the multi-account hook can read. Add a call to `AshMultiAccount.Phoenix.Session.put_user_id/3` in your success callback:

```elixir
defmodule MyAppWeb.AuthController do
  use MyAppWeb, :controller
  use AshAuthentication.Phoenix.Controller

  def success(conn, _activity, user, _token) do
    conn
    |> store_in_session(user)
    |> AshMultiAccount.Phoenix.Session.put_user_id(user.id)
    |> assign(:current_user, user)
    |> redirect(to: ~p"/")
  end

  def failure(conn, _activity, _reason) do
    conn
    |> put_flash(:error, "Incorrect email or password")
    |> redirect(to: ~p"/sign-in")
  end

  def sign_out(conn, _params) do
    conn
    |> clear_session(:my_app)
    |> redirect(to: ~p"/sign-in")
  end
end
```

> **Why is this needed?** AshAuthentication stores a JWT subject string in the session. The multi-account LiveView hook needs a plain user ID to resolve the current user after account switches. `put_user_id/3` writes the subject in a format both systems can read.

## Step 5: Create the Multi-Account Controller

```elixir
defmodule MyAppWeb.MultiAccountController do
  use MyAppWeb, :controller
  use AshMultiAccount.Phoenix.Controller,
    user_resource: MyApp.Accounts.User

  # Optionally override redirect paths:
  # def after_link_path(_conn), do: ~p"/"
  # def after_switch_path(_conn), do: ~p"/"
  # def sign_in_path(_conn, primary_user_id), do: ~p"/sign-in?return_to=/link/p/#{primary_user_id}"
end
```

The controller mixin provides two actions:
- `link_account/2` — links a newly signed-in user to an existing primary account
- `switch_to_account/2` — switches the session to a different linked user

## Step 6: Add Routes

```elixir
defmodule MyAppWeb.Router do
  use MyAppWeb, :router
  use AshMultiAccount.Phoenix.Router

  pipeline :browser do
    # ... existing plugs ...
    plug AshMultiAccount.Phoenix.Plug
  end

  scope "/", MyAppWeb do
    pipe_through :browser

    # Generates:
    #   GET /link/p/:primary_user_id  -> MultiAccountController.link_account
    #   GET /link/switch_to/:user_id  -> MultiAccountController.switch_to_account
    multi_account_routes MultiAccountController, MyApp.Accounts.User
  end
end
```

`AshMultiAccount.Phoenix.Plug` ensures a session token UUID exists before any multi-account routes are hit.

## Step 7: Add the LiveView Hook

Add the multi-account hook to your authenticated live sessions. It should run **after** AshAuthentication's hook:

```elixir
live_session :authenticated,
  on_mount: [
    {AshAuthentication.Phoenix.LiveSession, :load_from_session},
    {AshMultiAccount.Phoenix.LiveHook, {:load_multi_account, MyApp.Accounts.User}}
  ] do
  live "/", DashboardLive
  # ... more live routes
end
```

The hook sets two assigns on every mount:
- `@current_user` — the user currently acting (may differ from primary after a switch)
- `@primary_user` — the primary account owner (`nil` when not in multi-account mode)

## Step 8: Add the Account Switcher Component

Use the slot-based component in your layout or navigation:

```heex
<AshMultiAccount.Phoenix.Components.account_switcher
  current_user={@current_user}
  primary_user={@primary_user}
>
  <:account :let={account}>
    <.link :if={!account.current?} href={account.switch_url}>
      {account.user.name}
    </.link>
    <span :if={account.current?}>{account.user.name} (active)</span>
  </:account>
  <:add_account :let={url}>
    <.link href={url}>Add another account</.link>
  </:add_account>
</AshMultiAccount.Phoenix.Components.account_switcher>
```

The component imposes no styling — you control all HTML and CSS through slots.

## What's Next?

- [How It Works](how-it-works.md) — understand the data model, session tokens, and linking/switching flows
- [Phoenix Integration](phoenix-integration.md) — deep dive into each Phoenix module
- [Testing](testing.md) — set up test support and write tests for multi-account flows
