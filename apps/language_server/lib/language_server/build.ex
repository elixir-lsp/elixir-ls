defmodule ElixirLS.LanguageServer.Build do
  alias ElixirLS.LanguageServer.{Server, JsonRpc, SourceFile, Diagnostics, Project}

  def build(parent, root_path, opts) when is_binary(root_path) do
    if Path.absname(File.cwd!()) != Path.absname(root_path) do
      IO.puts("Skipping build because cwd changed from #{root_path} to #{File.cwd!()}")
      {nil, nil}
    else
      spawn_monitor(fn ->
        with_build_lock(fn ->
          {us, _} =
            :timer.tc(fn ->
              IO.puts("MIX_ENV: #{Mix.env()}")
              IO.puts("MIX_TARGET: #{Mix.target()}")

              case Project.reload() do
                {:ok, mixfile_diagnostics} ->
                  # FIXME: Private API
                  if Keyword.get(opts, :fetch_deps?) and
                       Mix.Dep.load_on_environment([]) != cached_deps() do
                    # NOTE: Clear deps cache when deps in mix.exs has change to prevent
                    # formatter crash from clearing deps during build.
                    :ok = Mix.Project.clear_deps_cache()
                    fetch_deps()
                  end

                  # if we won't do it elixir >= 1.11 warns that protocols have already been consolidated
                  purge_consolidated_protocols()
                  {status, diagnostics} = compile()

                  if status in [:ok, :noop] and Keyword.get(opts, :load_all_modules?) do
                    load_all_modules()
                  end

                  diagnostics = Diagnostics.normalize(diagnostics, root_path)
                  Server.build_finished(parent, {status, mixfile_diagnostics ++ diagnostics})

                {:error, mixfile_diagnostics} ->
                  Server.build_finished(parent, {:error, mixfile_diagnostics})

                :no_mixfile ->
                  Server.build_finished(parent, {:no_mixfile, []})
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

        message =
          case diagnostic.message do
            m when is_binary(m) -> m
            m when is_list(m) -> m |> Enum.join("\n")
          end

        %{
          "message" => message,
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
          "Build failed for unknown reason. See output log."

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

  def load_all_modules do
    apps =
      cond do
        Mix.Project.umbrella?() ->
          Mix.Project.apps_paths() |> Map.keys()

        app = Keyword.get(Mix.Project.config(), :app) ->
          [app]

        true ->
          []
      end

    Enum.each(apps, fn app ->
      true = Code.prepend_path(Path.join(Mix.Project.build_path(), "lib/#{app}/ebin"))

      case Application.load(app) do
        :ok -> :ok
        {:error, {:already_loaded, _}} -> :ok
      end
    end)
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

  defp purge_consolidated_protocols do
    config = Mix.Project.config()
    path = Mix.Project.consolidation_path(config)

    with {:ok, beams} <- File.ls(path) do
      Enum.map(beams, &(&1 |> Path.rootname(".beam") |> String.to_atom() |> purge_module()))
    else
      {:error, :enoent} ->
        # consolidation_path does not exist
        :ok

      {:error, reason} ->
        JsonRpc.log_message(
          :warning,
          "Unable to purge consolidated protocols from #{path}: #{inspect(reason)}"
        )
    end

    # NOTE this implementation is based on https://github.com/phoenixframework/phoenix/commit/b5580e9
    # calling `Code.delete_path(path)` may be unnecessary in our case
    Code.delete_path(path)
  end

  def purge_module(module) do
    :code.purge(module)
    :code.delete(module)
  end

  defp cached_deps do
    try do
      # FIXME: Private API
      Mix.Dep.cached()
    rescue
      _ ->
        []
    end
  end

  defp fetch_deps do
    # FIXME: Private API and struct
    missing_deps =
      Mix.Dep.load_on_environment([])
      |> Enum.filter(fn %Mix.Dep{status: status} ->
        case status do
          {:unavailable, _} -> true
          {:nomatchvsn, _} -> true
          _ -> false
        end
      end)
      # FIXME: Private struct
      |> Enum.map(fn %Mix.Dep{app: app, requirement: requirement} -> "#{app} #{requirement}" end)

    if missing_deps != [] do
      JsonRpc.show_message(
        :info,
        "Fetching #{Enum.count(missing_deps)} deps: #{Enum.join(missing_deps, ", ")}"
      )

      Mix.Task.run("deps.get")

      JsonRpc.show_message(
        :info,
        "Done fetching deps"
      )
    end

    :ok
  end

  defp range(position, nil) when is_integer(position) do
    line = position - 1

    # we don't care about utf16 positions here as we send 0
    %{
      "start" => %{"line" => line, "character" => 0},
      "end" => %{"line" => line, "character" => 0}
    }
  end

  defp range(position, source_file) when is_integer(position) do
    line = position - 1
    text = Enum.at(SourceFile.lines(source_file), line) || ""

    start_idx = String.length(text) - String.length(String.trim_leading(text)) + 1
    length = max(String.length(String.trim(text)), 1)

    %{
      "start" => %{
        "line" => line,
        "character" => SourceFile.elixir_character_to_lsp(text, start_idx)
      },
      "end" => %{
        "line" => line,
        "character" => SourceFile.elixir_character_to_lsp(text, start_idx + length)
      }
    }
  end

  defp range(_, nil) do
    # we don't care about utf16 positions here as we send 0
    %{"start" => %{"line" => 0, "character" => 0}, "end" => %{"line" => 0, "character" => 0}}
  end

  defp range(_, source_file) do
    SourceFile.full_range(source_file)
  end
end
