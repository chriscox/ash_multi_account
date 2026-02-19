defmodule AshMultiAccount.Calculations.LinkedAccountSessions do
  @moduledoc """
  Calculation that resolves linked account records for a user.

  Resolves the domain from the LinkedAccount resource configuration rather
  than hardcoding a domain reference. Called with a `session_token` argument
  that scopes the query; each user record's `:id` is used as the primary
  user ID.
  """

  use Ash.Resource.Calculation
  import AshMultiAccount.Helpers, only: [fetch_config!: 2]

  @impl true
  def calculate([], _opts, _context), do: {:ok, []}

  def calculate(users, _opts, %{arguments: %{session_token: session_token}} = context) do
    user_resource = hd(users).__struct__

    linked_account_resource =
      fetch_config!(
        AshMultiAccount.Info.multi_account_linked_account_resource(user_resource),
        :linked_account_resource
      )

    get_action =
      fetch_config!(
        AshMultiAccount.LinkedAccount.Info.multi_account_get_linked_accounts_action_name(
          linked_account_resource
        ),
        :get_linked_accounts_action_name
      )

    actor = Map.get(context, :actor)

    results =
      Enum.reduce_while(users, {:ok, []}, fn user, {:ok, acc} ->
        query =
          Ash.Query.for_read(linked_account_resource, get_action, %{
            primary_user_id: user.id,
            session_token: session_token
          })

        case Ash.read(query, actor: actor) do
          {:ok, linked} -> {:cont, {:ok, [linked | acc]}}
          {:error, error} -> {:halt, {:error, error}}
        end
      end)

    case results do
      {:ok, reversed} -> {:ok, Enum.reverse(reversed)}
      error -> error
    end
  end

  def calculate(_users, _opts, context) do
    arguments = Map.get(context, :arguments, %{})

    {:error,
     "The linked_accounts calculation requires a :session_token argument. " <>
       "Received arguments: #{inspect(Map.keys(arguments))}"}
  end
end
