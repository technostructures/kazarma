# SPDX-FileCopyrightText: 2020-2023 The Kazarma Team
# SPDX-License-Identifier: AGPL-3.0-only
defmodule KazarmaWeb.HtmlChecker do
  @moduledoc """
     This module helps running tests involving html displayed by the app
  """

  use ExUnit.CaseTemplate

  @doc """
  This macro is used to help check more easily that the html generated contains the required data

  """

  defmacro assert_html_include(
             html,
             selector,
             times \\ 1,
             attributes \\ Macro.escape(%{}),
             text \\ nil
           ) do
    quote do
      assert_html_verify(
        unquote(html),
        unquote(selector),
        unquote(times),
        unquote(attributes),
        unquote(text)
      )
    end
  end

  defmacro refute_html_include(
             html,
             selector,
             attributes \\ Macro.escape(%{}),
             text \\ nil
           ) do
    quote do
      assert_html_verify(
        unquote(html),
        unquote(selector),
        unquote(0),
        unquote(attributes),
        unquote(text)
      )
    end
  end

  def assert_html_verify(html, selector, times, attributes, text) do
    res =
      html
      |> Floki.parse_fragment!()
      |> Floki.find(to_string(selector))
      |> filter_attributes(attributes)
      |> filter_text(text)

    assert length(res) == times
    html
  end

  defp filter_attributes(fragments, attribute) when attribute == %{}, do: fragments

  defp filter_attributes(fragments, attributes) do
    fragments
    |> Enum.filter(fn frag ->
      Enum.all?(attributes, fn {attr, attr_content} ->
        Floki.attribute(frag, "#{attr}") == [attr_content]
      end)
    end)
  end

  defp filter_text(fragments, nil), do: fragments

  defp filter_text(fragments, text) do
    Enum.filter(fragments, fn frag -> Floki.text(frag) =~ text end)
  end
end
