
defmodule ElixirLS.LanguageServer.BuildTest do
  use ExUnit.Case
  alias ElixirLS.LanguageServer.Build

  describe "sanitize_root_path/1" do
    test "changes path that ends with . to its directory name" do
      path = "/fake/path"
      assert path == Build.sanitize_root_path("#{path}/.")
    end
  end
end
