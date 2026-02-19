# Testing

This topic covers how to set up test support and write tests for multi-account functionality in your app.

## Test Setup

### ETS Data Layer

For unit tests, use `Ash.DataLayer.Ets` instead of Postgres. ETS provides fast, isolated, in-memory storage with no database setup required.

```elixir
# test/support/resources/user.ex
defmodule MyApp.Test.User do
  use Ash.Resource,
    domain: MyApp.Test.Domain,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshMultiAccount]

  ets do
    private? true
  end

  multi_account do
    linked_account_resource MyApp.Test.LinkedAccount
    display_fields [:name]
    max_linked_accounts 3
    active_check {:status, :active}
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
    end

    attribute :status, :atom do
      constraints one_of: [:active, :inactive]
      default :active
      public? true
    end
  end
end
```

```elixir
# test/support/resources/linked_account.ex
defmodule MyApp.Test.LinkedAccount do
  use Ash.Resource,
    domain: MyApp.Test.Domain,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshMultiAccount.LinkedAccount]

  ets do
    private? true
  end

  multi_account do
    user_resource MyApp.Test.User
  end
end
```

Key points:
- `private? true` on the ETS data layer gives each test process its own isolated store
- The LinkedAccount resource needs no attributes, actions, or relationships — the transformer generates everything
- Include `create: :*` and `update: :*` in your User's default actions so tests can create users with all public attributes

### Test Domain

```elixir
# test/support/domain.ex
defmodule MyApp.Test.Domain do
  use Ash.Domain, validate_config_inclusion?: false

  resources do
    resource MyApp.Test.User
    resource MyApp.Test.LinkedAccount
  end
end
```

The `validate_config_inclusion?: false` option allows the domain to be used in tests without being listed in your app's config.

## Testing Core Flows

### Creating Users

```elixir
defp create_user!(name, opts \\ []) do
  status = Keyword.get(opts, :status, :active)

  MyApp.Test.User
  |> Ash.Changeset.for_create(:create, %{name: name, status: status})
  |> Ash.create!()
end
```

### Linking Accounts

```elixir
test "links two accounts in a session" do
  alice = create_user!("Alice")
  bob = create_user!("Bob")
  session_token = Ash.UUID.generate()

  # Create the link — actor must be the primary user
  linked = MyApp.Test.LinkedAccount
  |> Ash.Changeset.for_create(
    :create_linked_account,
    %{linked_user_id: bob.id, session_token: session_token},
    actor: alice
  )
  |> Ash.create!()

  assert linked.primary_user_id == alice.id
  assert linked.linked_user_id == bob.id
  assert linked.session_token == session_token
  assert linked.status == :active
end
```

Important: pass `actor: primary_user` in `Ash.Changeset.for_create/4` opts, not just in `Ash.create/2`. The `RelateActor` change needs the actor at changeset time to set `primary_user_id`.

### Self-Link Prevention

```elixir
test "rejects self-linking" do
  alice = create_user!("Alice")
  session_token = Ash.UUID.generate()

  assert_raise Ash.Error.Invalid, ~r/cannot link.*yourself/i, fn ->
    MyApp.Test.LinkedAccount
    |> Ash.Changeset.for_create(
      :create_linked_account,
      %{linked_user_id: alice.id, session_token: session_token},
      actor: alice
    )
    |> Ash.create!()
  end
end
```

### Max Linked Accounts

```elixir
test "enforces max_linked_accounts limit" do
  primary = create_user!("Primary")
  session_token = Ash.UUID.generate()

  # Create links up to the limit (3 in our test config)
  for i <- 1..3 do
    user = create_user!("User #{i}")

    MyApp.Test.LinkedAccount
    |> Ash.Changeset.for_create(
      :create_linked_account,
      %{linked_user_id: user.id, session_token: session_token},
      actor: primary
    )
    |> Ash.create!()
  end

  # The 4th link should fail
  extra_user = create_user!("Extra")

  assert_raise Ash.Error.Invalid, ~r/maximum.*linked accounts/i, fn ->
    MyApp.Test.LinkedAccount
    |> Ash.Changeset.for_create(
      :create_linked_account,
      %{linked_user_id: extra_user.id, session_token: session_token},
      actor: primary
    )
    |> Ash.create!()
  end
end
```

### Reading Linked Accounts

```elixir
test "reads linked accounts filtered by session" do
  alice = create_user!("Alice")
  bob = create_user!("Bob")
  token = Ash.UUID.generate()
  other_token = Ash.UUID.generate()

  # Link in our session
  MyApp.Test.LinkedAccount
  |> Ash.Changeset.for_create(
    :create_linked_account,
    %{linked_user_id: bob.id, session_token: token},
    actor: alice
  )
  |> Ash.create!()

  # Link in a different session (shouldn't appear)
  carol = create_user!("Carol")

  MyApp.Test.LinkedAccount
  |> Ash.Changeset.for_create(
    :create_linked_account,
    %{linked_user_id: carol.id, session_token: other_token},
    actor: alice
  )
  |> Ash.create!()

  # Read links for our session only
  results =
    MyApp.Test.LinkedAccount
    |> Ash.Query.for_read(:get_linked_accounts, %{
      primary_user_id: alice.id,
      session_token: token
    })
    |> Ash.read!()

  assert length(results) == 1
  assert hd(results).linked_user_id == bob.id
end
```

