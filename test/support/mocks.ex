# SPDX-FileCopyrightText: 2020-2021 The Kazarma Team
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
  end

  defp callback_with_error({:fn, _, clauses} = callback, caller) do
    {:fn, [],
     [
       {:->, [],
        [
          catch_all_patterns(clauses),
          callback_case(callback, caller)
        ]}
     ]}
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
    case_clauses = Enum.map(clauses, &case_clause/1) ++ error_clause(callback, caller)

    quote do
      case unquote(unique_or_tuple(catch_all_patterns(clauses))) do
        unquote(case_clauses)
      end
    end
  end

  defp unique_or_tuple([pattern]), do: pattern
  defp unique_or_tuple([_ | _] = patterns), do: {:{}, [], patterns}

  defp case_clause({:->, env, [patterns, body]}) do
    pattern =
      patterns
      |> Enum.map(&fix_ignored/1)
      |> unique_or_tuple()

    {:->, env, [[pattern], body]}
  end

  defp fix_ignored(pattern) do
    Macro.prewalk(pattern, fn
      {id, env, rest} = node when is_atom(id) ->
        case Atom.to_string(id) do
          "_" <> _ ->
            {:_, env, nil}

          _ ->
            node
        end

      other ->
        other
    end)
  end

  defp error_clause({:fn, _, clauses} = callback, caller) do
    # @TODO: handle pins
    pins = []

    body =
      Enum.map(clauses, fn
        {:->, _env, [patterns, _body]} = clause ->
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
      right
    end
  end

  defp right_quote([_ | _]) do
    quote do
      Tuple.to_list(right)
    end
  end
end
