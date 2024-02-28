defmodule ElixirLS.LanguageServer.LocationTest do
  use ExUnit.Case, async: false

  alias ElixirLS.LanguageServer.Location

  setup do
    elixir_src = Path.join(File.cwd!(), "/test/misc/mock_elixir_src")
    # TODO make this work and expose via config
    Application.put_env(:elixir_sense, :elixir_src, elixir_src)

    on_exit(fn ->
      Application.delete_env(:elixir_sense, :elixir_src)
    end)
  end

  describe "find_mod_fun_source/3" do
    test "returns location of a core Elixir function" do
      if not File.exists?(String.module_info(:compile)[:source]) do
        assert %Location{type: :function, line: 26, column: 3, file: file} =
                 Location.find_mod_fun_source(String, :length, 1)

        assert String.ends_with?(file, "/mock_elixir_src/lib/elixir/lib/string.ex")
      else
        assert %Location{type: :function, file: file} =
                 Location.find_mod_fun_source(String, :length, 1)

        assert file == Path.expand(String.module_info(:compile)[:source])
      end
    end
  end

  describe "find_type_source/3" do
    test "returns location of a core Elixir type" do
      if not File.exists?(String.module_info(:compile)[:source]) do
        assert %Location{type: :typespec, line: 11, column: 3, file: file} =
                 Location.find_type_source(String, :t, 0)

        assert String.ends_with?(file, "/mock_elixir_src/lib/elixir/lib/string.ex")
      else
        assert %Location{type: :typespec, file: file} =
                 Location.find_type_source(String, :t, 0)

        assert file == Path.expand(String.module_info(:compile)[:source])
      end
    end
  end
end
