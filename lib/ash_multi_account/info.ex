defmodule AshMultiAccount.Info do
  @moduledoc """
  Introspection functions for the `AshMultiAccount` extension.
  """

  use Spark.InfoGenerator,
    extension: AshMultiAccount,
    sections: [:multi_account]
end
