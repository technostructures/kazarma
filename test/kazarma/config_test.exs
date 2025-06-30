# SPDX-FileCopyrightText: 2020-2024 Technostructures
# SPDX-License-Identifier: AGPL-3.0-only
defmodule Kazarma.ConfigTest do
  use KazarmaWeb.ConnCase, async: false

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest
  @endpoint KazarmaWeb.Endpoint

  describe "html_search" do
    setup :set_mox_from_context
    setup :verify_on_exit!

    test "when false (default) it does not display the search form", %{conn: conn} do
      # the default is inverted in test environment
      Application.put_env(:kazarma, :html_search, false)

      on_exit(fn ->
        Application.put_env(:kazarma, :html_search, true)
      end)

      {:ok, _view, html} = live(conn, "/")

      refute html =~ "search-form"
    end

    test "when true it displays the search form", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      assert html =~ "search-form"
    end
  end

  # describe "html_actor_view_include_remote" do
  #   setup :set_mox_from_context
  #   setup :verify_on_exit!
  #
  #   setup do
  #     create_ap_user_alice()
  #
  #     :ok
  #   end
  #
  #   test "when false (default) it does not display remote actor views", %{conn: conn} do
  #     # the default is inverted in test environment
  #     Application.put_env(:kazarma, :html_actor_view_include_remote, false)
  #
  #     on_exit(fn ->
  #       Application.put_env(:kazarma, :html_actor_view_include_remote, true)
  #     end)
  #
  #     assert {:error, {:live_redirect, %{to: "/", flash: %{"error" => "User not found"}}}} =
  #              live(conn, "/pleroma.com/alice")
  #   end
  #
  #   test "when true it displays remote actor views", %{conn: conn} do
  #     {:ok, _view, html} = live(conn, "/pleroma.com/alice")
  #
  #     assert html =~ "Alice"
  #   end
  # end

  describe "frontpage_help" do
    setup :set_mox_from_context
    setup :verify_on_exit!

    test "when true (default) it displays the frontpage help", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      assert html =~ "frontpage-help"
    end

    test "when false it does not display the frontpage help", %{conn: conn} do
      Application.put_env(:kazarma, :frontpage_help, false)

      on_exit(fn ->
        Application.put_env(:kazarma, :frontpage_help, true)
      end)

      {:ok, _view, html} = live(conn, "/")

      refute html =~ "frontpage-help"
    end
  end

  describe "frontpage_before_text" do
    setup :set_mox_from_context
    setup :verify_on_exit!

    setup do
      Application.put_env(:kazarma, :frontpage_before_text, "FRONTPAGE BEFORE TEXT")

      on_exit(fn ->
        Application.put_env(:kazarma, :frontpage_before_text, nil)
      end)
    end

    test "it displays the given text", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      assert html =~ "FRONTPAGE BEFORE TEXT"
    end
  end

  describe "frontpage_after_text" do
    setup :set_mox_from_context
    setup :verify_on_exit!

    setup do
      Application.put_env(:kazarma, :frontpage_after_text, "FRONTPAGE AFTER TEXT")

      on_exit(fn ->
        Application.put_env(:kazarma, :frontpage_after_text, nil)
      end)
    end

    test "it displays the given text", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      assert html =~ "FRONTPAGE AFTER TEXT"
    end
  end
end
