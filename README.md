# AshMultiAccount

[![CI](https://github.com/chriscox/ash_multi_account/actions/workflows/ci.yml/badge.svg)](https://github.com/chriscox/ash_multi_account/actions/workflows/ci.yml)

**Status: In Development — not yet published to Hex**

Multi-account linking and switching for [Ash](https://ash-hq.org/) apps. Let users link multiple accounts together and switch between them without re-authenticating — similar to Google/Apple's account switcher UX.

## Why?

Many apps need multi-account support: family accounts, work/personal separation, admin impersonation. Building this correctly requires careful session management, security considerations (session fixation, authorization checks), and LiveView integration. This library handles all of that.

There's nothing like this in the Ash ecosystem today.

## Features (Phase 2 — Core Extension)

- Session-scoped account linking (primary user + linked accounts)
- Configurable active-user checks, display fields, and max linked accounts
- Self-link prevention and max-account enforcement
- Activate/deactivate linked accounts with status tracking
- Works alongside AshAuthentication's existing session management

## Planned Features (Phase 3 — Phoenix Integration)

- LiveView hook that resolves `current_user` and `primary_user` on every mount
- Default account switcher component with override system
- Router macros for link/switch routes

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

### 3. Phoenix integration (Phase 3 — not yet implemented)

Routes, controllers, LiveView hooks, and account switcher components are
planned for the next phase. See the
[planning issue](https://github.com/chriscox/cano-phx/issues/124) for details.

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
