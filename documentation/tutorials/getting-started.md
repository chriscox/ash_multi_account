# Getting Started

This guide walks you through adding multi-account linking and switching to an existing Ash + AshAuthentication + Phoenix app. By the end, your users will be able to link multiple accounts to a single browser session and switch between them without re-authenticating.

## Prerequisites

AshMultiAccount adds multi-account support **on top of** an existing Ash + AshAuthentication + Phoenix app. Before installing, you need:

### Required

These are pulled in automatically as transitive dependencies of `ash_multi_account`:

- **Ash and Spark**
- **AshAuthentication** — you must have at least one authentication strategy configured
- **Phoenix** — controllers, plugs, and router all require it

You also need:

- **A user resource** — an Ash resource with AshAuthentication set up and registered in a domain (can be any module name, e.g. `MyApp.Accounts.User`, `MyApp.Accounts.Person`, etc.)
- **AshAuthentication Phoenix** (`ash_authentication_phoenix`) — provides `AshAuthentication.Phoenix.Controller` which is used by the auth controller that handles sign-in callbacks. Most Phoenix + AshAuthentication apps already have this.

> **Don't have a user resource yet?** Follow the [AshAuthentication Getting Started guide](https://hexdocs.pm/ash_authentication/get-started.html) to create one with an authentication strategy, then come back here.

### Also needed for LiveView

If your app uses LiveView for authenticated pages, also add:

- **Phoenix LiveView** (`phoenix_live_view`) — needed for the LiveView hook (`AshMultiAccount.Phoenix.LiveHook`) and the account switcher component (`AshMultiAccount.Phoenix.Components`).

> **Note:** `ash_authentication_phoenix` also provides `AshAuthentication.Phoenix.LiveSession` which the multi-account LiveView hook runs alongside. You likely already have it if your app uses AshAuthentication with LiveView.

The installer patches your existing resources and router; it does not create a User resource, domain, or authentication setup from scratch.

Specific version requirements are defined in the library's `mix.exs` — running `mix deps.get` will ensure compatible versions are resolved automatically.

### Data Layer

AshMultiAccount is **data layer agnostic**. It works with any Ash data layer — AshPostgres, AshSqlite, ETS, or others. The library generates standard Ash resources with attributes, relationships, and actions that work on any data layer. Both the demo app and the library's own test suite use ETS.

### Authentication Strategy

AshMultiAccount is **strategy-agnostic**. It works with any AshAuthentication strategy — password, OAuth2, magic links, API keys, or any combination. The library hooks into the session layer *after* authentication completes, so it doesn't care how the user originally signed in. The demo app uses password authentication for simplicity, but the same setup works with any strategy.

## Installation

Add the dependencies to your `mix.exs`. What you need depends on your setup:

<!-- tabs-open -->

### Using Igniter (recommended)

```elixir
# mix.exs
def deps do
  [
    {:ash_multi_account, "~> 0.1.0"},
    {:igniter, "~> 0.6"},
    # If not already present:
    {:ash_authentication_phoenix, "~> 2.0"},
    # Also add if using LiveView:
    {:phoenix_live_view, "~> 1.0"}
  ]
end
```

### Manual

```elixir
# mix.exs
def deps do
  [
    {:ash_multi_account, "~> 0.1.0"},
    # If not already present:
    {:ash_authentication_phoenix, "~> 2.0"},
    # Also add if using LiveView:
    {:phoenix_live_view, "~> 1.0"}
  ]
end
```

<!-- tabs-close -->

Run `mix deps.get` to fetch the dependencies.

<!-- tabs-open -->

### Using Igniter (recommended)

The Igniter installer automates steps 1–6 below:

1. Adds the `AshMultiAccount` extension to your User resource
2. Creates the LinkedAccount resource (or patches it if it exists)
3. Registers LinkedAccount in your domain
4. Patches your auth controller's `success/4` to call `put_user_id/3`
5. Creates a `MultiAccountController`
6. Adds `use AshMultiAccount.Phoenix.Router`, the `Plug`, and routes to your router

