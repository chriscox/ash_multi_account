# AshMultiAccount

[![CI](https://github.com/chriscox/ash_multi_account/actions/workflows/ci.yml/badge.svg)](https://github.com/chriscox/ash_multi_account/actions/workflows/ci.yml)

**Status: In Development — not yet published to Hex**

Multi-account linking and switching for [Ash](https://ash-hq.org/) apps. Let users link multiple accounts together and switch between them without re-authenticating — similar to Google/Apple's account switcher UX.

<!-- Screenshot: account switcher dropdown showing linked accounts -->
<!-- ![Account switcher dropdown](documentation/assets/images/account-switcher-dropdown.png) -->

## Why?

Many apps need multi-account support: family accounts, work/personal separation, admin impersonation. Building this correctly requires careful session management, security considerations (session fixation, authorization checks), and LiveView integration. This library handles all of that.

There's nothing like this in the Ash ecosystem today.

## Features

- Session-scoped account linking (primary user + linked accounts)
- Configurable active-user checks, display fields, and max linked accounts
- Self-link prevention and max-account enforcement
- Activate/deactivate linked accounts with status tracking
- Works with **any** AshAuthentication strategy (password, OAuth, magic links, etc.)
- Phoenix controller mixin with link/switch actions and session regeneration
- LiveView hook that resolves `current_user` and `primary_user` on every mount
- Slot-based account switcher component — you control all HTML and styling
- Router macros for link/switch routes
- Session token plug for automatic token management

## Requirements

| Dependency | Version |
|------------|---------|
| Elixir | >= 1.17 |
| Ash | ~> 3.0 |
| AshAuthentication | ~> 4.0 |
| Phoenix | ~> 1.7 |
| Phoenix LiveView | ~> 1.0 |

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
# Router
use AshMultiAccount.Phoenix.Router
plug AshMultiAccount.Phoenix.Plug
multi_account_routes MultiAccountController, MyApp.Accounts.User

# Controller
use AshMultiAccount.Phoenix.Controller, user_resource: MyApp.Accounts.User

# LiveView hook
on_mount: [{AshMultiAccount.Phoenix.LiveHook, {:load_multi_account, MyApp.Accounts.User}}]
```

See the [Getting Started guide](documentation/tutorials/getting-started.md) for the full step-by-step walkthrough.

## Documentation

- **[Getting Started](documentation/tutorials/getting-started.md)** — step-by-step setup guide
- **[How It Works](documentation/topics/how-it-works.md)** — architecture, data model, and flows
- **[Phoenix Integration](documentation/topics/phoenix-integration.md)** — plug, controller, router, LiveView hook, components
- **[Customizing the Account Switcher](documentation/topics/customizing-the-account-switcher.md)** — slot data, styling patterns, examples
- **[Testing](documentation/topics/testing.md)** — ETS test setup, testing flows and Phoenix integration
- **DSL Reference** — auto-generated from the Spark DSL schemas (run `mix docs`)

## Demo App

A complete demo Phoenix app lives in `example/demo/`. It uses password authentication with Postgres and exercises every integration point — auth, linking, switching, the account switcher component, and the LiveView hook.

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
