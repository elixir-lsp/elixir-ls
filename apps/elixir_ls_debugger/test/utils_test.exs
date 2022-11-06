defmodule ElixirLS.Debugger.UtilsTest do
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

  describe "positions" do
    test "dap_character_to_elixir empty" do
      assert 0 == Utils.dap_character_to_elixir("", 0)
    end

    test "dap_character_to_elixir empty after end" do
      assert 0 == Utils.dap_character_to_elixir("", 1)
    end

    test "dap_character_to_elixir first char" do
      assert 0 == Utils.dap_character_to_elixir("abcde", 0)
    end

    test "dap_character_to_elixir line" do
      assert 1 == Utils.dap_character_to_elixir("abcde", 1)
    end

    test "dap_character_to_elixir before line start" do
      assert 0 == Utils.dap_character_to_elixir("abcde", -1)
    end

    test "dap_character_to_elixir after line end" do
      assert 5 == Utils.dap_character_to_elixir("abcde", 15)
    end

    test "dap_character_to_elixir utf8" do
      assert 1 == Utils.dap_character_to_elixir("🏳️‍🌈abcde", 6)
    end
  end
end
