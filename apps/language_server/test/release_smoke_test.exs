defmodule ElixirLS.LanguageServer.ReleaseSmokeTest do
  @moduledoc """
  Release-gate smoke tests.

  These tests are excluded from the normal CI/test suite via:

      @moduletag :release_smoke

  They are intended to run against a CLEAN checkout with production deps (no
  `path:` overrides) before cutting a release.  Today most of them are excluded
  because the workspace intentionally uses a local `path:` dep for
  `elixir_sense` during development.

  ## Running at release time

      MIX_ENV=test mix test --only release_smoke

  ## Tests in this module

  1. `no_absolute_path_deps` — asserts that no `mix.exs` file in the umbrella
     tree contains `path: "/"` (an absolute-path dep).  Today this test
     DOCUMENTS A KNOWN RELEASE BLOCKER: the `elixir_sense` dep in
     `apps/language_server/mix.exs` uses an absolute `path:` pointing to a
     local worktree.  The always-running companion test
     (`path_dep_is_still_present`) asserts that the path dep IS present so the
     suite notices when it is removed.

  2. `packaged_dep_compile_check` — placeholder for a manual smoke step
     (clean checkout, `mix deps.get`, hint round-trip).

  NOTE: Do NOT add these tests to the default CI run.  They require a prepared
  release environment and will fail on ordinary development checkouts.
  """

  use ExUnit.Case, async: false

  # Tag the whole module so `ExUnit.start(exclude: [release_smoke: true])` in
  # test_helper.exs skips every test here by default.
  @moduletag :release_smoke

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  # The pattern used to detect absolute-path deps in mix.exs files.
  # Matches `path: "/...` (a string value starting with `/`).
  @abs_path_dep_pattern ~s[path: "/]

  # Return the absolute paths to all mix.exs files in the umbrella.
  defp umbrella_mix_files do
    # Walk up from __DIR__ (apps/language_server/test) to find the umbrella root.
    umbrella_root =
      __DIR__
      |> Path.join("../../..")
      |> Path.expand()

    [
      Path.join(umbrella_root, "mix.exs"),
      Path.join(umbrella_root, "apps/language_server/mix.exs"),
      Path.join(umbrella_root, "apps/debug_adapter/mix.exs"),
      Path.join(umbrella_root, "apps/elixir_ls_utils/mix.exs")
    ]
    |> Enum.filter(&File.exists?/1)
  end

  defp read_mix_files do
    for path <- umbrella_mix_files(), into: %{} do
      {path, File.read!(path)}
    end
  end

  # ---------------------------------------------------------------------------
  # Always-running companion test
  #
  # Override the module-level :release_smoke tag with `release_smoke: false` so
  # this specific test runs in normal CI. It asserts the CURRENT state: the
  # elixir_sense dependency is a GIT PIN (no absolute path dep) — flipped on
  # 2026-06-12 when the branch was repointed to the published
  # elixir-lsp/elixir_sense commit. If someone reintroduces a local absolute
  # path dep (e.g. for development), this fails, reminding them not to ship it.
  # ---------------------------------------------------------------------------

  @tag release_smoke: false
  test "companion: elixir_sense is a git pin (no absolute path dep) in language_server/mix.exs" do
    ls_mix = Path.join([__DIR__, "../mix.exs"]) |> Path.expand()
    content = File.read!(ls_mix)

    refute String.contains?(content, @abs_path_dep_pattern),
           """
           apps/language_server/mix.exs contains an absolute path dependency.
           Local path deps are fine for development but must not ship — repoint
           to the published elixir_sense ref (dep_versions.exs) before pushing.
           """

    assert content =~ ~r/\{:elixir_sense,\s+github:/,
           "expected elixir_sense to be declared as a github dependency"
  end

  # ---------------------------------------------------------------------------
  # Release smoke test 1: no absolute-path deps
  # ---------------------------------------------------------------------------

  @doc """
  Asserts that no mix.exs in the umbrella contains `path: "/"` (an absolute
  path pointing outside the repo).

  ## Known blocker (as of 2026-06-12)

  `apps/language_server/mix.exs` contains:

      {:elixir_sense, path: "/Users/lukaszsamson/elixir_sense/.claude/worktrees/..."}

  This is a local development override.  Before cutting a release, replace it
  with the published Hex package reference (or a GitHub ref) and verify that
  `mix deps.get` resolves cleanly from a clean checkout.
  """
  test "no_absolute_path_deps: no mix.exs uses an absolute path dep" do
    # NOTE: This test is excluded by default (@moduletag :release_smoke).
    # Run with: MIX_ENV=test mix test --only release_smoke
    files = read_mix_files()

    offenders =
      for {path, content} <- files,
          String.contains?(content, @abs_path_dep_pattern),
          do: path

    assert offenders == [],
           """
           The following mix.exs files contain absolute-path deps (`path: "/..."`).
           These must be replaced with published Hex or GitHub refs before releasing:

           #{Enum.map_join(offenders, "\n", &"  #{&1}")}

           See the DEVELOPMENT.md release checklist for how to swap the path dep for
           the published elixir_sense package.
           """
  end

  # ---------------------------------------------------------------------------
  # Release smoke test 2: packaged-dep compile + hint round-trip (placeholder)
  # ---------------------------------------------------------------------------

  @doc """
  Placeholder for the packaged-dep compile-and-hint smoke test.

  This test is intentionally skipped via `@tag :skip`.  It documents the
  MANUAL STEPS that a release engineer must perform after switching from the
  local `path:` dep to the published Hex package.

  ## Manual steps

  1. On a clean branch (no path-dep overrides), run:

         git clone <repo> /tmp/elixir_ls_release_check
         cd /tmp/elixir_ls_release_check
         mix deps.get

  2. Verify all deps resolve from Hex (no warnings about missing local paths):

         mix deps

  3. Build in test mode:

         MIX_ENV=test mix compile

  4. Run the full inlay hints integration suite:

         MIX_ENV=test mix test apps/language_server/test/providers/inlay_hints_integration_test.exs \\
           apps/language_server/test/providers/inlay_hints_test.exs

  5. Confirm at least one type hint label matches an expected stdlib form, e.g.:

         Map.get/2 call → label contains "nil or integer()" or similar

  6. If all pass, tag the release.

  ## Automating this placeholder

  Replace the `@tag :skip` below with the actual test body once a CI release
  environment (clean checkout, Hex-only deps, single mix run) is available.
  """
  @tag :skip
  test "packaged_dep_compile_check: clean checkout with Hex deps, hint round-trip" do
    # Placeholder — see @doc above for manual steps.
    # The actual assertion would call:
    #   InlayHints.inlay_hints(ctx, range, settings: %{})
    # and check that at least one stdlib hint (e.g. Map.get/2 → "nil or integer()")
    # is produced from the Hex-published elixir_sense package.
    flunk("This test is a placeholder; implement after switching to published Hex deps.")
  end
end
