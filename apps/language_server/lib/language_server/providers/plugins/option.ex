defmodule ElixirLS.LanguageServer.Plugins.Option do
  @moduledoc false

  alias ElixirLS.LanguageServer.Plugins.Util
  alias ElixirLS.Utils.Matcher

  def find(options, hint, fun) do
    for option <- options, match_hint?(option, hint) do
      to_suggestion(option, fun)
    end
    |> Enum.sort_by(& &1.label)
  end

  def to_suggestion(option, fun) do
    command =
      if option[:values] not in [nil, []] do
        Util.command(:trigger_suggest)
      end

    %{
      type: :generic,
      kind: :property,
      label: to_string(option.name),
      insert_text: "#{option.name}: ",
      snippet: option[:snippet],
      detail: "#{fun} option",
      documentation: option[:doc],
      command: command
    }
  end

  def match_hint?(option, hint) do
    option
    |> Map.fetch!(:name)
    |> to_string()
    |> Matcher.match?(hint)
  end
end
