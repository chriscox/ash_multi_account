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

### 3. Add routes and controller

```elixir
# lib/my_app_web/router.ex
defmodule MyAppWeb.Router do
  use MyAppWeb, :router
  use AshMultiAccount.Phoenix.Router

  scope "/", MyAppWeb do
    pipe_through [:browser, AshMultiAccount.Phoenix.Plug]
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

### 4. Add LiveView hook

```elixir
live_session :authenticated,
  on_mount: [
    {AshMultiAccount.Phoenix.LiveHook, {:load_multi_account, MyApp.Accounts.User}}
  ] do
  # your live routes...
end
```

### 5. Use the account switcher component

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
