defmodule DemoWeb.MultiAccountTest do
  @moduledoc """
  Smoke tests for the demo app's multi-account integration.
  Validates that the library works end-to-end with an ETS data layer.
  """
  use DemoWeb.ConnCase

  @moduletag :capture_log

  setup do
    password = "password123!"

    alice =
      Demo.Accounts.User
      |> Ash.Changeset.for_create(:register_with_password, %{
        email: "alice-#{System.unique_integer([:positive])}@example.com",
        name: "Alice",
        password: password,
        password_confirmation: password
      })
      |> Ash.create!()

    bob =
      Demo.Accounts.User
      |> Ash.Changeset.for_create(:register_with_password, %{
        email: "bob-#{System.unique_integer([:positive])}@example.com",
        name: "Bob",
        password: password,
        password_confirmation: password
      })
      |> Ash.create!()

    %{alice: alice, bob: bob, password: password}
  end

  describe "page loads" do
    test "home page loads when not signed in", %{conn: conn} do
      conn = get(conn, ~p"/")
      assert html_response(conn, 200) =~ "Welcome to Ash Multi Account"
    end

    test "sign-in page loads", %{conn: conn} do
      conn = get(conn, ~p"/sign-in")
      assert html_response(conn, 200)
    end

    test "register page loads", %{conn: conn} do
      conn = get(conn, ~p"/register")
      assert html_response(conn, 200)
    end
  end

  describe "authentication" do
    test "sign in via password strategy", %{conn: conn, alice: alice, password: password} do
      conn =
        post(conn, ~p"/auth/user/password/sign_in", %{
          "user" => %{
            "email" => to_string(alice.email),
            "password" => password
          }
        })

      assert redirected_to(conn) == "/"
    end

    test "sign in failure redirects to sign-in", %{conn: conn, alice: alice} do
      conn =
        post(conn, ~p"/auth/user/password/sign_in", %{
          "user" => %{
            "email" => to_string(alice.email),
            "password" => "wrong-password"
          }
        })

      assert redirected_to(conn) == "/sign-in"
    end
  end

  describe "multi-account routes" do
    test "link route requires authentication", %{conn: conn, alice: alice} do
      conn = get(conn, ~p"/link/p/#{alice.id}")

      # Should redirect to sign-in since no user is authenticated
      assert redirected_to(conn) =~ "/sign-in"
    end

    test "switch route requires authentication", %{conn: conn, alice: alice} do
      conn = get(conn, ~p"/link/switch_to/#{alice.id}")

      # Should redirect to sign-out since no user is authenticated
      assert redirected_to(conn) == "/sign-out"
    end

    test "link sets up multi-account session for primary user", %{
      conn: conn,
      alice: alice,
      password: password
    } do
      # Sign in as Alice
      conn =
        post(conn, ~p"/auth/user/password/sign_in", %{
          "user" => %{"email" => to_string(alice.email), "password" => password}
        })

      conn = get(recycle(conn), ~p"/link/p/#{alice.id}")

      # Should set up multi-account session and redirect to sign-in
      assert redir = redirected_to(conn)
      assert redir =~ "/sign-in"
      assert redir =~ "return_to"
    end

    test "full link and switch flow", %{conn: conn, alice: alice, bob: bob, password: password} do
      # 1. Sign in as Alice
      conn =
        post(conn, ~p"/auth/user/password/sign_in", %{
          "user" => %{"email" => to_string(alice.email), "password" => password}
        })

      # 2. Start multi-account linking (Alice is primary)
      conn = get(recycle(conn), ~p"/link/p/#{alice.id}")
      assert redirected_to(conn) =~ "/sign-in"

      # 3. Sign in as Bob (linking step)
      conn =
        post(recycle(conn), ~p"/auth/user/password/sign_in", %{
          "user" => %{"email" => to_string(bob.email), "password" => password}
        })

      # The return_to should redirect to the link endpoint
      conn = get(recycle(conn), ~p"/link/p/#{alice.id}")

      # Bob should now be linked to Alice
      assert redirected_to(conn) == "/"

      # 4. Switch back to Alice
      conn = get(recycle(conn), ~p"/link/switch_to/#{alice.id}")
      assert redirected_to(conn) == "/"
    end
  end

  describe "sign out" do
    test "sign out clears session", %{conn: conn, alice: alice, password: password} do
      conn =
        post(conn, ~p"/auth/user/password/sign_in", %{
          "user" => %{"email" => to_string(alice.email), "password" => password}
        })

      conn = get(recycle(conn), ~p"/sign-out")
      assert redirected_to(conn) == "/"
    end
  end
end