Steps 7–8 (LiveView hook / controller plug and account switcher component) are app-specific — the installer prints post-install instructions for these.

```sh
mix igniter.install ash_multi_account
```

If `ash_multi_account` is a path or git dependency (not yet on Hex), run the installer directly instead:

```sh
mix ash_multi_account.install
```

You can also specify resource module names explicitly:

```sh
mix igniter.install ash_multi_account \
  --user MyApp.Accounts.User \
  --linked-account MyApp.Accounts.LinkedAccount
```

After running the installer:

- **LiveView apps:** Follow the post-install instructions for the LiveView hook (Step 7) and component (Step 8)
- **Controller-only apps:** Add the `LoadMultiAccount` plug (Step 7 alt) and component (Step 8)

If using a database-backed data layer (AshPostgres, AshSqlite), update the generated LinkedAccount resource's data layer configuration and run migrations:

```bash
mix ash.codegen create_linked_accounts
mix ash.migrate
```

### Manual

Follow all steps below to set up AshMultiAccount manually.

<!-- tabs-close -->

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

> **Note:** Replace `:my_app` in `clear_session(:my_app)` with your OTP application name (the `:app` value in your `mix.exs` project config).

> **Why is `put_user_id` needed?** AshAuthentication stores a JWT subject string in the session. The multi-account hook needs a plain user ID to resolve the current user after account switches. `put_user_id/3` writes the subject in a format both systems can read.

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

## Step 7: LiveView Setup

> **Skip this step** if your app doesn't use LiveView. See [Step 7 alt](#step-7-alt-controller-only-setup) instead.

Add the multi-account hook to your authenticated live sessions. It should run **after** AshAuthentication's hook:

```elixir
live_session :authenticated,
  on_mount: [
    {AshAuthentication.Phoenix.LiveSession, :load_from_session},
    {AshMultiAccount.Phoenix.LiveHook, {:load_multi_account, MyApp.Accounts.User}}
  ] do
  live "/", HomeLive
  # ... more live routes
end
```

The hook sets two assigns on every mount:
- `@current_user` — the user currently acting (may differ from primary after a switch)
- `@primary_user` — the primary account owner (`nil` when not in multi-account mode)

> **Tip:** If your app has both LiveView and controller-rendered pages, you can add the `LoadMultiAccount` plug (Step 7 alt) alongside the LiveView hook. They read the same session keys and coexist without conflict.

## Step 7 alt: Controller-Only Setup

> **Skip this step** if you already added the LiveView hook above and don't have controller-rendered pages that need multi-account assigns.

Add the `LoadMultiAccount` plug to your browser pipeline:

```elixir
pipeline :browser do
  # ... existing plugs ...
  plug AshMultiAccount.Phoenix.Plug
  plug AshMultiAccount.Phoenix.LoadMultiAccount, user_resource: MyApp.Accounts.User
end
```

This plug sets the same `@current_user` and `@primary_user` assigns on `conn` that the LiveView hook sets on the socket. It must run after `:fetch_session` and `AshMultiAccount.Phoenix.Plug`.

For controller-only apps, this is the only integration step needed — the plug handles user resolution and multi-account switching for all controller-rendered pages.

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
    <span :if={account.current?}>{account.user.name} (current)</span>
  </:account>
  <:add_account :let={url}>
    <.link href={url}>Add another account</.link>
  </:add_account>
</AshMultiAccount.Phoenix.Components.account_switcher>
```

The component imposes no styling — you control all HTML and CSS through slots. It works identically in both LiveView templates and controller-rendered templates — it's a standard `Phoenix.Component` that only needs `@current_user` and `@primary_user` assigns.

## What's Next?

- [How It Works](../topics/how-it-works.md) — understand the data model, session tokens, and linking/switching flows
- [Phoenix Integration](../topics/phoenix-integration.md) — deep dive into each Phoenix module
- [Testing](../topics/testing.md) — set up test support and write tests for multi-account flows
