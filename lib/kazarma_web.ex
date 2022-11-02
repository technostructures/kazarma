# SPDX-FileCopyrightText: 2020-2021 The Kazarma Team
# SPDX-License-Identifier: AGPL-3.0-only

defmodule KazarmaWeb do
  @moduledoc """
  The entrypoint for defining your web interface, such
  as controllers, views, channels and so on.

  This can be used in your application as:

      use KazarmaWeb, :controller
      use KazarmaWeb, :view

  The definitions below will be executed for every view,
  controller, etc, so keep them short and clean, focused
  on imports, uses and aliases.

  Do NOT define functions inside the quoted expressions
  below. Instead, define any helper function in modules
  and import those modules here.
  """

  def controller do
    quote do
      use Phoenix.Controller, namespace: KazarmaWeb

      import Plug.Conn
      import KazarmaWeb.Gettext
      alias KazarmaWeb.Router.Helpers, as: Routes
    end
  end

  def view do
    quote do
      use Phoenix.View,
        root: "lib/kazarma_web/templates",
        namespace: KazarmaWeb

      # Import convenience functions from controllers
      import Phoenix.Controller,
        only: [get_flash: 1, get_flash: 2, view_module: 1, view_template: 1]

      # Include shared imports and aliases for views
      unquote(view_helpers())
    end
  end

  defmodule RouterHelpers do
    @moduledoc false

    defmacro live_or_json(path, live_view, action \\ nil, opts \\ []) do
      quote bind_quoted: binding() do
        {action, router_options} =
          Phoenix.LiveView.Router.__live__(__MODULE__, live_view, action, opts)

        Phoenix.Router.get(path, KazarmaWeb.LiveOrJsonPlug, action, router_options)
      end
    end
  end

  def router do
    quote do
      use Phoenix.Router

      import Plug.Conn
      import Phoenix.Component
      import Phoenix.LiveView.Router
      import Phoenix.Controller

      require KazarmaWeb.RouterHelpers
      import KazarmaWeb.RouterHelpers
    end
  end

  def channel do
    quote do
      use Phoenix.Channel
      import KazarmaWeb.Gettext
    end
  end

  def live_view do
    quote do
      use Phoenix.LiveView, layout: {KazarmaWeb.LayoutView, "live.html"}

      unquote(view_helpers())
    end
  end

  defp view_helpers do
    quote do
      # Use all HTML functionality (forms, tags, etc)
      use Phoenix.HTML

      import Phoenix.Component

      # Import basic rendering functionality (render, render_layout, etc)
      import Phoenix.View

      import KazarmaWeb.ErrorHelpers
      import KazarmaWeb.Gettext
      alias KazarmaWeb.Router.Helpers, as: Routes
    end
  end

  @doc """
  When used, dispatch to the appropriate controller/view/etc.
  """
  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
