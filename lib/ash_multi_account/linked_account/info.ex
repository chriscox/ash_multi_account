defmodule AshMultiAccount.LinkedAccount.Info do
  @moduledoc """
  Introspection functions for the `AshMultiAccount.LinkedAccount` extension.
  """

  use Spark.InfoGenerator,
    extension: AshMultiAccount.LinkedAccount,
    sections: [:multi_account]
end