## Testing Phoenix Controllers

### Test Endpoint and Router

For controller tests, you need a minimal test endpoint and router:

```elixir
# test/support/test_endpoint.ex
defmodule MyApp.Test.Endpoint do
  use Phoenix.Endpoint, otp_app: :my_app

  plug Plug.Session,
    store: :cookie,
    key: "_test_key",
    signing_salt: "test_salt"

  plug MyApp.Test.Router
end
```

```elixir
# test/support/test_router.ex
defmodule MyApp.Test.Router do
  use Phoenix.Router
  use AshMultiAccount.Phoenix.Router

  pipeline :browser do
    plug :fetch_session
    plug :fetch_flash
    plug AshMultiAccount.Phoenix.Plug
  end

  scope "/", MyApp.Test do
    pipe_through :browser
    multi_account_routes TestController, MyApp.Test.User
  end
end
```

```elixir
# test/support/test_controller.ex
defmodule MyApp.Test.TestController do
  use Phoenix.Controller, formats: [:html]
  use AshMultiAccount.Phoenix.Controller,
    user_resource: MyApp.Test.User
end
```

Configure the endpoint in your test config:

```elixir
# config/test.exs
config :my_app, MyApp.Test.Endpoint,
  secret_key_base: String.duplicate("a", 64),
  render_errors: [formats: [html: MyApp.Test.ErrorView]]
```

### Controller Test Example

```elixir
defmodule MyApp.ControllerTest do
  use ExUnit.Case

  import Plug.Test

  @endpoint MyApp.Test.Endpoint

  setup do
    {:ok, _} = @endpoint.start_link()
    :ok
  end

  test "link_account sets up multi-account session for primary user" do
    alice = create_user!("Alice")

    conn =
      conn(:get, "/link/p/#{alice.id}")
      |> init_test_session(%{"user" => "user?id=#{alice.id}"})
      |> @endpoint.call(@endpoint.init([]))

    assert conn.status == 302
    location = get_resp_header(conn, "location") |> hd()
    assert location =~ "/sign-in"

    # Verify session was set up
    assert get_session(conn, "primary_user_id") == alice.id
    assert get_session(conn, "session_token") != nil
  end

  test "switch_to_account switches the active user" do
    alice = create_user!("Alice")
    bob = create_user!("Bob")
    session_token = Ash.UUID.generate()

    # Create the link
    MyApp.Test.LinkedAccount
    |> Ash.Changeset.for_create(
      :create_linked_account,
      %{linked_user_id: bob.id, session_token: session_token},
      actor: alice
    )
    |> Ash.create!()

    # Switch from Bob to Alice
    conn =
      conn(:get, "/link/switch_to/#{alice.id}")
      |> init_test_session(%{
        "user" => "user?id=#{bob.id}",
        "primary_user_id" => alice.id,
        "session_token" => session_token
      })
      |> @endpoint.call(@endpoint.init([]))

    assert conn.status == 302
    assert get_session(conn, "user") == "user?id=#{alice.id}"
  end
end
```

### Flash Assertions

In Phoenix 1.7+, flash is stored in `conn.assigns.flash`. Use `Phoenix.Flash.get/2`:

```elixir
flash = conn.assigns[:flash] || %{}
assert Phoenix.Flash.get(flash, :info) == "Account successfully linked!"
```

## Testing LiveView

To test the LiveView hook, use Phoenix.LiveViewTest:

```elixir
defmodule MyApp.LiveHookTest do
  use ExUnit.Case
  import Phoenix.LiveViewTest

  test "assigns current_user and primary_user in multi-account mode" do
    alice = create_user!("Alice")
    bob = create_user!("Bob")
    session_token = Ash.UUID.generate()

    MyApp.Test.LinkedAccount
    |> Ash.Changeset.for_create(
      :create_linked_account,
      %{linked_user_id: bob.id, session_token: session_token},
      actor: alice
    )
    |> Ash.create!()

    {:ok, view, _html} =
      live(build_conn(), "/dashboard",
        session: %{
          "user" => "user?id=#{bob.id}",
          "primary_user_id" => alice.id,
          "session_token" => session_token
        }
      )

    assert view |> element("...") |> ...
  end
end
```

## Tips

- **ETS isolation**: With `private? true`, each test process gets its own ETS table. No need for `Ecto.Adapters.SQL.Sandbox` or async coordination.
- **Actor matters**: Always pass the primary user as `actor:` in `for_create/4` opts when creating linked accounts. The `RelateActor` change sets `primary_user_id` from the actor.
- **Session format**: The `"user"` session key expects AshAuthentication's subject format: `"user?id=<UUID>"`. Use `AshMultiAccount.Phoenix.Session.put_user_id/3` or construct it manually in tests.
- **Display fields**: If your tests assert on user fields like `name`, make sure they're listed in `display_fields` so they get loaded by the hook and component.
