# Phoenix Integration

AshMultiAccount provides seven Phoenix modules that handle session management, routing, controller actions, LiveView state, controller state, and UI components. This topic covers each module in detail.

## Plug

`AshMultiAccount.Phoenix.Plug` ensures a session token UUID exists before any multi-account routes are hit.

```elixir
pipeline :browser do
  plug :fetch_session
  plug :fetch_flash
  # ... other plugs ...
  plug AshMultiAccount.Phoenix.Plug
end
```

The plug generates a UUID via `Ash.UUID.generate()` and stores it in the `"session_token"` session key. If a token already exists, the plug is a no-op. This runs on every request in the pipeline, so the token is always available when the controller needs it.

## LoadMultiAccount Plug

`AshMultiAccount.Phoenix.LoadMultiAccount` resolves `@current_user` and `@primary_user` assigns for controller-rendered pages. It mirrors the logic of the LiveView hook but operates on `Plug.Conn`.

```elixir
pipeline :browser do
  plug :fetch_session
  # ... other plugs ...
  plug AshMultiAccount.Phoenix.Plug
  plug AshMultiAccount.Phoenix.LoadMultiAccount, user_resource: MyApp.Accounts.User
end
```

### Configuration

The plug requires a `:user_resource` option — it raises `ArgumentError` at compile time if omitted. It must run after `:fetch_session` and `AshMultiAccount.Phoenix.Plug` in the pipeline.

### Multi-Account Mode

When `multi_account_session?` is true:

1. Loads the primary user via the `get_user_with_linked_accounts` action
2. Validates the primary user passes `active_check`
3. Resolves the current user from the session (overriding any JWT-based assign)
4. Assigns both `@current_user` and `@primary_user`

### Standard Mode

When no multi-account session exists:

1. Gets `current_user` from conn assigns or the session
2. Loads configured `display_fields`
3. Sets `@primary_user` to `nil`

### Error Handling

When the primary user is **not found** or **not active** (e.g., stale session after data reset), the plug clears the multi-account session keys and falls back to standard mode — resolving the current user from `conn.assigns` or the session. For unexpected errors (e.g., database failures), the plug assigns `nil` gracefully and lets the controller decide how to respond.

### When to Use LoadMultiAccount vs LiveHook

- Use **LoadMultiAccount** for controller-rendered pages (`Plug.Conn` pipeline)
- Use **LiveHook** for LiveView pages (`on_mount` hook)
- Both can coexist in the same app — they read the same session keys

## Session Helpers

`AshMultiAccount.Phoenix.Session` provides read/write functions for the three multi-account session keys. All read functions accept both `Plug.Conn` (controllers) and raw session maps (LiveView hooks). Write functions require `Plug.Conn`.

Key functions:

- `get_user_id/1` / `put_user_id/3` — reads/writes the `"user"` subject string
- `get_primary_user_id/1` / `put_primary_user_id/2` — reads/writes `"primary_user_id"`
- `get_session_token/1` / `put_session_token/2` — reads/writes `"session_token"`
- `put_multi_account_session/3` — atomically sets both `"primary_user_id"` and `"session_token"`
- `multi_account_session?/1` — returns `true` if both keys are present
- `clear_multi_account_session/1` — removes multi-account keys (keeps `"user"`)

The `"user"` key uses AshAuthentication's subject format: `"<short_name>?id=<UUID>"`. The `put_user_id/3` function constructs this format; `get_user_id/1` parses it back to a plain UUID. The default short name is `"user"` — pass a third argument if your resource uses a different one.

## Router

`AshMultiAccount.Phoenix.Router` provides the `multi_account_routes/3` macro.

```elixir
use AshMultiAccount.Phoenix.Router

scope "/", MyAppWeb do
  pipe_through :browser
  multi_account_routes MultiAccountController, MyApp.Accounts.User
end
```

This generates two GET routes:

| Route | Action | Purpose |
|-------|--------|---------|
| `/link/p/:primary_user_id` | `:link_account` | Initiate or complete account linking |
| `/link/switch_to/:user_id` | `:switch_to_account` | Switch to a linked account |

Custom paths are supported:

```elixir
multi_account_routes MultiAccountController, MyApp.Accounts.User,
  link_path: "/accounts/link/:primary_user_id",
  switch_path: "/accounts/switch/:user_id"
```

## Controller

`AshMultiAccount.Phoenix.Controller` is a macro that injects `link_account/2` and `switch_to_account/2` into your controller.

```elixir
defmodule MyAppWeb.MultiAccountController do
  use MyAppWeb, :controller
  use AshMultiAccount.Phoenix.Controller,
    user_resource: MyApp.Accounts.User
end
```

