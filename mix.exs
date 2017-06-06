defmodule ElixirLs.Mixfile do
  use Mix.Project

  def project do
    [apps_path: "apps",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     build_per_environment: false,
     deps: deps(),
     dialyzer: [paths: dialyzer_paths(), plt_add_apps: [:ex_unit, :mix, :debugger, :wx]]]
  end

  def dialyzer_paths do
    ["_build/dev/lib/language_server/ebin",
     "_build/dev/lib/debugger/ebin",
     "_build/dev/lib/elixir_sense/ebin",
     "_build/dev/lib/io_handler/ebin",
     Path.dirname(to_string(:code.which(:int)))]
  end

  # Dependencies can be Hex packages:
  #
  #   {:my_dep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:my_dep, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
  #
  # Type "mix help deps" for more examples and options.
  #
  # Dependencies listed here are available only for this project
  # and cannot be accessed from applications inside the apps folder
  defp deps do
    []
  end
end
