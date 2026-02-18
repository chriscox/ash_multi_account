# AshMultiAccount

[![CI](https://github.com/chriscox/ash_multi_account/actions/workflows/ci.yml/badge.svg)](https://github.com/chriscox/ash_multi_account/actions/workflows/ci.yml)

**Status: In Development — not yet published to Hex**

Multi-account linking and switching for [Ash](https://ash-hq.org/) apps. Let users link multiple accounts together and switch between them without re-authenticating — similar to Google/Apple's account switcher UX.

## Why?

Many apps need multi-account support: family accounts, work/personal separation, admin impersonation. Building this correctly requires careful session management, security considerations (session fixation, authorization checks), and LiveView integration. This library handles all of that.

There's nothing like this in the Ash ecosystem today.

## Features

- Session-scoped account linking (primary user + linked accounts)
- Secure account switching without re-authentication
- LiveView hook that resolves `current_user` and `primary_user` on every mount
- Default account switcher component with override system
- Configurable active-user checks, display fields, and max linked accounts
- Works alongside AshAuthentication's existing session management
- Router macros for link/switch routes

## Planned Consumer API

### 1. Add to your User resource

```elixir
defmodule MyApp.Accounts.User do
  use Ash.Resource,
    extensions: [AshAuthentication, AshMultiAccount]

  multi_account do
    linked_account_resource MyApp.Accounts.LinkedAccount
    active_check :status_id, :active
    display_fields [:full_name, :avatar_url]
    max_linked_accounts 5
  end
end
```

### 2. Define a LinkedAccount resource

```elixir
defmodule MyApp.Accounts.LinkedAccount do
  use Ash.Resource,
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

### 3. Add routes

```elixir
defmodule MyAppWeb.Router do
  use MyAppWeb, :router
  use AshMultiAccount.Phoenix.Router

  scope "/", MyAppWeb do
    pipe_through :browser
    multi_account_routes MultiAccountController, MyApp.Accounts.User
  end
end
```

### 4. Create a controller

```elixir
defmodule MyAppWeb.MultiAccountController do
  use MyAppWeb, :controller
  use AshMultiAccount.Phoenix.Controller

  def after_link_path(_conn), do: ~p"/dashboard"
  def after_switch_path(_conn), do: ~p"/dashboard"
  def sign_in_path(conn, primary_user_id), do: ~p"/sign-in?return_to=/link/p/#{primary_user_id}"
end
```

### 5. Add LiveView hook

```elixir
ash_authentication_live_session :my_session,
  on_mount: [
    {AshMultiAccount.Phoenix.LiveHook, :load_multi_account}
  ] do
  # routes...
end
```

### 6. Use the account switcher component

```elixir
<AshMultiAccount.Phoenix.Components.account_switcher
  current_user={@current_user}
  primary_user={@primary_user}
/>
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
