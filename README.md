# Ash Multi Account

[![CI](https://github.com/chriscox/ash_multi_account/actions/workflows/ci.yml/badge.svg)](https://github.com/chriscox/ash_multi_account/actions/workflows/ci.yml)

**Status: In Development — not yet published to Hex**

Multi-account linking and switching for [Ash](https://ash-hq.org/) apps. Let users link multiple accounts together and switch between them without re-authenticating — similar to Google/Apple's account switcher UX.

<!-- Screenshot: account switcher dropdown showing linked accounts -->
<!-- ![Account switcher dropdown](documentation/assets/images/account-switcher-dropdown.png) -->

## Why?

[AshAuthentication](https://hexdocs.pm/ash_authentication) and [AshAuthentication.Phoenix](https://hexdocs.pm/ash_authentication_phoenix) provide excellent single-user authentication — strategies, session management, and LiveView integration all work out of the box. But many apps need users to link and switch between multiple accounts: family accounts, work/personal separation, admin impersonation. That's a different problem entirely, requiring its own session management, security considerations (session fixation, authorization checks), and UI integration across both LiveView and controller-rendered pages.

Ash Multi Account picks up where AshAuthentication leaves off, adding multi-account linking and switching as a natural extension of the same Ash ecosystem.

## Features

- Session-scoped account linking (primary user + linked accounts)
- Configurable active-user checks, display fields, and max linked accounts
- Self-link prevention and max-account enforcement
- Activate/deactivate linked accounts with status tracking
- Works with **any** AshAuthentication strategy (password, OAuth, magic links, etc.)
- Phoenix controller mixin with link/switch actions and session regeneration
- **Works with both LiveView and controller-rendered pages:**
  - LiveView hook resolves `current_user` and `primary_user` on every mount
  - `LoadMultiAccount` plug resolves the same assigns for controller pages
- Slot-based account switcher component — works identically in both contexts
- Router macros for link/switch routes
- Automatic return-to-origin after linking and switching (stays on current page)
- Session token plug for automatic token management

## Built On

Ash Multi Account is an extension for the [Ash Framework](https://ash-hq.org/) ecosystem. It builds on:

- **[Ash](https://hexdocs.pm/ash)** — resources, actions, and the DSL extension system (Spark)
- **[AshAuthentication](https://hexdocs.pm/ash_authentication)** — user authentication and session management
- **[Phoenix](https://hexdocs.pm/phoenix)** / **[Phoenix LiveView](https://hexdocs.pm/phoenix_live_view)** — controller mixin, LiveView hook, router macros, and the account switcher component

Works with **any Ash data layer** (Postgres, SQLite, ETS, etc.) and **any AshAuthentication strategy** (password, OAuth, magic links, etc.).

## Quick Look

Add two extensions to your resources — the transformer generates the full schema:

```elixir
# User resource
defmodule MyApp.Accounts.User do
  use Ash.Resource,
    extensions: [AshMultiAccount]

  multi_account do
    linked_account_resource MyApp.Accounts.LinkedAccount
    active_check {:status, :active}
    display_fields [:name, :avatar_url]
    max_linked_accounts 5
  end
end

# LinkedAccount resource — schema generated automatically
defmodule MyApp.Accounts.LinkedAccount do
  use Ash.Resource,
    extensions: [AshMultiAccount.LinkedAccount]

  multi_account do
    user_resource MyApp.Accounts.User
  end
end
```

Then wire up the Phoenix integration:

```elixir
# Router pipeline
plug AshMultiAccount.Phoenix.Plug
plug AshMultiAccount.Phoenix.LoadMultiAccount, user_resource: MyApp.Accounts.User

# Routes
use AshMultiAccount.Phoenix.Router
multi_account_routes MultiAccountController, MyApp.Accounts.User

# Multi-account controller
use AshMultiAccount.Phoenix.Controller, user_resource: MyApp.Accounts.User

# LiveView hook (must come after AshAuthentication's hook)
on_mount: [
  {AshAuthentication.Phoenix.LiveSession, :load_from_session},
  {AshMultiAccount.Phoenix.LiveHook, {:load_multi_account, MyApp.Accounts.User}}
]
```

The `LoadMultiAccount` plug handles controller-rendered pages, while the `LiveHook` handles LiveView pages. Both resolve the same `@current_user` and `@primary_user` assigns from the same session state, and can coexist in the same app.

See the [Getting Started guide](documentation/tutorials/getting-started.md) for the full step-by-step walkthrough.

## Documentation

- **[Getting Started](documentation/tutorials/getting-started.md)** — step-by-step setup guide
- **[How It Works](documentation/topics/how-it-works.md)** — architecture, data model, and flows
- **[Phoenix Integration](documentation/topics/phoenix-integration.md)** — plug, controller, router, LiveView hook, components
- **[Customizing the Account Switcher](documentation/topics/customizing-the-account-switcher.md)** — slot data, styling patterns, examples
- **[Testing](documentation/topics/testing.md)** — ETS test setup, testing flows and Phoenix integration
- **DSL Reference** — auto-generated from the Spark DSL schemas (run `mix docs`)

## Demo App

A complete demo Phoenix app lives in `example/demo/`. It uses password authentication with ETS (no external dependencies — just `mix setup && mix phx.server`).

The demo includes two pages to demonstrate that multi-account works with both rendering approaches:

- **LiveView Page** (`/`) — uses `AshMultiAccount.Phoenix.LiveHook` to resolve assigns via `on_mount`
- **Controller Page** (`/controller`) — uses `AshMultiAccount.Phoenix.LoadMultiAccount` plug to resolve assigns in the router pipeline

Both pages show the same user data, account switcher, and multi-account status — proving the library works identically in both contexts. Switch between them using the tabs at the top of each page.

See the [demo README](example/demo/README.md) for setup instructions and a walkthrough.

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

MIT — see `LICENSE`.
