defmodule AshMultiAccount.Test.Controller do
  @moduledoc false
  use Phoenix.Controller, formats: [:html]

  use AshMultiAccount.Phoenix.Controller,
    user_resource: AshMultiAccount.Test.User
end
