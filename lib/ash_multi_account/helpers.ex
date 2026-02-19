defmodule AshMultiAccount.Helpers do
  @moduledoc false

  alias AshMultiAccount.LinkedAccount.Info, as: LAInfo

  @type status :: :active | :inactive

  @active_status :active
  @inactive_status :inactive
  @status_values [@active_status, @inactive_status]

  @doc "The active status value for linked accounts."
  @spec active_status() :: status()
  def active_status, do: @active_status

  @doc "The inactive status value for linked accounts."
  @spec inactive_status() :: status()
  def inactive_status, do: @inactive_status

  @doc "All valid status values for linked accounts."
  @spec status_values() :: [status()]
  def status_values, do: @status_values

  @doc """
  Extracts a value from an `{:ok, value}` tuple, raising a descriptive error
  on any other result.

  Used throughout runtime modules to unwrap DSL Info calls with helpful
  error messages instead of bare MatchErrors.
  """
  @spec fetch_config!({:ok, value} | :error | {:error, term()}, atom()) :: value
        when value: term()
  def fetch_config!({:ok, value}, _label), do: value

  def fetch_config!(other, label) do
    raise ArgumentError,
          "AshMultiAccount: Could not read #{label}. " <>
            "Got: #{inspect(other)}. " <>
            "Ensure the resource has the correct AshMultiAccount extension applied."
  end

  @doc """
  Checks whether a user passes the `active_check` configured on the
  user resource. The `active_check` is a `{field, value}` tuple from the DSL.
  The user is considered active when `Map.get(user, field) == value`.

  Returns `:ok` if the user is active, if `active_check` is not configured,
  or if the configuration cannot be read (treated as no restriction).
  Returns `{:error, :not_active}` when a check is configured and the user
  fails it.
  """
  @spec validate_user_active(Ash.Resource.record(), module()) :: :ok | {:error, :not_active}
  def validate_user_active(user, user_resource) do
    case AshMultiAccount.Info.multi_account_active_check(user_resource) do
      {:ok, {field, value}} ->
        if Map.get(user, field) == value, do: :ok, else: {:error, :not_active}

      :error ->
        :ok
    end
  end

  @doc """
  Fetches the common LinkedAccount DSL configuration values needed by
  runtime modules (preparations, changes, calculations).

  Returns a map with keys: `:user_resource`, `:primary_user_rel`,
  `:linked_user_rel`, `:session_token_attr`, `:status_attr`.
  """
  @spec linked_account_config!(module()) :: %{
          user_resource: module(),
          primary_user_rel: atom(),
          linked_user_rel: atom(),
          session_token_attr: atom(),
          status_attr: atom()
        }
  def linked_account_config!(linked_account_resource) do
    fetch = fn info_fn, label ->
      fetch_config!(info_fn.(linked_account_resource), label)
    end

    %{
      user_resource: fetch.(&LAInfo.multi_account_user_resource/1, :user_resource),
      primary_user_rel:
        fetch.(&LAInfo.multi_account_primary_user_relationship_name/1, :primary_user_relationship),
      linked_user_rel:
        fetch.(&LAInfo.multi_account_linked_user_relationship_name/1, :linked_user_relationship),
      session_token_attr:
        fetch.(&LAInfo.multi_account_session_token_attribute_name/1, :session_token_attribute),
      status_attr: fetch.(&LAInfo.multi_account_status_attribute_name/1, :status_attribute)
    }
  end
end
