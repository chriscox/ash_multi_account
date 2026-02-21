# Ash Multi Account

[![CI](https://github.com/chriscox/ash_multi_account/actions/workflows/ci.yml/badge.svg)](https://github.com/chriscox/ash_multi_account/actions/workflows/ci.yml) [![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT) [![Hex version badge](https://img.shields.io/hexpm/v/ash_multi_account.svg)](https://hex.pm/packages/ash_multi_account) [![Hexdocs badge](https://img.shields.io/badge/docs-hexdocs-purple)](https://hexdocs.pm/ash_multi_account)

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

Ash Multi Account is an extension for the [Ash Framework](https://ash-hq.org/) ecosystem.

**Required** — pulled in automatically as dependencies:

- **[Ash](https://hexdocs.pm/ash)** — resources, actions, and the DSL extension system (Spark)
- **[AshAuthentication](https://hexdocs.pm/ash_authentication)** — user authentication and session management
- **[Phoenix](https://hexdocs.pm/phoenix)** — controller mixin, router macros, plugs, and session management

**Also needed** (not pulled in transitively):

- **[AshAuthentication Phoenix](https://hexdocs.pm/ash_authentication_phoenix)** — provides the auth controller (`AshAuthentication.Phoenix.Controller`) used for sign-in callbacks, and `AshAuthentication.Phoenix.LiveSession` for LiveView apps. Most Phoenix + AshAuthentication apps already have this.
- **[Phoenix LiveView](https://hexdocs.pm/phoenix_live_view)** — only needed if using the LiveView hook (`AshMultiAccount.Phoenix.LiveHook`) or account switcher component

Works with **any Ash data layer** (Postgres, SQLite, ETS, etc.) and **any AshAuthentication strategy** (password, OAuth, magic links, etc.).

## Quick Look

Add two extensions to your resources — the transformer generates the full schema:

```elixir
# User resource — add AshMultiAccount alongside AshAuthentication
defmodule MyApp.Accounts.User do
  use Ash.Resource,
    extensions: [AshAuthentication, AshMultiAccount]

  multi_account do
    linked_account_resource MyApp.Accounts.LinkedAccount
    active_check {:status, :active}
    display_fields [:name, :avatar_url]
    max_linked_accounts 5
  end
end

# LinkedAccount resource — attributes, relationships, and actions generated automatically
defmodule MyApp.Accounts.LinkedAccount do
  use Ash.Resource,
    extensions: [AshMultiAccount.LinkedAccount]

  multi_account do
    user_resource MyApp.Accounts.User
  end
end
```

The Phoenix integration provides plugs, controllers, router macros, and a LiveView hook — all resolving the same `@current_user` and `@primary_user` assigns. See the [Getting Started guide](documentation/tutorials/getting-started.md) for the full walkthrough.

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

```elixir
# mix.exs
{:ash_multi_account, "~> 0.1.0"}
```

The recommended way to get started is with the Igniter installer, which automates resource setup, domain registration, controller creation, and router configuration:

```sh
mix igniter.install ash_multi_account
```

See the [Getting Started guide](documentation/tutorials/getting-started.md) for manual setup or additional options.

## License

MIT — see `LICENSE`.

---

AshMultiAccount is an independent project by [Chris Cox](https://github.com/chriscox), not affiliated with or maintained by the Ash Framework team. Built as a contribution back to the Phoenix and Ash community that has given me so much.
