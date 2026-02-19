defmodule Demo.Accounts.User do
  use Ash.Resource,
    domain: Demo.Accounts,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshAuthentication, AshMultiAccount]

  postgres do
    table "users"
    repo Demo.Repo
  end

  authentication do
    tokens do
      enabled? true
      token_resource Demo.Accounts.Token
      require_token_presence_for_authentication? true

      signing_secret fn _, _ ->
        Application.fetch_env(:demo, :token_signing_secret)
      end
    end

    strategies do
      password :password do
        identity_field :email

        register_action_name :register_with_password
        sign_in_action_name :sign_in_with_password
      end
    end
  end

  multi_account do
    linked_account_resource(Demo.Accounts.LinkedAccount)
    active_check({:status, :active})
    display_fields([:name])
    max_linked_accounts(5)
  end

  actions do
    defaults [:read, update: :*]
  end

  attributes do
    uuid_primary_key :id

    attribute :email, :ci_string do
      allow_nil? false
      public? true
    end

    attribute :hashed_password, :string do
      allow_nil? true
      sensitive? true
    end

    attribute :name, :string do
      public? true
    end

    attribute :status, :atom do
      constraints one_of: [:active, :inactive]
      default :active
      public? true
    end
  end

  identities do
    identity :unique_email, [:email]
  end
end
