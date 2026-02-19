defmodule AshMultiAccount.LinkedAccount.Dsl do
  @moduledoc false

  @multi_account %Spark.Dsl.Section{
    name: :multi_account,
    describe: "Configure multi-account options for the LinkedAccount resource.",
    no_depend_modules: [:user_resource],
    schema: [
      user_resource: [
        type: {:behaviour, Ash.Resource},
        doc: "The User resource module that linked accounts belong to.",
        required: true
      ],
      session_token_attribute_name: [
        type: :atom,
        doc: "The name of the session token attribute.",
        default: :session_token
      ],
      status_attribute_name: [
        type: :atom,
        doc: "The name of the status attribute.",
        default: :status
      ],
      primary_user_relationship_name: [
        type: :atom,
        doc: "The name of the primary_user belongs_to relationship.",
        default: :primary_user
      ],
      linked_user_relationship_name: [
        type: :atom,
        doc: "The name of the linked_user belongs_to relationship.",
        default: :linked_user
      ],
      create_action_name: [
        type: :atom,
        doc: "The name of the create linked account action.",
        default: :create_linked_account
      ],
      get_linked_accounts_action_name: [
        type: :atom,
        doc: "The name of the get linked accounts read action.",
        default: :get_linked_accounts
      ],
      activate_action_name: [
        type: :atom,
        doc: "The name of the activate action.",
        default: :activate
      ],
      deactivate_action_name: [
        type: :atom,
        doc: "The name of the deactivate action.",
        default: :deactivate
      ],
      read_action_name: [
        type: :atom,
        doc: "The name of the default read action.",
        default: :read
      ],
      destroy_action_name: [
        type: :atom,
        doc: "The name of the default destroy action.",
        default: :destroy
      ]
    ]
  }

  def dsl, do: [@multi_account]
end
