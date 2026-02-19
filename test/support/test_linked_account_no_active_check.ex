defmodule AshMultiAccount.Test.LinkedAccountNoActiveCheck do
  @moduledoc false
  use Ash.Resource,
    domain: AshMultiAccount.Test.Domain,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshMultiAccount.LinkedAccount]

  ets do
    private? true
  end

  multi_account do
    user_resource AshMultiAccount.Test.UserNoActiveCheck
  end
end
