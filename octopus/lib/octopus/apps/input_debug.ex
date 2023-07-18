defmodule Octopus.Apps.InputDebug do
  use Octopus.App
  require Logger

  alias Octopus.ColorPalette
  alias Octopus.Protobuf.{Frame, InputEvent}
  alias Octopus.Apps.Input.{ButtonState, JoyState}

  @frame_rate 60
  @frame_time_ms trunc(1000 / @frame_rate)

  defmodule Screen do
    defstruct [:pixels]

    def new() do
      %Screen{
        pixels:
          [
            0
          ]
          #   1,
          #   2,
          #   3,
          #   0,
          #   1,
          #   2,
          #   3,
          #   4,
          #   5,
          #   6,
          #   7,
          #   4,
          #   5,
          #   6,
          #   7,
          #   8,
          #   9,
          #   10,
          #   11,
          #   8,
          #   9,
          #   10,
          #   11,
          #   12,
          #   13,
          #   14,
          #   15,
          #   12,
          #   13,
          #   14,
          #   15
          # ]
          |> Stream.cycle()
          |> Stream.take(8 * 8)
          |> Enum.to_list()
      }
    end

    defp index_to_coord(i) do
      {rem(i, 8), floor(i / 8)}
    end

    def set_pixels(%Screen{} = screen, tuples) do
      screen_map =
        screen.pixels
        |> Enum.with_index()
        |> Enum.reduce(%{}, fn {v, i}, acc ->
          acc
          |> Map.put(index_to_coord(i), v)
        end)

      screen_map =
        tuples
        |> Enum.reduce(screen_map, fn {coord, value}, acc ->
          acc |> Map.put(coord, value)
        end)

      new_pixels =
        0..63
        |> Enum.reduce([], fn i, acc ->
          [
            screen_map
            |> Map.get(index_to_coord(i))
            | acc
          ]
        end)
        |> Enum.reverse()

      %Screen{screen | pixels: new_pixels}
    end
  end

  defmodule State do
    defstruct [:position, :color, :palette, :screen, :button_state]
  end

  def name(), do: "Input Debugger"

  def init(_args) do
    state = %State{
      position: 0,
      color: 1,
      palette: ColorPalette.load("pico-8"),
      screen: Screen.new(),
      button_state: ButtonState.new()
    }

    :timer.send_interval(@frame_time_ms, :tick)
    {:ok, state}
  end

  def handle_info(:tick, %State{} = state) do
    render_frame(state)
    {:noreply, state}
  end

  def handle_input(
        %InputEvent{type: type, value: value} = event,
        %State{button_state: bs} = state
      ) do
    Logger.info("Input Debug: #{inspect(event)}")

    new_bs = bs |> ButtonState.handle_event(type, value) |> IO.inspect()

    {:noreply, %State{state | button_state: new_bs}}
  end

  defp screen_button_color(sb_index), do: sb_index + 4

  defp render_frame(%State{button_state: bs} = state) do
    # collect some painting
    pixel_tuples =
      [
        {:BUTTON_1, {0, 1}},
        {:BUTTON_2, {0, 0}},
        {:BUTTON_3, {1, 0}},
        {:BUTTON_4, {2, 0}},
        {:BUTTON_5, {3, 0}},
        {:BUTTON_6, {4, 0}},
        {:BUTTON_7, {5, 0}},
        {:BUTTON_8, {6, 0}},
        {:BUTTON_9, {7, 0}},
        {:BUTTON_10, {7, 1}}
      ]
      |> Enum.with_index()
      |> Enum.reduce([], fn {{b, coord}, index}, acc ->
        [
          {coord,
           if bs |> ButtonState.button?(b) do
             screen_button_color(index)
           else
             1
           end}
          | acc
        ]
      end)

    # Paint some joysticks
    screen =
      [{bs.joy1, {0, 3}}, {bs.joy2, {5, 3}}]
      |> Enum.map(fn {joy, {x, y}} ->
        [
          {:a, {0, 0}},
          {:b, {2, 0}},
          {:u, {1, 1}},
          {:d, {1, 3}},
          {:l, {0, 2}},
          {:r, {2, 2}},
          {:middle, {1, 2}}
        ]
        |> Enum.map(fn {button, {offset_x, offset_y}} ->
          {{x + offset_x, y + offset_y},
           if JoyState.button?(joy, button) do
             case button do
               :a -> 8
               :b -> 12
               _ -> 7
             end
           else
             cond do
               button in [:a, :b] -> 2
               true -> 5
             end
           end}
        end)
      end)
      |> Enum.reduce(state.screen, fn tuplelist, acc ->
        acc |> Screen.set_pixels(tuplelist)
      end)

    # Paint some pixels
    screen =
      screen
      |> Screen.set_pixels(pixel_tuples)

    paint_screen = fn data, screen_index ->
      data
      |> Enum.with_index()
      |> Enum.map(fn {v, i} ->
        if floor(i / 64) == screen_index do
          screen_button_color(screen_index)
        else
          v
        end
      end)
      |> Enum.to_list()
    end

    # Put screen on all windows
    data =
      screen.pixels
      #      |> IO.inspect()
      |> Stream.cycle()
      |> Stream.take(8 * 8 * 10)
      |> Enum.to_list()

    # make whole window light up for screen buttons
    data =
      0..9
      |> Enum.reduce(data, fn i, acc ->
        cond do
          state.button_state |> ButtonState.screen_button?(i) ->
            paint_screen.(acc, i)

          true ->
            acc
        end
      end)

    %Frame{
      data: data,
      palette: state.palette
    }
    |> send_frame()
  end
end
