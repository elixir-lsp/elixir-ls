defmodule ElixirLS.LanguageServer.Build do
  alias ElixirLS.LanguageServer.{Server, JsonRpc, SourceFile}
  require Logger

  def build(parent, root_path, fetch_deps?) do
    if Path.absname(File.cwd!()) != Path.absname(root_path) do
      IO.puts("Skipping build because cwd changed from #{root_path} to #{File.cwd!()}")
      {nil, nil}
    else
      spawn_monitor(fn ->
        with_build_lock(fn ->
          {us, _} =
            :timer.tc(fn ->
              IO.puts("Compiling with Mix env #{Mix.env()}")

              case reload_project() do
                {:ok, mixfile_diagnostics} ->
                  if fetch_deps?, do: fetch_deps()
                  {status, diagnostics} = compile()
                  Server.build_finished(parent, {status, mixfile_diagnostics ++ diagnostics})

                {:error, mixfile_diagnostics} ->
                  Server.build_finished(parent, {:error, mixfile_diagnostics})
              end
            end)

          JsonRpc.log_message(:info, "Compile took #{div(us, 1000)} milliseconds")
        end)
      end)
    end
  end

  def publish_file_diagnostics(uri, all_diagnostics, source_file) do
    diagnostics =
      all_diagnostics
      |> Enum.filter(&(SourceFile.path_to_uri(&1.file) == uri))
      |> Enum.sort_by(fn %{position: position} -> position end)

    diagnostics_json =
      for diagnostic <- diagnostics do
        severity =
          case diagnostic.severity do
            :error -> 1
            :warning -> 2
            :information -> 3
            :hint -> 4
          end

        %{
          "message" => diagnostic.message,
          "severity" => severity,
          "range" => range(diagnostic.position, source_file),
          "source" => diagnostic.compiler_name
        }
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

  def with_build_lock(func) do
    :global.trans({__MODULE__, self()}, func)
  end

  defp reload_project do
    clear_deps_cache()

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

      Mix.Task.clear()

      # Override build directory to avoid interfering with other dev tools
      Mix.ProjectStack.post_config(build_path: ".elixir_ls/build")

      # If using Elixir 1.6 or higher, we can get diagnostics if Mixfile fails to load
      {status, diagnostics} =
        if Version.match?(System.version(), ">= 1.6.0-dev") do
          case Kernel.ParallelCompiler.compile([mixfile]) do
            {:ok, _, warnings} ->
              {:ok, Enum.map(warnings, &mixfile_diagnostic(&1, :warning))}

            {:error, errors, warnings} ->
              {
                :error,
                Enum.map(warnings, &mixfile_diagnostic(&1, :warning)) ++
                  Enum.map(errors, &mixfile_diagnostic(&1, :error))
              }
          end
        else
          Code.load_file(mixfile)
          {:ok, []}
        end

      if status == :ok do
        # The project may override our logger config, so we reset it after loading their config
        logger_config = Application.get_all_env(:logger)
        Mix.Task.run("loadconfig")
        Mix.Config.persist(logger: logger_config)
      end

      {status, diagnostics}
    else
      msg =
        "No mixfile found in project. " <>
          "To use a subdirectory, set `elixirLS.projectDir` in your settings"

      {:error, [mixfile_diagnostic({Path.absname(mixfile), nil, msg}, :error)]}
    end
  end

  defp compile do
    case Mix.Task.run("compile", ["--return-errors", "--ignore-module-conflict"]) do
      {status, diagnostics} when status in [:ok, :error, :noop] and is_list(diagnostics) ->
        {status, diagnostics}

      status when status in [:ok, :noop] ->
        {status, []}

      _ ->
        {:ok, []}
    end
  end

  defp clear_deps_cache do
    Mix.ProjectStack.write_cache({:cached_deps, Mix.env(), Mix.Project.get()}, nil)
  end

  defp fetch_deps do
    missing_deps =
      Mix.Dep.loaded([])
      |> Enum.filter(fn %Mix.Dep{status: status} ->
        case status do
          {:unavailable, _} -> true
          {:nomatchvsn, _} -> true
          _ -> false
        end
      end)
      |> Enum.map(fn %Mix.Dep{app: app, requirement: requirement} -> "#{app} #{requirement}" end)

    if missing_deps != [] do
      JsonRpc.show_message(
        :info,
        "Fetching #{Enum.count(missing_deps)} deps: #{Enum.join(missing_deps, ", ")}"
      )

      Mix.Task.run("deps.get")
    end

    :ok
  end

  defp range(position, nil) when is_integer(position) do
    line = position - 1

    %{
      "start" => %{"line" => line, "character" => 0},
      "end" => %{"line" => line, "character" => 0}
    }
  end

  defp range(position, source_file) when is_integer(position) do
    line = position - 1
    text = Enum.at(SourceFile.lines(source_file), line) || ""
    start_idx = String.length(text) - String.length(String.trim_leading(text))
    length = Enum.max([String.length(String.trim(text)), 1])

    %{
      "start" => %{"line" => line, "character" => start_idx},
      "end" => %{"line" => line, "character" => start_idx + length}
    }
  end

  defp range({start_line, start_col, end_line, end_col}, _) do
    %{
      "start" => %{"line" => start_line - 1, "character" => start_col},
      "end" => %{"line" => end_line - 1, "character" => end_col}
    }
  end

  defp range(nil, nil) do
    %{"start" => %{"line" => 0, "character" => 0}, "end" => %{"line" => 0, "character" => 0}}
  end

  defp range(nil, source_file) do
    SourceFile.full_range(source_file)
  end
end
