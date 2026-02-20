defmodule AshMultiAccount.Phoenix.LoadMultiAccount do
  @moduledoc """
  Plug that resolves multi-account assigns for controller-rendered pages.

  Mirrors the logic of `AshMultiAccount.Phoenix.LiveHook` but for `Plug.Conn`:
  determines whether the session is in multi-account mode and sets
  `:current_user` and `:primary_user` assigns on the conn.

  ## Usage

      pipeline :browser do
        plug :fetch_session
        # ... other plugs ...
        plug AshMultiAccount.Phoenix.Plug
        plug AshMultiAccount.Phoenix.LoadMultiAccount, user_resource: MyApp.Accounts.User
      end

  Must run **after** `:fetch_session` and `AshMultiAccount.Phoenix.Plug` in
  the pipeline.

  ## Assigns Set

  - `:current_user` — the user currently acting (may differ from primary in multi-account mode)
  - `:primary_user` — the primary account owner (`nil` when not in multi-account mode)

  ## Error Handling

  When the primary user is **not found** or **not active**, the plug clears the
  stale multi-account session keys and falls back to standard mode — resolving
  the current user from `conn.assigns` or the session without multi-account
  context. For unexpected errors (e.g., database failures), the plug assigns
  `nil` gracefully and lets the controller decide how to respond.
  """

  @behaviour Plug

  alias AshMultiAccount.Phoenix.Session
  alias AshMultiAccount.Phoenix.UserResolver

  require Logger

  @impl true
  @spec init(keyword()) :: keyword()
  def init(opts) do
    unless Keyword.has_key?(opts, :user_resource) do
      raise ArgumentError,
            "AshMultiAccount.Phoenix.LoadMultiAccount requires the :user_resource option. " <>
              "Example: plug AshMultiAccount.Phoenix.LoadMultiAccount, user_resource: MyApp.Accounts.User"
    end

    opts
  end

  @impl true
  @spec call(Plug.Conn.t(), keyword()) :: Plug.Conn.t()
  def call(conn, opts) do
    user_resource = Keyword.fetch!(opts, :user_resource)

    if Session.multi_account_session?(conn) do
      handle_multi_account(conn, user_resource)
    else
      handle_standard(conn, user_resource)
    end
  end

  defp handle_multi_account(conn, user_resource) do
    primary_user_id = Session.get_primary_user_id(conn)
    session_token = Session.get_session_token(conn)

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
        # Clear the stale multi-account keys and fall back to standard mode so the
        # current user (if authenticated) is still resolved correctly.
        Logger.warning(
          "Multi-account: primary user #{primary_user_id} not found, clearing stale session"
        )

        conn
        |> Session.clear_multi_account_session()
        |> handle_standard(user_resource)

      {:ok, primary_user} ->
        case AshMultiAccount.Helpers.validate_user_active(primary_user, user_resource) do
          :ok ->
            current_user = resolve_current_user(conn, user_resource, primary_user)

            conn
            |> Plug.Conn.assign(:current_user, current_user)
            |> Plug.Conn.assign(:primary_user, primary_user)

          {:error, :not_active} ->
            Logger.info("Primary user #{primary_user.id} is not active, clearing session")

            conn
            |> Session.clear_multi_account_session()
            |> handle_standard(user_resource)
        end

      {:error, error} ->
        Logger.error("Failed to load primary user with linked accounts: #{inspect(error)}")
        assign_no_user(conn)
    end
  end

  defp handle_standard(conn, user_resource) do
    current_user = conn.assigns[:current_user] || load_user_from_session(conn, user_resource)
    current_user = UserResolver.maybe_load_display_fields(current_user, user_resource)

    conn
    |> Plug.Conn.assign(:current_user, current_user)
    |> Plug.Conn.assign(:primary_user, nil)
  end

  defp resolve_current_user(conn, user_resource, primary_user) do
    # In multi-account mode, prioritize our session key over any existing
    # conn.assigns[:current_user] (which comes from JWT and can't reflect switches)
    case load_user_from_session(conn, user_resource) do
      nil ->
        fallback = conn.assigns[:current_user] || primary_user

        if fallback do
          source = if conn.assigns[:current_user], do: "conn assigns", else: "primary user"

          Logger.warning(
            "AshMultiAccount: Could not load user from session, falling back to #{source}"
          )
        end

        UserResolver.maybe_load_display_fields(fallback, user_resource)

      user ->
        UserResolver.maybe_load_display_fields(user, user_resource)
    end
  end

  defp load_user_from_session(conn, user_resource) do
    load_user_by_id(user_resource, Session.get_user_id(conn))
  end

  defp load_user_by_id(_user_resource, nil), do: nil

  defp load_user_by_id(user_resource, user_id) do
    case Ash.get(user_resource, user_id) do
      {:ok, user} ->
        user

      {:error, error} ->
        unless UserResolver.not_found_error?(error) do
          Logger.error("AshMultiAccount: Failed to load user #{user_id}: #{inspect(error)}")
        end

        nil
    end
  end

  defp assign_no_user(conn) do
    conn
    |> Plug.Conn.assign(:current_user, nil)
    |> Plug.Conn.assign(:primary_user, nil)
  end
end
