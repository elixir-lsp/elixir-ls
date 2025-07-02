defmodule ElixirLS.Utils.LaunchTest do
  use ExUnit.Case, async: true

  test "get_versions returns plain strings" do
    versions = ElixirLS.Utils.Launch.get_versions()

    assert is_binary(versions.current_elixir_version)
    assert is_binary(versions.current_otp_version)
    assert is_binary(versions.compile_elixir_version)
    assert is_binary(versions.compile_otp_version)

    for value <- Map.values(versions) do
      refute String.starts_with?(value, "\"")
      refute String.ends_with?(value, "\"")
    end
  end
end
