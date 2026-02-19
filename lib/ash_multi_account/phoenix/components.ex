defmodule AshMultiAccount.Phoenix.Components do
  @moduledoc """
  Slot-based account switcher component for multi-account UIs.

  Provides data and URLs to consumer-supplied slots — no styling or HTML structure
  is imposed. The consumer controls all rendering.

  ## Requirements

  The `current_user` struct must belong to a resource with the `AshMultiAccount`
  extension applied. The `primary_user` (when provided) should be loaded via the
  `get_user_with_linked_accounts` action so linked account data is available.

  ## Usage

      <AshMultiAccount.Phoenix.Components.account_switcher
        current_user={@current_user}
        primary_user={@primary_user}
      >
        <:account :let={account}>
          <.link :if={!account.current?} href={account.switch_url}>
            {account.user.name}
          </.link>
          <span :if={account.current?}>
            {account.user.name} (current)
          </span>
        </:account>

        <:add_account :let={url}>
          <.link href={url}>Add another account</.link>
        </:add_account>
      </AshMultiAccount.Phoenix.Components.account_switcher>

  ## Attributes

  - `current_user` (required) — the currently active user struct
  - `primary_user` — the primary account owner struct, or `nil` in standard mode
  - `switch_path` — base path for switch URLs (default: `"/link/switch_to"`)
  - `sign_in_path` — sign-in path for add-account URL (default: `"/sign-in"`)
  - `link_path` — link path for add-account URL (default: `"/link/p"`)

  ## Slot Data

  Each `:account` slot receives a map with:

  - `user` — the user struct
  - `current?` — whether this is the currently active user
  - `primary?` — whether this is the primary account
  - `switch_url` — URL to switch to this account

  The `:add_account` slot receives the URL to initiate linking a new account.
  """

  use Phoenix.Component

  require Logger

  attr :current_user, :map, required: true
  attr :primary_user, :map, default: nil
  attr :switch_path, :string, default: "/link/switch_to"
  attr :sign_in_path, :string, default: "/sign-in"
  attr :link_path, :string, default: "/link/p"

  slot :account, doc: "Rendered for each account. Receives account map via :let."
  slot :add_account, doc: "Rendered once with the add-account URL via :let."

  def account_switcher(assigns) do
    calc_name = linked_accounts_calculation_name(assigns.current_user)
    linked_accounts = get_linked_accounts(assigns.primary_user, calc_name)
    primary = assigns.primary_user || assigns.current_user

    accounts =
      build_account_list(
        primary,
        linked_accounts,
        assigns.current_user,
        assigns.switch_path
      )

    return_to = "#{assigns.link_path}/#{primary.id}"
    add_url = "#{assigns.sign_in_path}?#{URI.encode_query(%{"return_to" => return_to})}"

    assigns =
      assigns
      |> assign(:accounts, accounts)
      |> assign(:add_url, add_url)

    ~H"""
    <%= for account <- @accounts do %>
      {render_slot(@account, account)}
    <% end %>
    {render_slot(@add_account, @add_url)}
    """
  end

  defp build_account_list(primary, linked_accounts, current_user, switch_path) do
    primary_entry = %{
      user: primary,
      current?: primary.id == current_user.id,
      primary?: true,
      switch_url: "#{switch_path}/#{primary.id}"
    }

    linked_entries =
      Enum.map(linked_accounts, fn account ->
        linked_user = require_linked_user!(account)

        %{
          user: linked_user,
          current?: account.linked_user_id == current_user.id,
          primary?: false,
          switch_url: "#{switch_path}/#{account.linked_user_id}"
        }
      end)

    [primary_entry | linked_entries]
  end

  defp require_linked_user!(%{linked_user: %Ash.NotLoaded{}}) do
    raise ArgumentError,
          "AshMultiAccount: :linked_user relationship not loaded on linked account. " <>
            "Ensure linked accounts are loaded with the :linked_user relationship."
  end

  defp require_linked_user!(%{linked_user: nil, id: id}) do
    raise ArgumentError,
          "AshMultiAccount: :linked_user is nil on linked account #{inspect(id)}."
  end

  defp require_linked_user!(%{linked_user: user}), do: user

  defp linked_accounts_calculation_name(user) do
    AshMultiAccount.Helpers.fetch_config!(
      AshMultiAccount.Info.multi_account_linked_accounts_calculation_name(user.__struct__),
      :linked_accounts_calculation_name
    )
  end

  defp get_linked_accounts(nil, _calc_name), do: []

  defp get_linked_accounts(primary_user, calc_name) do
    case Map.fetch(primary_user, calc_name) do
      {:ok, %Ash.NotLoaded{}} ->
        Logger.error(
          "AshMultiAccount: Calculation #{inspect(calc_name)} is present but not loaded " <>
            "on primary user. Ensure the user is loaded via the " <>
            "get_user_with_linked_accounts action."
        )

        []

      {:ok, accounts} ->
        accounts

      :error ->
        Logger.error(
          "AshMultiAccount: Calculation #{inspect(calc_name)} not found on primary user struct. " <>
            "Ensure the user resource has the AshMultiAccount extension applied and " <>
            "the user is loaded via the get_user_with_linked_accounts action."
        )

        []
    end
  end
end
