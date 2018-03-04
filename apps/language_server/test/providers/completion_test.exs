defmodule ElixirLS.LanguageServer.Providers.CompletionTest do
  require Logger
  alias ElixirLS.LanguageServer.Providers.Completion
  use ExUnit.Case

  test "returns all Logger completions on normal require" do
    text = ~S[
      defmodule MyModule do
        require Logger

        def dummy_function() do
          Logger.
        end
      end
    ]

    {:ok, %{"items" => items}} = Completion.completion(text, 5, 12, true)

    logger_labels =
      ["warn", "debug", "error", "info"]
      |> Enum.map(&(&1 <> "(chardata_or_fun,metadata \\\\ [])"))

    for lfn <- logger_labels do
      assert(Enum.any?(items, fn %{"label" => label} -> label == lfn end))
    end
  end

  test "returns all Logger completions on require with alias" do
    text = ~S[
      defmodule MyModule do
        require Logger, as: LAlias

        def dummy_function() do
          LAlias.
        end
      end
    ]

    {:ok, %{"items" => items}} = Completion.completion(text, 5, 12, true)

    logger_labels =
      ["warn", "debug", "error", "info"]
      |> Enum.map(&(&1 <> "(chardata_or_fun,metadata \\\\ [])"))

    for lfn <- logger_labels do
      assert(Enum.any?(items, fn %{"label" => label} -> label == lfn end))
    end
  end
end