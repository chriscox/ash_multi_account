defmodule AshMultiAccount.Preparations.LoadLinkedUsers do
  @moduledoc """
  Preparation that loads the `primary_user` and `linked_user` relationships
  with the `display_fields` configured on the User resource.
  """

  use Ash.Resource.Preparation
  import AshMultiAccount.Helpers, only: [fetch_config!: 2]
  require Ash.Query

  @impl true
  def prepare(query, _opts, _context) do
    config = AshMultiAccount.Helpers.linked_account_config!(query.resource)

    display_fields =
      fetch_config!(
        AshMultiAccount.Info.multi_account_display_fields(config.user_resource),
        :display_fields
      )

    Ash.Query.load(query, [
      {config.primary_user_rel, display_fields},
      {config.linked_user_rel, display_fields}
    ])
  end
end
