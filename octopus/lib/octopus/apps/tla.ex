defmodule Octopus.Apps.Tla do
  use Octopus.App, category: :animation

  alias Octopus.Canvas
  alias Octopus.Font

  # @words_file "/usr/share/dict/words"
  @words_file "/Users/luka/code/letterbox/octopus/foo.txt"

  defmodule Words do
    defstruct [:words, :lookup]

    def load(path) do
      words =
        path
        |> File.stream!()
        |> Stream.map(&String.trim/1)
        |> Stream.map(&String.upcase/1)
        |> Stream.filter(&(String.length(&1) == 10))
        |> Stream.with_index()

      lookup =
        words
        |> Stream.map(fn {word_1, index_1} ->
          new_candidates =
            words
            |> Enum.reduce([], fn {word_2, index_2}, candidates ->
              if index_1 == index_2 do
                candidates
              else
                [{index_2, String.jaro_distance(word_1, word_2)} | candidates]
              end
            end)
            |> Enum.sort_by(&elem(&1, 1), :desc)
            |> Enum.map(&elem(&1, 0))
            |> Enum.take(100)

          {index_1, new_candidates}
        end)
        |> Enum.into(%{})

      %__MODULE__{words: words |> Enum.to_list() |> Enum.map(&elem(&1, 0)), lookup: lookup}
    end

    def next(%__MODULE__{words: words, lookup: lookup}, current_word, exclude \\ []) do
      current_word_index = Enum.find_index(words, &(&1 == current_word))

      candidates =
        lookup[current_word_index]
        |> Enum.map(&Enum.at(words, &1))
        |> Enum.reject(fn word -> word in exclude end)
        |> Enum.take(10)

      Enum.random(candidates)
    end
  end

  def name, do: "TLA"

  def init(_) do
    words = Words.load(@words_file)
    send(self(), :next_word)

    current_word = Enum.random(words.words)
    font = Font.load("ddp-DoDonPachi (Cave)")

    {:ok, %{words: words, current_word: current_word, last_words: [], font: font}}
  end

  def handle_info(
        :next_word,
        %{words: words, current_word: current_word, last_words: last_words, font: font} = state
      ) do
    last_words = [current_word | last_words] |> Enum.take(100)
    current_word = Words.next(words, current_word, last_words)

    Canvas.new(80, 8)
    |> Canvas.put_string({0, 0}, current_word, font)
    |> Canvas.to_frame()
    |> send_frame()

    Process.send_after(self(), :next_word, 1000)

    {:noreply, %{state | current_word: current_word, last_words: last_words}}
  end
end
