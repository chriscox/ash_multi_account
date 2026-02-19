defmodule AshMultiAccount.Test.User do
  @moduledoc false
  use Ash.Resource,
    domain: AshMultiAccount.Test.Domain,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshMultiAccount]

  ets do
    private? true
  end

  multi_account do
    linked_account_resource(AshMultiAccount.Test.LinkedAccount)
    display_fields([:name])
    max_linked_accounts(3)
    active_check({:status, :active})
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
    end

    attribute :status, :atom do
      constraints one_of: [:active, :inactive]
      default :active
      public? true
    end
  end
end
