# AshMultiAccount

[![CI](https://github.com/chriscox/ash_multi_account/actions/workflows/ci.yml/badge.svg)](https://github.com/chriscox/ash_multi_account/actions/workflows/ci.yml)

**Status: In Development — not yet published to Hex**

Multi-account linking and switching for [Ash](https://ash-hq.org/) apps. Let users link multiple accounts together and switch between them without re-authenticating — similar to Google/Apple's account switcher UX.

## Why?

Many apps need multi-account support: family accounts, work/personal separation, admin impersonation. Building this correctly requires careful session management, security considerations (session fixation, authorization checks), and LiveView integration. This library handles all of that.

There's nothing like this in the Ash ecosystem today.

## Features

- Session-scoped account linking (primary user + linked accounts)
- Configurable active-user checks, display fields, and max linked accounts
- Self-link prevention and max-account enforcement
- Activate/deactivate linked accounts with status tracking
- Works alongside AshAuthentication's existing session management
- Phoenix controller mixin with link/switch actions and session regeneration
- LiveView hook that resolves `current_user` and `primary_user` on every mount
- Default account switcher component with slot-based override system
- Router macros for link/switch routes
- Session token plug for automatic token management

## Usage

### 1. Add to your User resource

```elixir
defmodule MyApp.Accounts.User do
  use Ash.Resource,
    domain: MyApp.Accounts,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshMultiAccount]

  multi_account do
    linked_account_resource MyApp.Accounts.LinkedAccount
    active_check {:status, :active}
    display_fields [:full_name, :avatar_url]
    max_linked_accounts 5
  end
end
```

### 2. Define a LinkedAccount resource

```elixir
defmodule MyApp.Accounts.LinkedAccount do
  use Ash.Resource,
    domain: MyApp.Accounts,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshMultiAccount.LinkedAccount]

  multi_account do
    user_resource MyApp.Accounts.User
  end

  postgres do
    table "linked_accounts"
    repo MyApp.Repo
  end
end
```

### 3. Wire up the auth controller

Your AshAuthentication auth controller needs one addition — call
`AshMultiAccount.Phoenix.Session.put_user_id/3` in the success callback.
This is required because AshAuthentication stores a JWT token in the session,
while the multi-account LiveView hook needs a plain user ID to resolve the
current user after account switches. The third argument is the resource's
`short_name` and defaults to `"user"`:

```elixir
# lib/my_app_web/controllers/auth_controller.ex
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

### 4. Add routes and controller

```elixir
# lib/my_app_web/router.ex
defmodule MyAppWeb.Router do
  use MyAppWeb, :router
  use AshMultiAccount.Phoenix.Router

  pipeline :browser do
    # ... existing plugs ...
    plug AshMultiAccount.Phoenix.Plug
  end

  scope "/", MyAppWeb do
    pipe_through :browser
    multi_account_routes MultiAccountController, MyApp.Accounts.User
  end
end
```

```elixir
# lib/my_app_web/controllers/multi_account_controller.ex
defmodule MyAppWeb.MultiAccountController do
  use MyAppWeb, :controller
  use AshMultiAccount.Phoenix.Controller, user_resource: MyApp.Accounts.User

  # Optionally override redirect paths
  def after_link_path(_conn), do: ~p"/"
  def after_switch_path(_conn), do: ~p"/"
  def sign_in_path(_conn, primary_user_id), do: ~p"/sign-in?return_to=/link/p/#{primary_user_id}"
end
```

### 5. Add LiveView hook

```elixir
live_session :authenticated,
  on_mount: [
    {AshMultiAccount.Phoenix.LiveHook, {:load_multi_account, MyApp.Accounts.User}}
  ] do
  # your live routes...
end
```

### 6. Use the account switcher component

```elixir
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

## Example App

A complete demo Phoenix app lives in [`example/demo/`](example/demo/). It exercises every integration point — auth, linking, switching, the account switcher component, and the LiveView hook — against a real Postgres database.

### Quick start

```bash
cd example/demo
mix setup                  # deps, db create/migrate/seed, assets
mix phx.server             # http://localhost:4000
```

Two seed users are created automatically:

| Email | Password |
|-------|----------|
| alice@example.com | password123! |
| bob@example.com | password123! |

### What to try

1. Sign in as Alice — single-account mode, account switcher shows one entry
2. Click **"+ Add another account"** — redirects to sign-in
3. Sign in as Bob — Bob is linked to Alice's session, both appear in the switcher
4. Click **Switch** next to Alice — session switches without re-authenticating
5. Sign out and sign in fresh — links are session-scoped, so you're back to single-account mode

The demo app is tested in CI alongside the core library to catch integration regressions.

## Installation

Not yet published to Hex. During development, use a path dependency:

```elixir
def deps do
  [
    {:ash_multi_account, path: "../ash_multi_account"}
  ]
end
```

## License

MIT — see [LICENSE](LICENSE).
