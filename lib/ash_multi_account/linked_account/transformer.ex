defmodule AshMultiAccount.LinkedAccount.Transformer do
  @moduledoc """
  The LinkedAccount transformer.

  Sets up the default schema, relationships, identity, actions, and
  calculations for a linked account resource.
  """

  use Spark.Dsl.Transformer
  import Ash.Expr, only: [expr: 1, arg: 1]
  alias Ash.Resource
  alias AshMultiAccount.LinkedAccount.Info
  alias Spark.Dsl.Transformer
  require Ash.Expr

  @doc false
  @impl true
  def after?(Resource.Transformers.ValidatePrimaryActions), do: true
  def after?(_), do: false

  @doc false
  @impl true
  def before?(Resource.Transformers.CachePrimaryKey), do: true
  def before?(Resource.Transformers.DefaultAccept), do: true
  def before?(Resource.Transformers.ValidateRelationshipAttributes), do: true
  def before?(Resource.Transformers.BelongsToAttribute), do: true
  def before?(_), do: false

  @doc false
  @impl true
  def transform(dsl_state) do
    with {:ok, user_resource} <- Info.multi_account_user_resource(dsl_state),
         {:ok, session_token} <- Info.multi_account_session_token_attribute_name(dsl_state),
         {:ok, status} <- Info.multi_account_status_attribute_name(dsl_state),
         {:ok, primary_user_rel} <- Info.multi_account_primary_user_relationship_name(dsl_state),
         {:ok, linked_user_rel} <- Info.multi_account_linked_user_relationship_name(dsl_state),
         {:ok, create_action} <- Info.multi_account_create_action_name(dsl_state),
         {:ok, get_action} <- Info.multi_account_get_linked_accounts_action_name(dsl_state),
         {:ok, activate_action} <- Info.multi_account_activate_action_name(dsl_state),
         {:ok, deactivate_action} <- Info.multi_account_deactivate_action_name(dsl_state),
         {:ok, read_action} <- Info.multi_account_read_action_name(dsl_state),
         {:ok, destroy_action} <- Info.multi_account_destroy_action_name(dsl_state),
         # Primary key
         {:ok, dsl_state} <- maybe_build_primary_key(dsl_state),
         # Attributes
         {:ok, dsl_state} <-
           maybe_build_attribute(dsl_state, session_token, :uuid, allow_nil?: false),
         {:ok, dsl_state} <-
           maybe_build_attribute(dsl_state, status, :atom,
             constraints: [one_of: AshMultiAccount.Helpers.status_values()],
             default: AshMultiAccount.Helpers.active_status()
           ),
         # Timestamps
         {:ok, dsl_state} <- maybe_build_timestamp(dsl_state, :inserted_at, :create),
         {:ok, dsl_state} <- maybe_build_timestamp(dsl_state, :updated_at, :update),
         # Relationships
         {:ok, dsl_state} <-
           maybe_build_relationship(dsl_state, primary_user_rel, fn _ds ->
             Transformer.build_entity(Resource.Dsl, [:relationships], :belongs_to,
               name: primary_user_rel,
               destination: user_resource,
               attribute_writable?: true,
               allow_nil?: false
             )
           end),
         {:ok, dsl_state} <-
           maybe_build_relationship(dsl_state, linked_user_rel, fn _ds ->
             Transformer.build_entity(Resource.Dsl, [:relationships], :belongs_to,
               name: linked_user_rel,
               destination: user_resource,
               attribute_writable?: true,
               allow_nil?: false
             )
           end),
         # Identity
         primary_user_id_attr = :"#{primary_user_rel}_id",
         linked_user_id_attr = :"#{linked_user_rel}_id",
         domain = Spark.Dsl.Transformer.get_persisted(dsl_state, :domain),
         {:ok, dsl_state} <-
           maybe_build_identity(
             dsl_state,
             :unique_linked_user_session,
             [
               primary_user_id_attr,
               linked_user_id_attr,
               session_token
             ],
             pre_check_with: domain
           ),
         # Actions
         {:ok, dsl_state} <-
           maybe_build_action(dsl_state, read_action, fn _ds ->
             Transformer.build_entity(Resource.Dsl, [:actions], :read,
               name: read_action,
               primary?: true
             )
           end),
         {:ok, dsl_state} <-
           maybe_build_action(dsl_state, destroy_action, fn _ds ->
             Transformer.build_entity(Resource.Dsl, [:actions], :destroy,
               name: destroy_action,
               primary?: true
             )
           end),
         {:ok, dsl_state} <-
           maybe_build_action(dsl_state, create_action, fn _ds ->
             build_create_action(
               create_action,
               linked_user_id_attr,
               session_token,
               primary_user_rel
             )
           end),
         {:ok, dsl_state} <-
           maybe_build_action(dsl_state, get_action, fn _ds ->
             build_get_linked_accounts_action(get_action)
           end),
         {:ok, dsl_state} <-
           maybe_build_action(dsl_state, activate_action, fn _ds ->
             build_status_action(activate_action, status, AshMultiAccount.Helpers.active_status())
           end),
         {:ok, dsl_state} <-
           maybe_build_action(dsl_state, deactivate_action, fn _ds ->
             build_status_action(
               deactivate_action,
               status,
               AshMultiAccount.Helpers.inactive_status()
             )
           end),
         # Calculation
         {:ok, dsl_state} <- maybe_build_is_active_calculation(dsl_state, status) do
      {:ok, dsl_state}
    end
  end

  # --- Action builders ---

  defp build_create_action(action_name, linked_user_id_attr, session_token, primary_user_rel) do
    changes = [
      Transformer.build_entity!(Resource.Dsl, [:actions, :create], :change,
        change:
          {AshMultiAccount.Changes.ValidateNotSelfLinked,
           linked_user_id_attr: linked_user_id_attr}
      ),
      Transformer.build_entity!(Resource.Dsl, [:actions, :create], :change,
        change: {Ash.Resource.Change.RelateActor, relationship: primary_user_rel}
      ),
      Transformer.build_entity!(Resource.Dsl, [:actions, :create], :change,
        change: AshMultiAccount.Changes.ValidateMaxLinkedAccounts
      )
    ]

    Transformer.build_entity(Resource.Dsl, [:actions], :create,
      name: action_name,
      accept: [linked_user_id_attr, session_token],
      changes: changes
    )
  end

  defp build_get_linked_accounts_action(action_name) do
    arguments = [
      Transformer.build_entity!(Resource.Dsl, [:actions, :read], :argument,
        name: :primary_user_id,
        type: :uuid,
        allow_nil?: false
      ),
      Transformer.build_entity!(Resource.Dsl, [:actions, :read], :argument,
        name: :session_token,
        type: :uuid,
        allow_nil?: false
      )
    ]

    preparations = [
      Transformer.build_entity!(Resource.Dsl, [:actions, :read], :prepare,
        preparation: AshMultiAccount.Preparations.FilterLinkedAccounts
      ),
      Transformer.build_entity!(Resource.Dsl, [:actions, :read], :prepare,
        preparation: AshMultiAccount.Preparations.LoadLinkedUsers
      )
    ]

    Transformer.build_entity(Resource.Dsl, [:actions], :read,
      name: action_name,
      arguments: arguments,
      preparations: preparations
    )
  end

  defp build_status_action(action_name, status_attr, status_value) do
    arguments = [
      Transformer.build_entity!(Resource.Dsl, [:actions, :update], :argument,
        name: :id,
        type: :uuid,
        allow_nil?: false
      )
    ]

    changes = [
      Transformer.build_entity!(Resource.Dsl, [:actions, :update], :change,
        change: {Ash.Resource.Change.SetAttribute, attribute: status_attr, value: status_value}
      ),
      Transformer.build_entity!(Resource.Dsl, [:actions, :update], :change,
        change: {Ash.Resource.Change.Filter, filter: expr(id == ^arg(:id))}
      )
    ]

    Transformer.build_entity(Resource.Dsl, [:actions], :update,
      name: action_name,
      accept: [],
      require_atomic?: false,
      arguments: arguments,
      changes: changes
    )
  end

  # --- Calculation ---

  defp maybe_build_is_active_calculation(dsl_state, status_attr) do
    if Resource.Info.calculation(dsl_state, :is_active?) do
      {:ok, dsl_state}
    else
      calc =
        Transformer.build_entity!(Resource.Dsl, [:calculations], :calculate,
          name: :is_active?,
          type: :boolean,
          calculation: {AshMultiAccount.Calculations.IsActive, attribute: status_attr}
        )

      {:ok, Transformer.add_entity(dsl_state, [:calculations], calc)}
    end
  end

  # --- Helpers (following AshAuthentication transformer conventions) ---

  defp maybe_build_attribute(dsl_state, name, type, options) do
    if Resource.Info.attribute(dsl_state, name) do
      {:ok, dsl_state}
    else
      options =
        options
        |> Keyword.put(:name, name)
        |> Keyword.put(:type, type)

      attribute = Transformer.build_entity!(Resource.Dsl, [:attributes], :attribute, options)
      {:ok, Transformer.add_entity(dsl_state, [:attributes], attribute)}
    end
  end

  defp maybe_build_relationship(dsl_state, name, builder) when is_function(builder, 1) do
    case find_relationship(dsl_state, name) do
      {:ok, _} ->
        {:ok, dsl_state}

      :error ->
        case builder.(dsl_state) do
          {:ok, relationship} ->
            {:ok, Transformer.add_entity(dsl_state, [:relationships], relationship)}

          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  defp find_relationship(dsl_state, name) do
    case Enum.find(Resource.Info.relationships(dsl_state), &(&1.name == name)) do
      nil -> :error
      relationship -> {:ok, relationship}
    end
  end

  defp maybe_build_action(dsl_state, action_name, builder) when is_function(builder, 1) do
    case Resource.Info.action(dsl_state, action_name) do
      nil ->
        case builder.(dsl_state) do
          {:ok, action} -> {:ok, Transformer.add_entity(dsl_state, [:actions], action)}
          {:error, reason} -> {:error, reason}
        end

      _action ->
        {:ok, dsl_state}
    end
  end

  defp maybe_build_primary_key(dsl_state) do
    case Resource.Info.primary_key(dsl_state) do
      [] ->
        maybe_build_attribute(dsl_state, :id, :uuid,
          allow_nil?: false,
          writable?: true,
          primary_key?: true,
          default: &Ash.UUID.generate/0
        )

      _ ->
        {:ok, dsl_state}
    end
  end

  defp maybe_build_timestamp(dsl_state, name, type) do
    if Resource.Info.attribute(dsl_state, name) do
      {:ok, dsl_state}
    else
      entity =
        case type do
          :create ->
            Transformer.build_entity!(Resource.Dsl, [:attributes], :create_timestamp, name: name)

          :update ->
            Transformer.build_entity!(Resource.Dsl, [:attributes], :update_timestamp, name: name)
        end

      {:ok, Transformer.add_entity(dsl_state, [:attributes], entity)}
    end
  end

  defp maybe_build_identity(dsl_state, name, keys, opts) do
    case find_identity(dsl_state, keys) do
      {:ok, _} ->
        {:ok, dsl_state}

      :error ->
        identity_opts = [name: name, keys: keys] ++ Keyword.take(opts, [:pre_check_with])

        identity =
          Transformer.build_entity!(Resource.Dsl, [:identities], :identity, identity_opts)

        {:ok, Transformer.add_entity(dsl_state, [:identities], identity)}
    end
  end

  defp find_identity(dsl_state, keys) do
    keyset = MapSet.new(keys)

    dsl_state
    |> Resource.Info.identities()
    |> Enum.find_value(:error, fn identity ->
      if MapSet.equal?(MapSet.new(identity.keys), keyset), do: {:ok, identity}
    end)
  end
end
