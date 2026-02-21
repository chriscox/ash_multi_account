defmodule AshMultiAccount.Phoenix.LiveHook do
  @moduledoc """
  LiveView `on_mount` hook for multi-account session resolution.

  Determines whether the session is in multi-account mode and loads the
  appropriate `:current_user` and `:primary_user` assigns.

  ## Usage

      # In your router:
      live_session :authenticated,
        on_mount: [
          {AshAuthentication.Phoenix.LiveSession, :load_from_session},
          {AshMultiAccount.Phoenix.LiveHook, {:load_multi_account, MyApp.Accounts.User}}
        ]

  The hook name is a tuple `{:load_multi_account, user_resource}` so the user
  resource module is passed at the call site — no global application config needed.

  ## Options

  An optional keyword list can be passed as a third tuple element:

      {AshMultiAccount.Phoenix.LiveHook, {:load_multi_account, MyApp.Accounts.User, sign_out_path: "/logout"}}

  - `:sign_out_path` — path to redirect to on fatal errors (default: `"/sign-out"`).

  ## Assigns Set

  - `:current_user` — the user currently acting (may differ from primary in multi-account mode)
  - `:primary_user` — the primary account owner (nil when not in multi-account mode)

  ## Standard Mode

  When no multi-account session is detected, the hook loads `:current_user` from
  socket assigns or the session, applies configured `display_fields`, and sets
  `:primary_user` to `nil`.

  ## Error Handling

  - If the primary user is **not found** (e.g., stale session after data reset),
    the hook falls back to standard mode
  - If the primary user is **not active**, the hook halts and redirects to the
    configured `sign_out_path` (default: `"/sign-out"`)
  - If loading fails with an unexpected error, the hook halts with a generic error message
  """

  import Phoenix.Component, only: [assign: 3]

  alias AshMultiAccount.Phoenix.Session
  alias AshMultiAccount.Phoenix.UserResolver

  require Logger

  @default_sign_out_path "/sign-out"

  @spec on_mount(
          {:load_multi_account, module()} | {:load_multi_account, module(), keyword()},
          map(),
          map(),
          Phoenix.LiveView.Socket.t()
        ) :: {:cont | :halt, Phoenix.LiveView.Socket.t()}
  def on_mount({:load_multi_account, user_resource}, params, session, socket) do
    on_mount({:load_multi_account, user_resource, []}, params, session, socket)
  end

  def on_mount({:load_multi_account, user_resource, opts}, _params, session, socket) do
    sign_out_path = Keyword.get(opts, :sign_out_path, @default_sign_out_path)

    if Session.multi_account_session?(session) do
      handle_multi_account(user_resource, session, socket, sign_out_path)
    else
      handle_standard(user_resource, session, socket)
    end
  end

  defp handle_multi_account(user_resource, session, socket, sign_out_path) do
    primary_user_id = Session.get_primary_user_id(session)
    session_token = Session.get_session_token(session)

    action_name =
      AshMultiAccount.Helpers.fetch_config!(
        AshMultiAccount.Info.multi_account_get_user_with_linked_accounts_action_name(
          user_resource
        ),
        :get_user_with_linked_accounts_action_name
      )

    query =
      user_resource
      |> Ash.Query.for_read(action_name, %{
        primary_user_id: primary_user_id,
        session_token: session_token
      })

    case Ash.read_one(query) do
      {:ok, nil} ->
        # Primary user not found — likely a stale session (e.g., ETS cleared on restart).
        # Fall back to standard mode so the current user is still resolved.
        # The LoadMultiAccount plug (if present) will clear the stale session keys.
        Logger.warning(
          "Multi-account: primary user #{primary_user_id} not found, falling back to standard mode"
        )

        handle_standard(user_resource, session, socket)

      {:ok, primary_user} ->
        case AshMultiAccount.Helpers.validate_user_active(primary_user, user_resource) do
          :ok ->
            current_user = resolve_current_user(user_resource, session, socket, primary_user)

            {:cont,
             socket
             |> assign(:current_user, current_user)
             |> assign(:primary_user, primary_user)}

          {:error, :not_active} ->
            Logger.info("Primary user #{primary_user.id} is not active, halting")

            {:halt,
             socket
             |> Phoenix.LiveView.put_flash(
               :error,
               "Your session is no longer valid. Please sign in again."
             )
             |> Phoenix.LiveView.redirect(to: sign_out_path)}
        end

      {:error, error} ->
        Logger.error("Failed to load primary user with linked accounts: #{inspect(error)}")

        {:halt,
         socket
         |> Phoenix.LiveView.put_flash(
           :error,
           "Something went wrong loading your account. Please try again."
         )
         |> Phoenix.LiveView.redirect(to: sign_out_path)}
    end
  end

  defp handle_standard(user_resource, session, socket) do
    current_user =
      socket.assigns[:current_user] || load_user_from_session(user_resource, session)

    current_user = UserResolver.maybe_load_display_fields(current_user, user_resource)

    {:cont,
     socket
     |> assign(:current_user, current_user)
     |> assign(:primary_user, nil)}
  end

  defp resolve_current_user(user_resource, session, socket, primary_user) do
    # In multi-account mode, prioritize our session key over AshAuthentication's
    # socket.assigns[:current_user] (which comes from JWT and can't reflect switches)
    case load_user_from_session(user_resource, session) do
      nil ->
        fallback = socket.assigns[:current_user] || primary_user

        if fallback do
          source =
            if socket.assigns[:current_user], do: "socket assigns", else: "primary user"

          Logger.warning(
            "AshMultiAccount: Could not load user from session, falling back to #{source}"
          )
        end

        UserResolver.maybe_load_display_fields(fallback, user_resource)

      user ->
        UserResolver.maybe_load_display_fields(user, user_resource)
    end
  end

  defp load_user_from_session(user_resource, session) do
    load_user_by_id(user_resource, Session.get_user_id(session))
  end

  defp load_user_by_id(_user_resource, nil), do: nil

  defp load_user_by_id(user_resource, user_id) do
    case Ash.get(user_resource, user_id) do
      {:ok, user} ->
        user

      {:error, error} ->
        if UserResolver.not_found_error?(error) do
          Logger.warning("User not found: #{user_id}")
          nil
        else
          raise "AshMultiAccount: Failed to load user #{user_id}: #{inspect(error)}"
        end
    end
  end
end
