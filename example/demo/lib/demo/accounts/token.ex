defmodule Demo.Accounts.Token do
  use Ash.Resource,
    domain: Demo.Accounts,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshAuthentication.TokenResource]
end
