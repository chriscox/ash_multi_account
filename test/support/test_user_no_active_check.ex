defmodule AshMultiAccount.Test.UserNoActiveCheck do
  @moduledoc false
  use Ash.Resource,
    domain: AshMultiAccount.Test.Domain,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshMultiAccount]

  ets do
    private? true
  end

  multi_account do
    linked_account_resource(AshMultiAccount.Test.LinkedAccountNoActiveCheck)
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
  end
end
