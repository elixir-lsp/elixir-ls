defmodule TestCodeLensCustomPathsAndPattern.MixProject do
  use Mix.Project

  def project do
    [
      app: :test_code_lens_custom_paths_and_pattern,
      version: "0.1.0",
      test_paths: ["custom_path"],
      test_pattern: "*_custom_test.exs"
    ]
  end

  def application, do: []
end
