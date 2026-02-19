defmodule Demo.Accounts.Token do
  use Ash.Resource,
    domain: Demo.Accounts,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshAuthentication.TokenResource]

  postgres do
    table "tokens"
    repo Demo.Repo
  end
end
