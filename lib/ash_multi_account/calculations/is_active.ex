defmodule AshMultiAccount.Calculations.IsActive do
  @moduledoc """
  Calculation that returns whether a linked account is active.

  Accepts the status attribute name as an option so it works with
  customized attribute names.
  """

  use Ash.Resource.Calculation

  @impl true
  def calculate(records, opts, _context) do
    attr = Keyword.fetch!(opts, :attribute)
    active = AshMultiAccount.Helpers.active_status()

    {:ok,
     Enum.map(records, fn record ->
       Map.fetch!(record, attr) == active
     end)}
  end
end
