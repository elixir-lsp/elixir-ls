defmodule ElixirLS.LanguageServer.Build do
  alias ElixirLS.LanguageServer.{Server, JsonRpc, SourceFile}
  require Logger

  def build(parent, root_path) do
    if File.cwd!() != root_path do
      IO.puts("Skipping build because cwd changed")
      {nil, nil}
    else
      Process.spawn(fn ->
        {us, _} = :timer.tc fn ->
          case reload_project() do
            {:ok, mixfile_diagnostics} ->
              {status, diagnostics} = compile()
              Server.build_finished(parent, {status, mixfile_diagnostics ++ diagnostics})
            {:error, mixfile_diagnostics} ->
              Server.build_finished(parent, {:error, mixfile_diagnostics})
          end
        end
        Logger.info("Compile took #{div(us, 1000)} milliseconds")
      end, [:monitor])
    end
  end

  def publish_file_diagnostics(uri, all_diagnostics, source_file) do
    diagnostics = Enum.filter(
      all_diagnostics,
      &(SourceFile.path_to_uri(&1.file) == uri)
    ) |> Enum.sort_by(fn %{position: position} -> position end)

    diagnostics_json = for diagnostic <- diagnostics do
      severity = case diagnostic.severity do
        :error -> 1
        :warning -> 2
        :information -> 3
        :hint -> 4
      end

      %{"message" => diagnostic.message,
        "severity" => severity,
        "range" => range(diagnostic.position, source_file),
        "source" => diagnostic.compiler_name}
    end

    JsonRpc.notify("textDocument/publishDiagnostics", %{
      "uri" => uri,
      "diagnostics" => diagnostics_json
    })
  end

  def mixfile_diagnostic({file, line, message}, severity) do
    %Mix.Task.Compiler.Diagnostic{
      compiler_name: "ElixirLS",
      file: file,
      position: line,
      message: message,
      severity: severity
    }
  end

  def exception_to_diagnostic(error) do
    msg =
      case error do
        {:shutdown, 1} ->
          msg = "Build failed for unknown reason. See output log."
          if Version.match?(System.version(), ">= 1.6.0-dev") do
            msg
          else
            msg <> " Upgrade to Elixir 1.6 to see build errors and warnings."
          end
        _ ->
          Exception.format_exit(error)
      end

    %Mix.Task.Compiler.Diagnostic{
      compiler_name: "ElixirLS",
      file: Path.absname(System.get_env("MIX_EXS") || "mix.exs"),
      position: nil,
      message: msg,
      severity: :error,
      details: error
    }
  end

  defp reload_project do
    mixfile = Path.absname(System.get_env("MIX_EXS") || "mix.exs")
    if File.exists?(mixfile) do

      case Mix.ProjectStack.peek() do
        %{file: ^mixfile, name: module} ->
          Mix.Project.pop()
          :code.purge(module)
          :code.delete(module)
        _ ->
          :ok
      end

      Mix.Task.run("loadconfig")

      # If using Elixir 1.6 or higher, we can get diagnostics if Mixfile fails to load
      result =
        if Version.match?(System.version(), ">= 1.6.0-dev") do
          case Kernel.ParallelCompiler.compile([mixfile]) do
            {:ok, _, warnings} ->
              {:ok, Enum.map(warnings, &mixfile_diagnostic(&1, :warning))}
            {:error, errors, warnings} ->
              {:error, Enum.map(warnings, &mixfile_diagnostic(&1, :warning)) ++
                Enum.map(errors, &mixfile_diagnostic(&1, :error))}
          end
        else
          Code.load_file(mixfile)
          {:ok, []}
        end
      result
    else
      {:error, [mixfile_diagnostic({Path.absname(mixfile), nil, "No mixfile found in project root"}, :error)]}
    end
  end

  defp compile do
    Mix.TasksServer.clear()
    case Mix.Task.run("compile", ["--return-errors", "--ignore-module-conflict"]) do
      {status, diagnostics} when status in [:ok, :error, :noop] and is_list(diagnostics) ->
        {status, diagnostics}
      status when status in [:ok, :noop] ->
        {status, []}
      _ ->
        {:ok, []}
    end
  end

  defp range(position, nil) when is_integer(position) do
    line = position - 1
    %{"start" => %{"line" => line, "character" => 0},
      "end" => %{"line" => line, "character" => 0}}
  end

  defp range(position, source_file) when is_integer(position) do
    line = position - 1
    text = Enum.at(SourceFile.lines(source_file), line) || ""
    start_idx = String.length(text) - String.length(String.trim_leading(text))
    length = Enum.max([String.length(String.trim(text)), 1])
    %{"start" => %{"line" => line, "character" => start_idx},
        "end" => %{"line" => line, "character" => start_idx + length}}
  end

  defp range({start_line, start_col, end_line, end_col}, _) do
    %{"start" => %{"line" => start_line - 1, "character" => start_col},
        "end" => %{"line" => end_line - 1, "character" => end_col}}
  end

  defp range(nil, nil) do
    %{"start" => %{"line" => 0, "character" => 0},
        "end" => %{"line" => 0, "character" => 0}}
  end

  defp range(nil, source_file) do
    SourceFile.full_range(source_file)
  end
end
