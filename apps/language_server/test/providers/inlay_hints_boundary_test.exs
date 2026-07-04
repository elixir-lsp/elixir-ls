defmodule ElixirLS.LanguageServer.Providers.InlayHintsBoundaryTest do
  @moduledoc """
  Architecture boundary check: the inlay-hints provider must consume types
  exclusively through the `ElixirSense.Core.TypeHints` facade — never through
  `ElixirSense.Core.Binding` or `ElixirSense.Core.TypePresentation` directly.
  Those are elixir_sense internals; the facade is the only supported LSP-facing
  type API, so display trust levels, caching, and shape/descr translation stay
  in one place.

  Enforced against compiled BEAM import tables (actual remote-call targets),
  so doc/comment mentions don't count.
  """
  use ExUnit.Case, async: true

  @forbidden_prefixes [
    "Elixir.ElixirSense.Core.Binding",
    "Elixir.ElixirSense.Core.TypePresentation"
  ]

  test "InlayHints provider only uses the TypeHints facade for type access" do
    provider_modules =
      for module <- Application.spec(:language_server, :modules),
          module
          |> Atom.to_string()
          |> String.starts_with?("Elixir.ElixirLS.LanguageServer.Providers.InlayHints"),
          do: module

    assert provider_modules != [], "InlayHints provider modules not found in app spec"

    offenders =
      for module <- provider_modules,
          target <- forbidden_call_targets(module),
          do: {module, target}

    assert offenders == [],
           "Inlay-hints provider bypasses the TypeHints facade:\n" <>
             Enum.map_join(offenders, "\n", fn {m, {tm, tf, ta}} ->
               "  #{inspect(m)} -> #{inspect(tm)}.#{tf}/#{ta}"
             end)
  end

  defp forbidden_call_targets(module) do
    with path when is_list(path) <- :code.which(module),
         {:ok, {^module, [{:imports, imports}]}} <- :beam_lib.chunks(path, [:imports]) do
      Enum.filter(imports, fn {target_mod, _f, _a} ->
        target = Atom.to_string(target_mod)
        Enum.any?(@forbidden_prefixes, &String.starts_with?(target, &1))
      end)
    else
      _ -> []
    end
  end
end
