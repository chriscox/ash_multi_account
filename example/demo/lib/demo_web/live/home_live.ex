defmodule DemoWeb.HomeLive do
  use DemoWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <div class="navbar bg-base-100 shadow-sm">
      <div class="flex-1">
        <a href="/" class="btn btn-ghost text-lg">AshMultiAccount Demo</a>
      </div>
      <div :if={@current_user} class="flex-none">
        <.link href={~p"/sign-out"} class="btn btn-ghost btn-sm text-error">
          Sign Out
        </.link>
      </div>
    </div>

    <main class="max-w-2xl mx-auto py-8 px-4">
      <%= if @current_user do %>
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
            <h2 class="card-title">Multi-Account Status</h2>
            <%= if @primary_user do %>
              <p class="text-success">Multi-account session active</p>
              <dl class="space-y-2">
                <div class="flex gap-2">
                  <dt class="font-medium text-base-content/60">Primary user:</dt>
                  <dd>{@primary_user.email}</dd>
                </div>
              </dl>
            <% else %>
              <p class="text-base-content/50">Single-account mode</p>
            <% end %>
          </div>
        </div>

        <div class="card bg-base-100 shadow-sm mb-6">
          <div class="card-body">
            <h2 class="card-title">Account Switcher</h2>
            <div class="space-y-2">
              <AshMultiAccount.Phoenix.Components.account_switcher
                current_user={@current_user}
                primary_user={@primary_user}
              >
                <:account :let={account}>
                  <div class={"flex items-center justify-between p-3 rounded-lg #{if account.current?, do: "bg-primary/10 border border-primary/20", else: "bg-base-200 hover:bg-base-300"}"}>
                    <div>
                      <span class="font-medium">
                        {account.user.name || account.user.email}
                      </span>
                      <span
                        :if={account.primary?}
                        class="badge badge-ghost badge-sm ml-2"
                      >
                        primary
                      </span>
                      <span
                        :if={account.current?}
                        class="badge badge-primary badge-sm ml-2"
                      >
                        active
                      </span>
                      <div class="text-sm text-base-content/50">{account.user.email}</div>
                    </div>
                    <.link
                      :if={!account.current?}
                      href={account.switch_url}
                      class="btn btn-sm btn-ghost text-primary"
                    >
                      Switch
                    </.link>
                  </div>
                </:account>

                <:add_account :let={url}>
                  <.link
                    href={url}
                    class="btn btn-ghost btn-block mt-2"
                  >
                    + Add another account
                  </.link>
                </:add_account>
              </AshMultiAccount.Phoenix.Components.account_switcher>
            </div>
          </div>
        </div>
      <% else %>
        <div class="card bg-base-100 shadow-sm">
          <div class="card-body items-center text-center">
            <h2 class="card-title">Welcome</h2>
            <p class="text-base-content/60 mb-4">Sign in or create an account to get started.</p>
            <div class="card-actions">
              <.link href={~p"/sign-in"} class="btn btn-primary">Sign In</.link>
              <.link href={~p"/register"} class="btn btn-ghost">Register</.link>
            </div>
          </div>
        </div>
      <% end %>
    </main>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end
end
