defmodule AshMultiAccount.Phoenix.Controller do
  @moduledoc """
  Provides `link_account/2` and `switch_to_account/2` controller actions for
  multi-account linking and switching.

  ## Usage

      defmodule MyAppWeb.MultiAccountController do
        use MyAppWeb, :controller
        use AshMultiAccount.Phoenix.Controller,
          user_resource: MyApp.Accounts.User

        # Optionally override redirect paths:
        # def after_link_path(_conn), do: "/"
        # def after_switch_path(_conn), do: "/"
        # def sign_in_path(_conn, primary_user_id), do: "/sign-in?return_to=/link/p/\#{primary_user_id}"
        # def sign_out_path(_conn), do: "/sign-out"
      end

  ## Options

  - `user_resource` (required) — the Ash resource module for users.

  ## Actions

  - `link_account(conn, %{"primary_user_id" => id})` — links the current user
    to an existing primary account, or sets up the multi-account session for the
    primary user themselves. Redirects to sign-in if no user is authenticated.

  - `switch_to_account(conn, %{"user_id" => id})` — switches the current session
    to a different linked user. Rotates the session ID via
    `configure_session(renew: true)` to reduce session fixation risk.
  """

  defmacro __using__(opts) do
    user_resource = Keyword.fetch!(opts, :user_resource)

    quote do
      require Logger

      alias AshMultiAccount.Phoenix.Session

      @__user_resource__ unquote(user_resource)

      @doc false
      def after_link_path(_conn), do: "/"

      @doc false
      def after_switch_path(_conn), do: "/"

      @doc false
      def sign_in_path(_conn, primary_user_id),
        do: "/sign-in?return_to=/link/p/#{primary_user_id}"

      @doc false
      def sign_out_path(_conn), do: "/sign-out"

      defoverridable after_link_path: 1,
                     after_switch_path: 1,
                     sign_in_path: 2,
                     sign_out_path: 1

      @doc """
      Links a newly signed-in user to an existing primary account.

      When the primary_user_id matches the current user, sets up the multi-account
      session and redirects to sign-in so the user can authenticate another account.
      """
      def link_account(conn, %{"primary_user_id" => primary_user_id}) do
        current_user = load_current_user(conn)

        cond do
          is_nil(current_user) ->
            Logger.warning("Link account failed: no authenticated user found")

            conn
            |> put_flash(:error, "Please sign in to link accounts.")
            |> redirect(to: sign_in_path(conn, primary_user_id))

          primary_user_id == current_user.id ->
            setup_multi_account_session(conn, primary_user_id)

          true ->
            link_to_primary(conn, current_user, primary_user_id)
        end
      end

      @doc """
      Switches the current session to a different linked user.

      Requires an active multi-account session. Validates that the target user
      exists, is active, and belongs to the current linked account group. Rotates
      the session ID via `configure_session(renew: true)` to reduce session
      fixation risk.
      """
      def switch_to_account(conn, %{"user_id" => user_id}) do
        current_user = load_current_user(conn)
        primary_user_id = Session.get_primary_user_id(conn)
        session_token = Session.get_session_token(conn)

        cond do
          is_nil(current_user) ->
            Logger.warning("Account switch failed: no authenticated user found")

            conn
            |> put_flash(:error, "Please sign in to switch accounts.")
            |> redirect(to: sign_out_path(conn))

          is_nil(primary_user_id) or is_nil(session_token) ->
            Logger.warning("Account switch attempted without multi-account session")

            conn
            |> put_flash(
              :error,
              "Multi-account session not found. Please set up account linking first."
            )
            |> redirect(to: after_switch_path(conn))

          true ->
            do_switch(conn, current_user, user_id, primary_user_id, session_token)
        end
      end

      defp load_current_user(conn) do
        conn.assigns[:current_user] || load_user_by_id(Session.get_user_id(conn))
      end

      defp load_user_by_id(nil), do: nil

      defp load_user_by_id(user_id) do
        case Ash.get(@__user_resource__, user_id) do
          {:ok, user} ->
            user

          {:error, %Ash.Error.Query.NotFound{}} ->
            Logger.warning("User not found: #{user_id}")
            nil

          {:error, error} ->
            raise "AshMultiAccount: Failed to load user #{user_id}: #{inspect(error)}"
        end
      end

      defp setup_multi_account_session(conn, primary_user_id) do
        session_token = Session.get_session_token(conn) || Ash.UUID.generate()

        Logger.info("Setting up multi-account session for user #{primary_user_id}")

        conn
        |> Session.put_multi_account_session(primary_user_id, session_token)
        |> put_flash(
          :info,
          "Multi-account session established. Please sign in with another account to link it."
        )
        |> redirect(to: sign_in_path(conn, primary_user_id))
      end

      defp link_to_primary(conn, current_user, primary_user_id) do
        case Ash.get(@__user_resource__, primary_user_id) do
          {:ok, primary_user} ->
            session_token = Session.get_session_token(conn)

            if session_token do
              create_link(conn, current_user, primary_user, session_token)
            else
              conn
              |> Session.put_multi_account_session(primary_user.id, Ash.UUID.generate())
              |> put_flash(:error, "Session was not properly set up. Please try again.")
              |> redirect(to: sign_in_path(conn, primary_user.id))
            end

          {:error, error} ->
            Logger.warning(
              "Link account failed for primary user #{primary_user_id}: #{inspect(error)}"
            )

            conn
            |> Session.clear_multi_account_session()
            |> put_flash(:error, "The linked account could not be found. Please sign in again.")
            |> redirect(to: sign_out_path(conn))
        end
      end

      defp create_link(conn, current_user, primary_user, session_token) do
        resource = linked_account_resource()

        create_action =
          AshMultiAccount.Helpers.fetch_config!(
            AshMultiAccount.LinkedAccount.Info.multi_account_create_action_name(resource),
            :create_action_name
          )

        result =
          resource
          |> Ash.Changeset.for_create(
            create_action,
            %{linked_user_id: current_user.id, session_token: session_token},
            actor: primary_user
          )
          |> Ash.create()

        case result do
          {:ok, _linked_account} ->
            Logger.info(
              "Successfully linked account #{current_user.id} to primary #{primary_user.id}"
            )

            conn
            |> Session.put_primary_user_id(primary_user.id)
            |> Plug.Conn.delete_session("user_return_to")
            |> put_flash(:info, "Account successfully linked!")
            |> redirect(to: after_link_path(conn))

          {:error, error} ->
            flash_message = handle_link_error(error, current_user.id, primary_user.id)

            conn
            |> put_flash(:error, flash_message)
            |> redirect(to: sign_in_path(conn, primary_user.id))
        end
      end

      defp identity_error?(%Ash.Error.Invalid{errors: errors}) do
        Enum.any?(errors, fn
          %Ash.Error.Changes.InvalidChanges{message: message}
          when is_binary(message) ->
            String.contains?(message, "has already been taken")

          _ ->
            false
        end)
      end

      defp identity_error?(_), do: false

      defp handle_link_error(error, current_id, primary_id) do
        if identity_error?(error) do
          Logger.warning("Account already linked: #{current_id} -> #{primary_id}")
          "This account is already linked."
        else
          Logger.error("Failed to create linked account: #{inspect(error)}")
          "An error occurred while linking accounts. Please try again."
        end
      end

      defp do_switch(conn, current_user, user_id, primary_user_id, session_token) do
        with {:get_user, {:ok, target_user}} <-
               {:get_user, Ash.get(@__user_resource__, user_id)},
             {:active, :ok} <-
               {:active,
                AshMultiAccount.Helpers.validate_user_active(target_user, @__user_resource__)},
             {:linked, {:ok, linked_accounts}} <-
               {:linked, get_linked_accounts(primary_user_id, session_token)},
             {:auth, true} <-
               {:auth,
                authorized_to_switch?(
                  linked_accounts,
                  current_user.id,
                  primary_user_id,
                  user_id
                )} do
          Logger.info("Account switch: #{current_user.id} -> #{user_id}")

          conn
          |> Plug.Conn.configure_session(renew: true)
          |> Session.put_user_id(user_id)
          |> Session.put_multi_account_session(primary_user_id, session_token)
          |> redirect(to: after_switch_path(conn))
        else
          {:active, {:error, :not_active}} ->
            conn
            |> put_flash(:error, "This account is no longer active and cannot be accessed.")
            |> redirect(to: after_switch_path(conn))

          {:get_user, {:error, error}} ->
            Logger.warning(
              "Account switch failed: could not find user #{user_id}: #{inspect(error)}"
            )

            conn
            |> put_flash(:error, "The target account could not be found.")
            |> redirect(to: after_switch_path(conn))

          {:linked, {:error, error}} ->
            Logger.warning(
              "Account switch failed: could not verify linking for user #{user_id}: #{inspect(error)}"
            )

            conn
            |> put_flash(
              :error,
              "Could not verify account linking. Please try again."
            )
            |> redirect(to: after_switch_path(conn))

          {:auth, false} ->
            Logger.warning("Unauthorized switch attempt: #{current_user.id} -> #{user_id}")

            conn
            |> put_flash(:error, "You are not authorized to switch to this account.")
            |> redirect(to: after_switch_path(conn))
        end
      end

      defp linked_account_resource do
        AshMultiAccount.Helpers.fetch_config!(
          AshMultiAccount.Info.multi_account_linked_account_resource(@__user_resource__),
          :linked_account_resource
        )
      end

      defp get_linked_accounts(primary_user_id, session_token) do
        resource = linked_account_resource()

        get_action =
          AshMultiAccount.Helpers.fetch_config!(
            AshMultiAccount.LinkedAccount.Info.multi_account_get_linked_accounts_action_name(
              resource
            ),
            :get_linked_accounts_action_name
          )

        resource
        |> Ash.Query.for_read(get_action, %{
          primary_user_id: primary_user_id,
          session_token: session_token
        })
        |> Ash.read()
      end

      defp authorized_to_switch?(
             linked_accounts,
             current_user_id,
             primary_user_id,
             target_user_id
           ) do
        in_group? = fn user_id ->
          primary_user_id == user_id or
            Enum.any?(linked_accounts, &(&1.linked_user_id == user_id))
        end

        in_group?.(current_user_id) and in_group?.(target_user_id)
      end
    end
  end
end
