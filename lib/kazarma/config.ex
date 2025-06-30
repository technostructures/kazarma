# SPDX-FileCopyrightText: 2020-2024 Technostructures
# SPDX-License-Identifier: AGPL-3.0-only
defmodule Kazarma.Config do
  @moduledoc """
  Helpers for managing project-wide configuration.
  """
  defmacro __using__(_) do
    quote do
      @matrix_client Application.compile_env!(:kazarma, [:matrix, :client])
      @activitypub_server Application.compile_env!(:kazarma, [:activity_pub, :server])
    end
  end

  def public_bridge?() do
    Application.get_env(:kazarma, :public_bridge)
  end

  def private_bridge?() do
    not Application.get_env(:kazarma, :public_bridge)
  end

  def frontpage_help() do
    Application.get_env(:kazarma, :frontpage_help)
  end

  def frontpage_before_text() do
    Application.get_env(:kazarma, :frontpage_before_text)
  end

  def frontpage_after_text() do
    Application.get_env(:kazarma, :frontpage_after_text)
  end

  def show_search_form() do
    Application.get_env(:kazarma, :html_search)
  end
end
