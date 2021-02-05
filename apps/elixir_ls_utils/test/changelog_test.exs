defmodule ElixirLS.Utils.ChangelogTest do
  use ExUnit.Case, async: true

  test "changelog pull requests are correctly linked" do
    contents = File.read!("../../CHANGELOG.md")
    String.split(contents, "\n", trim: true)
    |> Enum.each(fn line ->
      case Regex.run(~r/\/pull\/(\d+)/, line, capture: :all_but_first) do
        [pr_number] ->
          assert String.match?(line, ~r/\[.*#{pr_number}\]/)
          _ -> nil
      end
    end)
  end
end
