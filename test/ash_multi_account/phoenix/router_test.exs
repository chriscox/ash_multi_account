defmodule AshMultiAccount.Phoenix.RouterTest do
  use ExUnit.Case, async: true

  alias AshMultiAccount.Test.Router

  describe "multi_account_routes/3" do
    test "generates link_account route with default path" do
      route =
        Enum.find(Phoenix.Router.routes(Router), fn route ->
          route.plug == AshMultiAccount.Test.Controller and
            route.plug_opts == :link_account
        end)

      assert route != nil
      assert route.path == "/link/p/:primary_user_id"
      assert route.verb == :get
    end

    test "generates switch_to_account route with default path" do
      route =
        Enum.find(Phoenix.Router.routes(Router), fn route ->
          route.plug == AshMultiAccount.Test.Controller and
            route.plug_opts == :switch_to_account
        end)

      assert route != nil
      assert route.path == "/link/switch_to/:user_id"
      assert route.verb == :get
    end
  end
end
