defmodule ElixirLS.Debugger.UtilsTest do
  # Awkwardly, testing that the debugger can debug ExUnit tests in the fixture project
  # gives us no way to capture the output, since ExUnit doesn't really distinguish
  # between the debugger's tests and the fixture project's tests. Expect to see output printed
  # from both.

  use ElixirLS.Utils.MixTest.Case, async: true
  alias ElixirLS.Debugger.Utils

  describe "parse_mfa" do
    test "elixir" do
      assert {:ok, {Some.Module, :fun, 2}} == Utils.parse_mfa("Some.Module.fun/2")
      assert {:ok, {Some.Module, :fun, 2}} == Utils.parse_mfa("Elixir.Some.Module.fun/2")
      assert {:ok, {Some.Module, :fun, 2}} == Utils.parse_mfa(":'Elixir.Some.Module'.fun/2")
      assert {:ok, {Elixir, :fun, 2}} == Utils.parse_mfa("Elixir.fun/2")
      assert {:ok, {Elixir.Elixir, :fun, 2}} == Utils.parse_mfa("Elixir.Elixir.fun/2")
    end

    test "erlang" do
      assert {:ok, {:some_module, :fun, 2}} == Utils.parse_mfa(":some_module.fun/2")
      assert {:ok, {:"Some.Module", :fun, 2}} == Utils.parse_mfa(":'Some.Module'.fun/2")
    end

    test "invalid" do
      assert {:error, "cannot parse MFA"} == Utils.parse_mfa("Some..Module.fun/2")
      assert {:error, "cannot parse MFA"} == Utils.parse_mfa("Some.Module.fun/-2")
      assert {:error, "cannot parse MFA"} == Utils.parse_mfa(".fun/2")
      assert {:error, "cannot parse MFA"} == Utils.parse_mfa("fun/2")
      assert {:error, "cannot parse MFA"} == Utils.parse_mfa("some_module.fun/2")
      assert {:error, "cannot parse MFA"} == Utils.parse_mfa(":some_module.fun/")
      assert {:error, "cannot parse MFA"} == Utils.parse_mfa(":some_module.fun")
      assert {:error, "cannot parse MFA"} == Utils.parse_mfa(":some_module.")
      assert {:error, "cannot parse MFA"} == Utils.parse_mfa(":some_module")
      assert {:error, "cannot parse MFA"} == Utils.parse_mfa("some_module")
      assert {:error, "cannot parse MFA"} == Utils.parse_mfa(":")
      assert {:error, "cannot parse MFA"} == Utils.parse_mfa("/")
      assert {:error, "cannot parse MFA"} == Utils.parse_mfa("/2")
      assert {:error, "cannot parse MFA"} == Utils.parse_mfa("")
    end
  end
end
