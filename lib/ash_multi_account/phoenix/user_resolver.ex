defmodule AshMultiAccount.Phoenix.UserResolver do
  @moduledoc false
  # Shared user-loading helpers used by both LoadMultiAccount (plug) and
  # LiveHook (on_mount). Extracted to avoid duplicating the same logic in
  # two places.

  require Logger

  @doc """
  Returns `true` when the error (or any nested error) is `Ash.Error.Query.NotFound`.
  """
  @spec not_found_error?(term()) :: boolean()
  def not_found_error?(%Ash.Error.Query.NotFound{}), do: true

  def not_found_error?(%{errors: errors}) when is_list(errors),
    do: Enum.any?(errors, &not_found_error?/1)

  def not_found_error?(_), do: false

  @doc """
  Loads the configured `display_fields` onto a user struct.
  Returns the user unchanged if no display fields are configured or if loading fails.
  """
  @spec maybe_load_display_fields(Ash.Resource.record() | nil, module()) ::
          Ash.Resource.record() | nil
  def maybe_load_display_fields(nil, _user_resource), do: nil

  def maybe_load_display_fields(user, user_resource) do
    case AshMultiAccount.Info.multi_account_display_fields(user_resource) do
      {:ok, fields} when fields != [] ->
        case Ash.load(user, fields) do
          {:ok, user} ->
            user

          {:error, error} ->
            Logger.warning("Failed to load display fields #{inspect(fields)}: #{inspect(error)}")
            user
        end

      {:ok, _} ->
        user
    end
  end
end
