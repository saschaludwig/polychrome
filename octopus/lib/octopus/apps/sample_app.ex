defmodule Octopus.Apps.SampleApp do
  use Octopus.App
  require Logger

  alias Octopus.Protobuf.{Frame, InputEvent}

  defmodule State do
    defstruct [:index, :delay]
  end

  @palette Octopus.ColorPalette.load("lava-gb")
  @pixel_count 640

  # TODO: use the new canvas module

  def name(), do: "Sample App"

  def init(_args) do
    state = %State{index: 0, delay: 100}

    send(self(), :tick)

    {:ok, state}
  end

  def handle_info(:tick, %State{} = state) do
    data =
      0..(@pixel_count - 1)
      |> Enum.map(fn _ -> 0 end)
      |> List.update_at(state.index, fn _ -> 3 end)

    send_frame(%Frame{data: data, palette: @palette})
    :timer.send_after(state.delay, self(), :tick)

    {:noreply, increment_index(state)}
  end

  def handle_input(%InputEvent{type: :BUTTON, value: 0}, state) do
    {:noreply, %State{state | delay: state.delay + 10}}
  end

  def handle_input(%InputEvent{type: :BUTTON, value: 1}, state) do
    {:noreply, %State{state | delay: max(10, state.delay - 10)}}
  end

  def handle_input(_input_event, state) do
    {:noreply, state}
  end

  defp increment_index(%State{index: index} = state) when index >= @pixel_count do
    %State{state | index: 0}
  end

  defp increment_index(%State{index: index} = state) do
    %State{state | index: index + 1}
  end
end
