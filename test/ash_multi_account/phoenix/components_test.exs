defmodule AshMultiAccount.Phoenix.ComponentsTest do
  use ExUnit.Case, async: false

  import Phoenix.LiveViewTest

  alias AshMultiAccount.Test.LinkedAccount
  alias AshMultiAccount.Test.User

  defmodule TestComponent do
    use Phoenix.Component

    def render(assigns) do
      ~H"""
      <AshMultiAccount.Phoenix.Components.account_switcher
        current_user={@current_user}
        primary_user={@primary_user}
      >
        <:account :let={account}>
          <div data-testid={"account-#{account.user.id}"}>
            <span class="name">{account.user.name}</span>
            <span :if={account.current?} class="current">current</span>
            <span :if={account.primary?} class="primary">primary</span>
            <a :if={!account.current?} href={account.switch_url}>switch</a>
          </div>
        </:account>
        <:add_account :let={url}>
          <a href={url} class="add-account">Add account</a>
        </:add_account>
      </AshMultiAccount.Phoenix.Components.account_switcher>
      """
    end
  end

  setup do
    session_token = Ash.UUID.generate()

    primary_user =
      User
      |> Ash.Changeset.for_create(:create, %{name: "Primary", status: :active})
      |> Ash.create!()

    linked_user =
      User
      |> Ash.Changeset.for_create(:create, %{name: "Linked", status: :active})
      |> Ash.create!()

    %{
      session_token: session_token,
      primary_user: primary_user,
      linked_user: linked_user
    }
  end

  describe "account_switcher/1" do
    test "renders single account in standard mode", %{primary_user: user} do
      html =
        render_component(&TestComponent.render/1,
          current_user: user,
          primary_user: nil
        )

      assert html =~ user.name
      assert html =~ "current"
      assert html =~ "primary"
      assert html =~ "Add account"
    end

    test "renders primary and linked accounts in multi-account mode", %{
      primary_user: primary_user,
      linked_user: linked_user,
      session_token: session_token
    } do
      # Create the link
      LinkedAccount
      |> Ash.Changeset.for_create(
        :create_linked_account,
        %{linked_user_id: linked_user.id, session_token: session_token},
        actor: primary_user
      )
      |> Ash.create!()

      # Load primary with linked accounts
      primary_with_accounts =
        User
        |> Ash.Query.for_read(:get_user_with_linked_accounts, %{
          primary_user_id: primary_user.id,
          session_token: session_token
        })
        |> Ash.read_one!()

      html =
        render_component(&TestComponent.render/1,
          current_user: primary_user,
          primary_user: primary_with_accounts
        )

      # Primary user shown as current
      assert html =~ primary_user.name
      assert html =~ "current"
      assert html =~ "primary"

      # Linked user shown with switch URL
      assert html =~ linked_user.name
      assert html =~ "/link/switch_to/#{linked_user.id}"

      # Add account link present
      assert html =~ "Add account"

      expected_url =
        "/sign-in?#{URI.encode_query(%{"return_to" => "/link/p/#{primary_user.id}"})}"

      assert html =~ expected_url
    end

    test "marks linked user as current when switched", %{
      primary_user: primary_user,
      linked_user: linked_user,
      session_token: session_token
    } do
      # Create the link
      LinkedAccount
      |> Ash.Changeset.for_create(
        :create_linked_account,
        %{linked_user_id: linked_user.id, session_token: session_token},
        actor: primary_user
      )
      |> Ash.create!()

      # Load primary with linked accounts
      primary_with_accounts =
        User
        |> Ash.Query.for_read(:get_user_with_linked_accounts, %{
          primary_user_id: primary_user.id,
          session_token: session_token
        })
        |> Ash.read_one!()

      html =
        render_component(&TestComponent.render/1,
          current_user: linked_user,
          primary_user: primary_with_accounts
        )

      # Primary user should have switch link (not current)
      assert html =~ "/link/switch_to/#{primary_user.id}"
    end
  end
end
