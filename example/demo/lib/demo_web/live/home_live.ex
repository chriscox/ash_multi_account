defmodule DemoWeb.HomeLive do
  use DemoWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <div class="bg-base-100 shadow-sm">
      <div class="navbar max-w-2xl mx-auto px-4">
        <div class="flex-1">
          <a href="/" class="text-lg font-semibold">Ash Multi Account Demo</a>
        </div>
        <div :if={@current_user} class="flex-none">
          <div class="dropdown dropdown-end">
            <div tabindex="0" role="button" class="btn btn-ghost gap-2">
              <span class="hero-user-circle-solid w-6 h-6" />
              <span class="text-sm">{@current_user.email}</span>
            </div>
            <ul
              tabindex="0"
              class="dropdown-content menu bg-base-100 rounded-box z-10 w-fit shadow-lg border border-base-200 mt-2"
            >
              <.account_menu_items
                current_user={@current_user}
                primary_user={@primary_user}
              />
              <hr class="border-base-300 my-0.5" />
              <li>
                <.link href={~p"/sign-out"} class="text-error">
                  <span class="hero-arrow-right-on-rectangle-solid w-5 h-5" /> Sign out
                </.link>
              </li>
            </ul>
          </div>
        </div>
      </div>
    </div>

    <main class="max-w-2xl mx-auto py-8 px-4">
      <%= if @current_user do %>
        <%!-- Page tabs --%>
        <div class="inline-flex rounded-lg bg-base-200 p-1 mb-6">
          <span class="rounded-md bg-base-100 px-4 py-2 text-sm font-medium shadow-sm">
            LiveView Page
          </span>
          <.link
            href={~p"/controller"}
            class="rounded-md px-4 py-2 text-sm text-base-content/60 hover:text-base-content transition-colors"
          >
            Controller Page
          </.link>
        </div>

        <%!-- Page info + multi-account status --%>
        <div class="mb-6">
          <div class="flex items-center gap-2 mb-2">
            <span class="badge badge-primary badge-sm">LiveView</span>
            <h1 class="text-xl font-semibold">LiveView Page</h1>
          </div>
          <p class="text-sm text-base-content/60 mb-3">
            This page is rendered by Phoenix LiveView. Multi-account assigns
            (<code class="text-xs bg-base-200 px-1 rounded">@current_user</code> and <code class="text-xs bg-base-200 px-1 rounded">@primary_user</code>) are resolved by the
            <code class="text-xs bg-base-200 px-1 rounded">AshMultiAccount.Phoenix.LiveHook</code>
            on every mount via the <code class="text-xs bg-base-200 px-1 rounded">on_mount</code>
            callback.
          </p>
          <%= if @primary_user do %>
            <div class="flex items-center gap-2 text-success text-sm">
              <span class="hero-check-circle-solid w-4 h-4 shrink-0" />
              <span>
                Multi-account active &mdash; primary: <strong>{@primary_user.email}</strong>
              </span>
            </div>
          <% else %>
            <div class="flex items-center gap-2 text-base-content/40 text-sm">
              <span class="hero-minus-circle w-4 h-4 shrink-0" />
              <span>Single-account mode</span>
            </div>
          <% end %>
        </div>

        <div class="card bg-base-100 shadow-sm mb-6">
          <div class="card-body">
            <h2 class="card-title">Current User</h2>
            <dl class="space-y-2">
              <div class="flex gap-2">
                <dt class="font-medium text-base-content/60">Email:</dt>
                <dd>{@current_user.email}</dd>
              </div>
              <div class="flex gap-2">
                <dt class="font-medium text-base-content/60">Name:</dt>
                <dd>{@current_user.name || "Not set"}</dd>
              </div>
              <div class="flex gap-2">
                <dt class="font-medium text-base-content/60">Status:</dt>
                <dd>{@current_user.status}</dd>
              </div>
              <div class="flex gap-2">
                <dt class="font-medium text-base-content/60">ID:</dt>
                <dd class="font-mono text-sm">{@current_user.id}</dd>
              </div>
            </dl>
          </div>
        </div>

        <div class="card bg-base-100 shadow-sm mb-6">
          <div class="card-body">
            <h2 class="card-title text-base">How to Try It</h2>
            <ol class="list-decimal list-inside space-y-2 text-sm text-base-content/70">
              <li>
                Click the user menu above and select <strong>Add another account</strong>.
              </li>
              <li>
                Register or sign in with a different email &mdash; the accounts will be linked automatically.
              </li>
              <li>
                Open the user menu again to switch between your linked accounts.
              </li>
              <li>
                Switch to the <strong>Controller Page</strong>
                tab to see the same data resolved by a plug instead of a hook.
              </li>
            </ol>
          </div>
        </div>
      <% else %>
        <div class="card bg-base-100 shadow-sm">
          <div class="card-body items-center text-center">
            <h2 class="card-title">Welcome to Ash Multi Account</h2>
            <p class="text-base-content/60 mb-2">
              This demo shows multi-account linking and switching powered by the
              <code class="text-sm">ash_multi_account</code>
              library.
            </p>
            <p class="text-base-content/60 mb-4">
              Register two accounts, then link and switch between them.
            </p>
            <div class="card-actions">
              <.link href={~p"/register"} class="btn btn-primary">Register</.link>
              <.link href={~p"/sign-in"} class="btn btn-ghost">Sign In</.link>
            </div>
          </div>
        </div>
      <% end %>
    </main>
    """
  end

  defp account_menu_items(assigns) do
    ~H"""
    <AshMultiAccount.Phoenix.Components.account_switcher
      current_user={@current_user}
      primary_user={@primary_user}
    >
      <:account :let={account}>
        <%= if account.current? do %>
          <li class="pointer-events-none">
            <div class="flex items-center gap-3">
              <span class="hero-user-circle-solid w-5 h-5 shrink-0" />
              <div class="flex flex-col min-w-0">
                <span class="text-sm font-medium truncate">
                  {account.user.name || account.user.email}
                </span>
                <span class="text-xs text-base-content/50 truncate">{account.user.email}</span>
              </div>
              <span class="badge badge-success badge-xs whitespace-nowrap ml-auto">Signed in</span>
            </div>
          </li>
        <% else %>
          <li>
            <.link href={account.switch_url} class="flex items-center gap-3">
              <span class="hero-user-circle w-5 h-5 opacity-60 shrink-0" />
              <div class="flex flex-col min-w-0">
                <span class="text-sm truncate">{account.user.name || account.user.email}</span>
                <span class="text-xs text-base-content/50 truncate">{account.user.email}</span>
              </div>
            </.link>
          </li>
        <% end %>
        <hr class="border-base-300 my-0.5" />
      </:account>

      <:add_account :let={url}>
        <li>
          <.link href={url} class="whitespace-nowrap">
            <span class="hero-user-plus w-5 h-5 opacity-60" /> Add another account
          </.link>
        </li>
      </:add_account>
    </AshMultiAccount.Phoenix.Components.account_switcher>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end
end
