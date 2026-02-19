defmodule Demo.Accounts.LinkedAccount do
  use Ash.Resource,
    domain: Demo.Accounts,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshMultiAccount.LinkedAccount]

  multi_account do
    user_resource Demo.Accounts.User
  end

  postgres do
    table "linked_accounts"
    repo Demo.Repo
  end
end