### Overridable Functions

| Function | Default | Purpose |
|----------|---------|---------|
| `after_link_path/1` | Origin page (from session) or `"/"` | Redirect after successful link |
| `after_switch_path/1` | Origin page (from Referer) or `"/"` | Redirect after successful switch |
| `sign_in_path/2` | `"/sign-in?return_to=/link/p/:id"` | Where to send unauthenticated users |
| `sign_out_path/1` | `"/sign-out"` | Where to send users on fatal errors |

By default, both `after_link_path/1` and `after_switch_path/1` return the user to the page they were on when they started the action. For linking, the origin page is saved in the session at the start of the multi-step flow. For switching, the origin is read from the HTTP Referer header. Both fall back to `"/"` if the origin cannot be determined.

### link_account/2

Handles three cases:

1. **No authenticated user** — redirects to sign-in with a flash error
2. **Primary user matches current user** — sets up the multi-account session and redirects to sign-in (so the user can authenticate another account)
3. **Different user** — creates a LinkedAccount record tying the current user to the primary, then redirects to `after_link_path`

### switch_to_account/2

Validates the switch is authorized, then:

1. Renews the session ID (`configure_session(renew: true)`) for session fixation protection
2. Writes the target user's ID to the session
3. Preserves the multi-account session keys
4. Redirects to `after_switch_path`

Validation checks:
- Target user exists and passes `active_check`
- Both the current user and target user belong to the same linked account group

## LiveView Hook

`AshMultiAccount.Phoenix.LiveHook` resolves `@current_user` and `@primary_user` on every LiveView mount.

```elixir
live_session :authenticated,
  on_mount: [
    {AshAuthentication.Phoenix.LiveSession, :load_from_session},
    {AshMultiAccount.Phoenix.LiveHook, {:load_multi_account, MyApp.Accounts.User}}
  ] do
  # ...
end
```

### Multi-Account Mode

When `multi_account_session?` is true (both `"primary_user_id"` and `"session_token"` are in the session):

1. Loads the primary user via the `get_user_with_linked_accounts` action
2. Validates the primary user passes `active_check`
3. Resolves the current user from the session's `"user"` key (not socket assigns, since AshAuthentication's JWT can't reflect switches)
4. Assigns both `@current_user` and `@primary_user`

### Standard Mode

When no multi-account session exists:

1. Gets `current_user` from socket assigns or the session
2. Loads configured `display_fields`
3. Sets `@primary_user` to `nil`

### Error Handling

- If the primary user is **not found** (e.g., stale session after data reset), the hook falls back to standard mode — resolving the current user from the session or socket assigns without multi-account context
- If the primary user is **not active**, the hook halts with a flash error and redirects to `/sign-out`
- If loading fails with an unexpected error, the hook halts with a generic error message

## Components

`AshMultiAccount.Phoenix.Components` provides a slot-based account switcher that imposes no styling.

```heex
<AshMultiAccount.Phoenix.Components.account_switcher
  current_user={@current_user}
  primary_user={@primary_user}
>
  <:account :let={account}>
    <div class={if account.current?, do: "font-bold", else: ""}>
      <.link :if={!account.current?} href={account.switch_url}>
        {account.user.name}
      </.link>
      <span :if={account.current?}>{account.user.name}</span>
      <span :if={account.primary?}>(primary)</span>
    </div>
  </:account>
  <:add_account :let={url}>
    <.link href={url}>+ Add another account</.link>
  </:add_account>
</AshMultiAccount.Phoenix.Components.account_switcher>
```

### Attributes

| Attribute | Type | Default | Description |
|-----------|------|---------|-------------|
| `current_user` | map | required | Currently active user struct |
| `primary_user` | map | `nil` | Primary account owner (nil = standard mode) |
| `switch_path` | string | `"/link/switch_to"` | Base path for switch URLs |
| `sign_in_path` | string | `"/sign-in"` | Sign-in path for add-account URL |
| `link_path` | string | `"/link/p"` | Link path for add-account URL |

### Slot Data

Each `:account` slot receives a map with:

| Key | Type | Description |
|-----|------|-------------|
| `user` | struct | The user struct with display fields loaded |
| `current?` | boolean | Whether this is the currently active user |
| `primary?` | boolean | Whether this is the primary account |
| `switch_url` | string | URL to switch to this account |

The `:add_account` slot receives the URL string for initiating a new link (includes `return_to` parameter).

### Single-Account Mode

When `primary_user` is `nil`, the component shows just the current user and the "add account" link. The first link click establishes the multi-account session.
