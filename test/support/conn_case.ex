# SPDX-FileCopyrightText: 2020-2024 Technostructures
# SPDX-License-Identifier: AGPL-3.0-only

defmodule KazarmaWeb.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.

  Such tests rely on `Phoenix.ConnTest` and also
  import other functionality to make it easier
  to build common data structures and query the data layer.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use KazarmaWeb.ConnCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest
      import Phoenix.LiveViewTest
      import KazarmaWeb.ConnCase
      require KazarmaWeb.HtmlChecker
      import KazarmaWeb.HtmlChecker
      require Kazarma.Mocks
      import Kazarma.Mocks
      import Mox, except: [expect: 3, expect: 4]

      alias KazarmaWeb.Router.Helpers, as: Routes

      # The default endpoint for testing
      @endpoint KazarmaWeb.Endpoint
    end
  end

  setup tags do
    {:ok, _} = Cachex.clear(:ap_actor_cache)
    {:ok, _} = Cachex.clear(:ap_object_cache)

    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(Kazarma.Repo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)

    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end

  def config_public_bridge(_context) do
    Application.put_env(:kazarma, :public_bridge, true)

    on_exit(fn ->
      Application.put_env(:kazarma, :public_bridge, false)
    end)
  end
end
