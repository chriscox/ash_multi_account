# Seed two test users for the demo app
password = "password123!"

{:ok, alice} =
  Demo.Accounts.User
  |> Ash.Changeset.for_create(:register_with_password, %{
    email: "alice@example.com",
    password: password,
    password_confirmation: password
  })
  |> Ash.create()

alice |> Ash.Changeset.for_update(:update, %{name: "Alice"}) |> Ash.update!()

{:ok, bob} =
  Demo.Accounts.User
  |> Ash.Changeset.for_create(:register_with_password, %{
    email: "bob@example.com",
    password: password,
    password_confirmation: password
  })
  |> Ash.create()

bob |> Ash.Changeset.for_update(:update, %{name: "Bob"}) |> Ash.update!()

IO.puts("Seeded alice@example.com and bob@example.com (password: #{password})")
