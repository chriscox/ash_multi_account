defmodule DemoWeb.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.

  Such tests rely on `Phoenix.ConnTest` and also
  import other functionality to make it easier
  to build common data structures and query the data layer.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      # The default endpoint for testing
      @endpoint DemoWeb.Endpoint

      use DemoWeb, :verified_routes

      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest
      import DemoWeb.ConnCase
    end
  end

  # ETS tables are shared (not private?) so the demo app works in both dev and
  # test. Test isolation is achieved via unique email addresses
  # (System.unique_integer) rather than per-process tables or sandboxing.
  setup do
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end
end
