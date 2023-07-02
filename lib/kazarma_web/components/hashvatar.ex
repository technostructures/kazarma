# SPDX-FileCopyrightText: 2020-2023 The Kazarma Team
# SPDX-License-Identifier: AGPL-3.0-only

defmodule KazarmaWeb.Components.Hashvatar do
  @moduledoc """
  Implementation of Hashvatar by François Best

  https://francoisbest.com/posts/2021/hashvatars
  """
  use Phoenix.Component
  use Phoenix.HTML
  import Bitwise

  attr :identifier, :string, required: true
  attr :variant, :atom, default: :normal
  attr :line_color, :string, default: "white"
  attr :radius_factor, :float, default: 0.42

  @doc """
  Generate a SVG hashvatar.

  Options:

  - `identifier` (required): the indentifier used to generate the hashvatar
  - `variant` (default: `:normal`): the variant, can be one of: `:normal`, `:stagger`, `:gem`, `:spider`, `:flower`
  - `line_color` (default: `"white"`): the line color, `"transparent"` is a special case
  - `radius_factor` (default: `0.42`): a coefficient for the circles radii
  """
  def hashvatar(%{variant: variant} = assigns) do
    mix = fn a, b ->
      a * assigns.radius_factor + b * (1 - assigns.radius_factor)
    end

    r1 = if variant == :flower, do: 0.75, else: 1
    r2 = mix.(r1 * :math.sqrt(3) / 2, r1 * 0.75)
    r3 = mix.(r1 * :math.sqrt(2) / 2, r1 * 0.5)
    r4 = mix.(r1 * 0.5, r1 * 0.25)

    bytes = :crypto.hash(:sha256, assigns.identifier)
    %{soul: soul, horcruxes: horcruxes} = hash_soul(bytes)

    inner_radii = [r2, r3, r4, 0]
    outer_radii = [r1, r2, r3, r4]

    sections =
      :binary.bin_to_list(bytes)
      |> Enum.with_index()
      |> Enum.map(fn {value, index} ->
        circle_index = floor(index / 8)
        inner_radius = Enum.at(inner_radii, circle_index)
        outer_radius = Enum.at(outer_radii, circle_index)
        horcrux = Enum.at(horcruxes, circle_index)

        {
          generate_section(%{
            value: value,
            index: index,
            outer_radius: outer_radius,
            inner_radius: inner_radius,
            variant: variant,
            horcrux: horcrux
          }),
          map_value_to_color(%{
            value: value,
            hash_soul: soul,
            circle_soul: horcrux
          })
        }
      end)

    assigns = assign(assigns, :sections, sections)

    ~H"""
    <svg viewBox="-1 -1 2 2" overflow="visible">
      <g>
        <path
          :for={{section, color} <- @sections}
          key={section.index}
          d={section.path}
          fill={color}
          stroke={@line_color}
          stroke-width="0.02"
          stroke-linejoin="round"
          style={"transition: all .15s ease-out 0s; transform: #{section.transform}"}
        />
      </g>
    </svg>
    """
  end

  defp hash_soul(bytes) do
    size = round(byte_size(bytes) / 4)

    <<circle1::binary-size(size), circle2::binary-size(size), circle3::binary-size(size),
      circle4::binary-size(size)>> = bytes

    circles = [
      :binary.bin_to_list(circle1),
      :binary.bin_to_list(circle2),
      :binary.bin_to_list(circle3),
      :binary.bin_to_list(circle4)
    ]

    xor = fn xor, byte -> bxor(xor, byte) end

    %{
      soul: Enum.reduce(:binary.bin_to_list(bytes), 0, xor) / 255 * 2 - 1,
      horcruxes: Enum.map(circles, fn circle -> Enum.reduce(circle, 0, xor) / 255 * 2 - 1 end)
    }
  end

  defp generate_section(
         %{
           index: index,
           outer_radius: outer_radius,
           horcrux: _horcrux,
           variant: variant
         } = params
       ) do
    staggering = staggering(params)

    # angle = (index + 0.5) / 8
    angle_a = index / 8
    angle_b = (index + 1) / 8
    angle_offset = staggering / 8

    arc_radius = arc_radius(params)

    path =
      [
        move_to(%{x: 0, y: 0}),
        line_to(polar_point(outer_radius, angle_a)),
        arc_to(polar_point(outer_radius, angle_b), arc_radius, variant == :spider),
        # close the path
        'Z'
      ]
      |> Enum.join(" ")

    %{
      path: path,
      index: index,
      transform:
        if(angle_offset != 0,
          do: "rotate(#{:erlang.float_to_binary(angle_offset, decimals: 6)}turn)"
        )
    }
  end

  defp staggering(%{variant: :stagger, horcrux: horcrux}), do: horcrux

  defp staggering(%{variant: variant, index: index})
       when variant in [:gem, :flower] do
    circle_index = floor(index / 8)

    case Integer.mod(circle_index, 2) do
      0 -> 0.5
      1 -> 0
    end
  end

  defp staggering(_), do: 0

  defp arc_radius(%{variant: :gem}), do: 0
  defp arc_radius(%{variant: :flower, outer_radius: outer_radius}), do: 0.25 * outer_radius
  defp arc_radius(%{outer_radius: outer_radius}), do: outer_radius

  defp map_value_to_color(%{
         value: value,
         hash_soul: hash_soul,
         circle_soul: circle_soul
       }) do
    color_h = value >>> 4
    color_s = value >>> 2 &&& 0x03
    color_l = value &&& 0x03

    h = 360 * hash_soul + 120 * circle_soul + 30 * color_h / 16
    s = 50 + 50 * color_s / 4
    l = 50 + 40 * color_l / 8

    "hsl(#{h}, #{s}%, #{l}%)"
  end

  defp polar_point(radius, angle) do
    # Angle is expressed as [0,1[
    # -Pi/2 to start at noon and go clockwise
    # Trigonometric rotation + inverted Y = clockwise rotation, nifty!

    %{
      x: radius * :math.cos(2 * :math.pi() * angle - :math.pi() / 2),
      y: radius * :math.sin(2 * :math.pi() * angle - :math.pi() / 2)
    }
  end

  defp move_to(%{x: x, y: y}), do: "M #{x} #{y}"

  defp line_to(%{x: x, y: y}), do: "L #{x} #{y}"

  defp arc_to(%{x: x, y: y}, radius, invert) do
    z = if invert, do: 0, else: 1

    "A #{radius} #{radius} 0 0 #{z} #{x} #{y}"
  end
end
