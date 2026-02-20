defmodule Mix.Tasks.AshMultiAccount.InstallTest do
  use ExUnit.Case, async: true
  import Igniter.Test

  @install_args [
    "--user",
    "Test.Accounts.User",
    "--linked-account",
    "Test.Accounts.LinkedAccount"
  ]

  @user_resource_file %{
    "lib/test/accounts/user.ex" => """
    defmodule Test.Accounts.User do
      use Ash.Resource,
        domain: Test.Accounts,
        extensions: [AshAuthentication]
    end
    """
  }

  describe "user resource setup" do
    test "adds AshMultiAccount extension to existing user resource" do
      igniter = test_project(files: @user_resource_file)

      igniter
      |> Igniter.compose_task("ash_multi_account.install", @install_args)
      |> assert_has_patch("lib/test/accounts/user.ex", """
       + |    extensions: [AshMultiAccount, AshAuthentication]
      """)
      |> assert_has_patch("lib/test/accounts/user.ex", """
       + |  multi_account do
       + |    linked_account_resource(Test.Accounts.LinkedAccount)
       + |  end
      """)
    end

    test "warns when user resource not found" do
      igniter = test_project()

      igniter
      |> Igniter.compose_task("ash_multi_account.install", @install_args)
      |> assert_has_warning(fn warning ->
        warning =~ "Could not find User resource" and
          warning =~ "Test.Accounts.User"
      end)
    end
  end

  describe "linked account resource setup" do
    test "creates linked account resource when it does not exist" do
      igniter = test_project(files: @user_resource_file)

      igniter
      |> Igniter.compose_task("ash_multi_account.install", @install_args)
      |> assert_creates("lib/test/accounts/linked_account.ex")
    end

    test "adds extension to existing linked account resource" do
      files =
        Map.merge(@user_resource_file, %{
          "lib/test/accounts/linked_account.ex" => """
          defmodule Test.Accounts.LinkedAccount do
            use Ash.Resource,
              domain: Test.Accounts
          end
          """
        })

      igniter = test_project(files: files)

      igniter
      |> Igniter.compose_task("ash_multi_account.install", @install_args)
      |> assert_has_patch("lib/test/accounts/linked_account.ex", """
       + |  use Ash.Resource, domain: Test.Accounts, extensions: [AshMultiAccount.LinkedAccount]
      """)
      |> assert_has_patch("lib/test/accounts/linked_account.ex", """
       + |  multi_account do
       + |    user_resource(Test.Accounts.User)
       + |  end
      """)
    end
  end

  describe "domain registration" do
    test "registers linked account in user's domain" do
      files =
        Map.merge(@user_resource_file, %{
          "lib/test/accounts.ex" => """
          defmodule Test.Accounts do
            use Ash.Domain

            resources do
              resource Test.Accounts.User
            end
          end
          """
        })

      igniter = test_project(files: files)

      igniter
      |> Igniter.compose_task("ash_multi_account.install", @install_args)
      |> assert_has_patch("lib/test/accounts.ex", """
       + |    resource(Test.Accounts.LinkedAccount)
      """)
    end
  end

  describe "multi account controller" do
    test "creates multi account controller" do
      igniter = phx_test_project()

      igniter
      |> Igniter.compose_task("ash_multi_account.install", @install_args)
      |> assert_creates("lib/test_web/controllers/multi_account_controller.ex")
    end

    test "does not overwrite existing controller" do
      igniter =
        phx_test_project(
          files: %{
            "lib/test_web/controllers/multi_account_controller.ex" => """
            defmodule TestWeb.MultiAccountController do
              use TestWeb, :controller
              use AshMultiAccount.Phoenix.Controller,
                user_resource: Test.Accounts.User
            end
            """
          }
        )

      igniter
      |> Igniter.compose_task("ash_multi_account.install", @install_args)
      |> assert_unchanged("lib/test_web/controllers/multi_account_controller.ex")
    end
  end

  describe "router setup" do
    test "adds plug and routes to router" do
      igniter = phx_test_project()

      igniter
      |> Igniter.compose_task("ash_multi_account.install", @install_args)
      |> assert_has_patch("lib/test_web/router.ex", """
       + |    plug AshMultiAccount.Phoenix.Plug
      """)
      |> assert_has_patch("lib/test_web/router.ex", """
       + |    multi_account_routes(MultiAccountController, Test.Accounts.User)
      """)
    end

    test "adds use AshMultiAccount.Phoenix.Router to router" do
      igniter = phx_test_project()

      igniter
      |> Igniter.compose_task("ash_multi_account.install", @install_args)
      |> assert_has_patch("lib/test_web/router.ex", """
       + |  use AshMultiAccount.Phoenix.Router
      """)
    end
  end

  describe "notices" do
    test "adds LiveView hook notice" do
      igniter = test_project()

      igniter
      |> Igniter.compose_task("ash_multi_account.install", @install_args)
      |> assert_has_notice(fn notice ->
        notice =~ "LiveView hook setup required"
      end)
    end

    test "adds account switcher component notice" do
      igniter = test_project()

      igniter
      |> Igniter.compose_task("ash_multi_account.install", @install_args)
      |> assert_has_notice(fn notice ->
        notice =~ "Account switcher component"
      end)
    end
  end

  describe "auth controller patching" do
    test "emits notice when no auth controller found" do
      igniter = test_project(files: @user_resource_file)

      igniter
      |> Igniter.compose_task("ash_multi_account.install", @install_args)
      |> assert_has_notice(fn notice ->
        notice =~ "No auth controller found"
      end)
    end

    test "patches auth controller with put_user_id after store_in_session" do
      files =
        Map.merge(@user_resource_file, %{
          "lib/test_web/controllers/auth_controller.ex" => """
          defmodule TestWeb.AuthController do
            use TestWeb, :controller
            use AshAuthentication.Phoenix.Controller

            def success(conn, _activity, user, _token) do
              conn
              |> store_in_session(user)
              |> assign(:current_user, user)
              |> redirect(to: "/")
            end
          end
          """
        })

      args = @install_args ++ ["--auth-controller", "TestWeb.AuthController"]
      igniter = phx_test_project(files: files)

      igniter
      |> Igniter.compose_task("ash_multi_account.install", args)
      |> assert_has_patch("lib/test_web/controllers/auth_controller.ex", """
       + |    |> AshMultiAccount.Phoenix.Session.put_user_id(user.id)
      """)
    end

    test "does not inject put_user_id if already present" do
      files =
        Map.merge(@user_resource_file, %{
          "lib/test_web/controllers/auth_controller.ex" => """
          defmodule TestWeb.AuthController do
            use TestWeb, :controller
            use AshAuthentication.Phoenix.Controller

            def success(conn, _activity, user, _token) do
              conn
              |> store_in_session(user)
              |> AshMultiAccount.Phoenix.Session.put_user_id(user.id)
              |> assign(:current_user, user)
              |> redirect(to: "/")
            end
          end
          """
        })

      args = @install_args ++ ["--auth-controller", "TestWeb.AuthController"]
      igniter = phx_test_project(files: files)

      igniter
      |> Igniter.compose_task("ash_multi_account.install", args)
      |> assert_unchanged("lib/test_web/controllers/auth_controller.ex")
    end
  end

  describe "idempotency" do
    test "running twice on user resource produces no additional changes" do
      files =
        Map.merge(@user_resource_file, %{
          "lib/test/accounts.ex" => """
          defmodule Test.Accounts do
            use Ash.Domain

            resources do
              resource Test.Accounts.User
            end
          end
          """
        })

      igniter = test_project(files: files)

      first_run =
        igniter
        |> Igniter.compose_task("ash_multi_account.install", @install_args)
        |> apply_igniter!()

      first_run
      |> Igniter.compose_task("ash_multi_account.install", @install_args)
      |> assert_unchanged("lib/test/accounts/user.ex")
      |> assert_unchanged("lib/test/accounts/linked_account.ex")
      |> assert_unchanged("lib/test/accounts.ex")
    end
  end
end
