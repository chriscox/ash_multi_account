defmodule Demo.Accounts.LinkedAccount do
  use Ash.Resource,
    domain: Demo.Accounts,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshMultiAccount.LinkedAccount]

  multi_account do
    user_resource Demo.Accounts.User
  end
end
