# Customizing the Account Switcher

The `AshMultiAccount.Phoenix.Components.account_switcher` component is intentionally unstyled — it provides data and URLs through slots, and you control all HTML and CSS. This topic covers common customization patterns.

## Basic Structure

The component accepts two slots:

- **`:account`** — rendered once per account (primary + all linked). Receives account data via `:let`.
- **`:add_account`** — rendered once at the end. Receives the add-account URL via `:let`.

```heex
<AshMultiAccount.Phoenix.Components.account_switcher
  current_user={@current_user}
  primary_user={@primary_user}
>
  <:account :let={account}>
    <!-- rendered for each account -->
  </:account>
  <:add_account :let={url}>
    <!-- rendered once -->
  </:add_account>
</AshMultiAccount.Phoenix.Components.account_switcher>
```

## Slot Data Reference

Each `:account` slot receives a map:

```elixir
%{
  user: %MyApp.Accounts.User{...},  # user struct with display_fields loaded
  current?: true | false,            # is this the active account?
  primary?: true | false,            # is this the primary account?
  switch_url: "/link/switch_to/abc"  # URL to switch to this account
}
```

The `:add_account` slot receives a URL string like `"/sign-in?return_to=%2Flink%2Fp%2Fabc-123"`.

## Minimal Example

A simple list with no framework-specific styling:

```heex
<AshMultiAccount.Phoenix.Components.account_switcher
  current_user={@current_user}
  primary_user={@primary_user}
>
  <:account :let={account}>
    <div>
      <span :if={account.current?}><strong>{account.user.name}</strong> (you)</span>
      <.link :if={!account.current?} href={account.switch_url}>
        {account.user.name} — Switch
      </.link>
    </div>
  </:account>
  <:add_account :let={url}>
    <.link href={url}>+ Add another account</.link>
  </:add_account>
</AshMultiAccount.Phoenix.Components.account_switcher>
```

## Dropdown Menu Example

A dropdown menu using Tailwind CSS (adapted from the demo app):

```heex
<div class="dropdown dropdown-end">
  <div tabindex="0" role="button" class="btn btn-ghost gap-2">
    <span>{@current_user.email}</span>
  </div>
  <ul tabindex="0" class="dropdown-content menu bg-base-100 rounded-box shadow-lg border w-72 mt-2">
    <.account_menu current_user={@current_user} primary_user={@primary_user} />
    <hr class="my-1" />
    <li>
      <.link href={~p"/sign-out"}>Sign out</.link>
    </li>
  </ul>
</div>
```

With a helper component:

```elixir
defp account_menu(assigns) do
  ~H"""
  <AshMultiAccount.Phoenix.Components.account_switcher
    current_user={@current_user}
    primary_user={@primary_user}
  >
    <:account :let={account}>
      <%= if account.current? do %>
        <li class="pointer-events-none">
          <div class="flex items-center gap-3">
            <div class="flex flex-col">
              <span class="text-sm font-medium">{account.user.name || account.user.email}</span>
              <span class="text-xs opacity-50">{account.user.email}</span>
            </div>
            <span class="badge badge-success badge-xs ml-auto">Active</span>
          </div>
        </li>
      <% else %>
        <li>
          <.link href={account.switch_url} class="flex items-center gap-3">
            <div class="flex flex-col">
              <span class="text-sm">{account.user.name || account.user.email}</span>
              <span class="text-xs opacity-50">{account.user.email}</span>
            </div>
          </.link>
        </li>
      <% end %>
      <hr class="my-0.5" />
    </:account>

    <:add_account :let={url}>
      <li>
        <.link href={url}>Add another account</.link>
      </li>
    </:add_account>
  </AshMultiAccount.Phoenix.Components.account_switcher>
  """
end
```

## Custom Paths

Override the default URL paths via component attributes:

```heex
<AshMultiAccount.Phoenix.Components.account_switcher
  current_user={@current_user}
  primary_user={@primary_user}
  switch_path="/accounts/switch"
  sign_in_path="/auth/login"
  link_path="/accounts/link"
>
  ...
</AshMultiAccount.Phoenix.Components.account_switcher>
```

These must match the paths defined in your router's `multi_account_routes/3` call:

```elixir
multi_account_routes MultiAccountController, MyApp.Accounts.User,
  link_path: "/accounts/link/:primary_user_id",
  switch_path: "/accounts/switch/:user_id"
```

## Display Fields

The `display_fields` option on your User resource controls which fields are loaded and available on `account.user` in the slot:

```elixir
multi_account do
  display_fields [:name, :email, :avatar_url]
end
```

These fields are loaded by both the LiveView hook and the `get_linked_accounts` preparation, so they're available when rendering the switcher.

## Showing Account Status

Use `account.primary?` to indicate which account owns the session:

```heex
<:account :let={account}>
  <div class="flex items-center gap-2">
    <span>{account.user.name}</span>
    <span :if={account.primary?} class="text-xs text-gray-400">(primary)</span>
    <span :if={account.current?} class="text-xs text-green-600">(active)</span>
  </div>
</:account>
```

## Wrapping in Your Own Component

For reuse across layouts, wrap the switcher in a function component:

```elixir
defmodule MyAppWeb.Components.AccountSwitcher do
  use Phoenix.Component

  attr :current_user, :map, required: true
  attr :primary_user, :map, default: nil

  def account_switcher(assigns) do
    ~H"""
    <div class="account-switcher">
      <AshMultiAccount.Phoenix.Components.account_switcher
        current_user={@current_user}
        primary_user={@primary_user}
      >
        <:account :let={account}>
          <%!-- your custom rendering --%>
        </:account>
        <:add_account :let={url}>
          <%!-- your custom rendering --%>
        </:add_account>
      </AshMultiAccount.Phoenix.Components.account_switcher>
    </div>
    """
  end
end
```

Then use it anywhere:

```heex
<MyAppWeb.Components.AccountSwitcher.account_switcher
  current_user={@current_user}
  primary_user={@primary_user}
/>
```

## Single-Account Mode

When `@primary_user` is `nil` (no multi-account session), the component renders:
- One `:account` entry for just the current user (with `current?: true`, `primary?: true`)
- The `:add_account` slot with a link to start the linking flow

This means the same component works seamlessly in both single and multi-account modes.
