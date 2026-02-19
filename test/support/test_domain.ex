defmodule AshMultiAccount.Test.Domain do
  @moduledoc false
  use Ash.Domain, validate_config_inclusion?: false

  resources do
    resource AshMultiAccount.Test.User
    resource AshMultiAccount.Test.UserNoActiveCheck
    resource AshMultiAccount.Test.LinkedAccount
    resource AshMultiAccount.Test.LinkedAccountNoActiveCheck
  end
end
