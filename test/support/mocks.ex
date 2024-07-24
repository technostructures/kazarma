# SPDX-FileCopyrightText: 2020-2024 Technostructures
# SPDX-License-Identifier: AGPL-3.0-only
Mox.defmock(Kazarma.Matrix.TestClient, for: MatrixAppService.ClientBehaviour)
Mox.defmock(Kazarma.ActivityPub.TestServer, for: Kazarma.ActivityPub.ServerBehaviour)

defmodule Kazarma.Mocks do
  @moduledoc """
    This module exports convenience macros for Mox.
  """

  @doc """
  This macro is a wrapper for `Mox.expect/4`, that replaces the callback by one
  that accepts any arguments and then tries to match, so we can raise
  `ExUnit.AssertionError`s that are nicely displayed.

  ```
  expect(Module, :fun_name, fn
    pattern1, pattern2 -> :foo
    pattern3, pattern4 -> :bar
  end)
  ```
  =>
  ```
  expect(Module, :fun_name, fn
    a1, a2 ->
      case {a1, a2} do
        {pattern1, pattern2} -> :foo
        {pattern3, pattern4} -> :bar
        _ -> raise AssertionError(...)
      end
  end)
  ```
  """
  defmacro expect(mock, fun_name, times \\ 1, callback) do
    quote do
      Mox.expect(
        unquote(mock),
        unquote(fun_name),
        unquote(times),
        unquote(callback_with_error(callback, __CALLER__))
      )
    end

    # expanded = Macro.expand(ret, __ENV__) |> Macro.to_string()
  end

  defp callback_with_error({:fn, _, clauses} = callback, caller) do
    quote do
      fn unquote_splicing(catch_all_patterns(clauses)) ->
        unquote(callback_case(callback, caller))
      end
    end
  end

  # Replace a list of pattern with a list of catch-all patterns.
  defp catch_all_patterns([
         {:->, _, [pattern, _]}
         | _
       ]) do
    case pattern do
      [] ->
        []

      [_] ->
        quote do
          [a1]
        end

      [_, _] ->
        quote do
          [a1, a2]
        end

      [_, _, _] ->
        quote do
          [a1, a2, a3]
        end

      [_, _, _, _] ->
        quote do
          [a1, a2, a3, a4]
        end

      [_, _, _, _, _] ->
        quote do
          [a1, a2, a3, a4, a5]
        end

      [_, _, _, _, _, _] ->
        quote do
          [a1, a2, a3, a4, a5, a6]
        end
    end
  end

  defp callback_case({:fn, _, [{:->, _, [[], body]}]}, _caller), do: body

  defp callback_case({:fn, _, [_ | _] = clauses} = callback, caller) do
    case_clauses = Enum.map(clauses, &case_clause(&1, caller)) ++ error_clause(callback, caller)

    quote do
      case unquote(unique_or_tuple(catch_all_patterns(clauses))) do
        unquote(case_clauses)
      end
    end
  end

  defp unique_or_tuple([pattern]), do: pattern
  # defp unique_or_tuple([pattern]), do: {:{}, [], [pattern]}
  defp unique_or_tuple([_ | _] = patterns), do: {:{}, [], patterns}

  defp case_clause({:->, env, [patterns, body]}, caller) do
    pattern =
      patterns
      |> Enum.map(&ExUnit.Assertions.__expand_pattern__(&1, caller))
      |> unique_or_tuple()

    {:->, env, [[pattern], body]}
  end

  defp error_clause({:fn, _, clauses} = callback, caller) do
    body =
      Enum.map(clauses, fn
        {:->, _env, [patterns, _body]} ->
          pins = collect_pins_from_pattern(patterns, Macro.Env.vars(caller))

          expanded_patterns = Enum.map(patterns, &Macro.expand(&1, caller))
          # {:->, _env, [expanded_patterns, _body]}  = Macro.expand(clause, __CALLER__)

          quote do
            raise ExUnit.AssertionError,
              left: unquote(Macro.escape(expanded_patterns)),
              right: unquote(right_quote(patterns)),
              expr: unquote(Macro.escape(callback)),
              message:
                "Mox expectation failed: no function clause matching" <>
                  ExUnit.Assertions.__pins__(unquote(pins)),
              context: {:match, unquote(pins)}
          end
      end)

    quote do
      right ->
        unquote({:__block__, [], body})
    end
  end

  defp right_quote([_]) do
    quote do
      [right]
    end
  end

  defp right_quote([_ | _]) do
    quote do
      Tuple.to_list(right)
    end
  end

  defp collect_pins_from_pattern(list, vars) when is_list(list) do
    Enum.map(list, &collect_pins_from_pattern(&1, vars))
    |> Enum.concat()
  end

  defp collect_pins_from_pattern(expr, vars) do
    {_, pins} =
      Macro.prewalk(expr, %{}, fn
        {:quote, _, [_]}, acc ->
          {:ok, acc}

        {:quote, _, [_, _]}, acc ->
          {:ok, acc}

        {:^, _, [var]}, acc ->
          identifier = var_context(var)

          if identifier in vars do
            {:ok, Map.put(acc, var_context(var), var)}
          else
            {:ok, acc}
          end

        form, acc ->
          {form, acc}
      end)

    Enum.to_list(pins)
  end

  defp var_context({name, meta, context}) do
    {name, meta[:counter] || context}
  end
end
