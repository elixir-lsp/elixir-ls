defmodule ElixirLS.Shell.Quiet do
  @moduledoc false

  @behaviour Mix.Shell

  @impl true
  def print_app() do
    if name = Mix.Shell.printable_app_name() do
      IO.puts(:stderr, "==> #{name}")
    end

    :ok
  end

  @impl true
  def info(message) do
    print_app()
    IO.puts(:stderr, IO.ANSI.format(message))
  end

  @impl true
  def error(message) do
    print_app()
    IO.puts(:stderr, IO.ANSI.format(message))
  end

  @impl true
  def prompt(message) do
    print_app()
    IO.puts(:stderr, IO.ANSI.format(message))
    raise "Mix.Shell.prompt is not supported at this time"
  end

  @impl true
  def yes?(message, options \\ []) do
    default = Keyword.get(options, :default, :yes)

    unless default in [:yes, :no] do
      raise ArgumentError,
            "expected :default to be either :yes or :no, got: #{inspect(default)}"
    end

    IO.puts(:stderr, IO.ANSI.format(message))

    default == :yes
  end

  @impl true
  def cmd(command, opts \\ []) do
    print_app? = Keyword.get(opts, :print_app, true)

    Mix.Shell.cmd(command, opts, fn data ->
      if print_app?, do: print_app()
      IO.write(:stderr, data)
    end)
  end
end

defmodule ElixirLS.Mix do
  @moduledoc false

  @mix_install_project Mix.InstallProject

  # This is a forked version of https://github.com/elixir-lang/elixir/blob/c521bdb91a77b36be16fdf18d632ad7719de4f91/lib/mix/lib/mix.ex#L765
  # with added option to disable stopping apps after install
  # we don't want hex app stopped
  # The original code is licensed under

  # Apache License
  # Version 2.0, January 2004
  # http://www.apache.org/licenses/

  # TERMS AND CONDITIONS FOR USE, REPRODUCTION, AND DISTRIBUTION

  # 1. Definitions.

  # "License" shall mean the terms and conditions for use, reproduction,
  # and distribution as defined by Sections 1 through 9 of this document.

  # "Licensor" shall mean the copyright owner or entity authorized by
  # the copyright owner that is granting the License.

  # "Legal Entity" shall mean the union of the acting entity and all
  # other entities that control, are controlled by, or are under common
  # control with that entity. For the purposes of this definition,
  # "control" means (i) the power, direct or indirect, to cause the
  # direction or management of such entity, whether by contract or
  # otherwise, or (ii) ownership of fifty percent (50%) or more of the
  # outstanding shares, or (iii) beneficial ownership of such entity.

  # "You" (or "Your") shall mean an individual or Legal Entity
  # exercising permissions granted by this License.

  # "Source" form shall mean the preferred form for making modifications,
  # including but not limited to software source code, documentation
  # source, and configuration files.

  # "Object" form shall mean any form resulting from mechanical
  # transformation or translation of a Source form, including but
  # not limited to compiled object code, generated documentation,
  # and conversions to other media types.

  # "Work" shall mean the work of authorship, whether in Source or
  # Object form, made available under the License, as indicated by a
  # copyright notice that is included in or attached to the work
  # (an example is provided in the Appendix below).

  # "Derivative Works" shall mean any work, whether in Source or Object
  # form, that is based on (or derived from) the Work and for which the
  # editorial revisions, annotations, elaborations, or other modifications
  # represent, as a whole, an original work of authorship. For the purposes
  # of this License, Derivative Works shall not include works that remain
  # separable from, or merely link (or bind by name) to the interfaces of,
  # the Work and Derivative Works thereof.

  # "Contribution" shall mean any work of authorship, including
  # the original version of the Work and any modifications or additions
  # to that Work or Derivative Works thereof, that is intentionally
  # submitted to Licensor for inclusion in the Work by the copyright owner
  # or by an individual or Legal Entity authorized to submit on behalf of
  # the copyright owner. For the purposes of this definition, "submitted"
  # means any form of electronic, verbal, or written communication sent
  # to the Licensor or its representatives, including but not limited to
  # communication on electronic mailing lists, source code control systems,
  # and issue tracking systems that are managed by, or on behalf of, the
  # Licensor for the purpose of discussing and improving the Work, but
  # excluding communication that is conspicuously marked or otherwise
  # designated in writing by the copyright owner as "Not a Contribution."

  # "Contributor" shall mean Licensor and any individual or Legal Entity
  # on behalf of whom a Contribution has been received by Licensor and
  # subsequently incorporated within the Work.

  # 2. Grant of Copyright License. Subject to the terms and conditions of
  # this License, each Contributor hereby grants to You a perpetual,
  # worldwide, non-exclusive, no-charge, royalty-free, irrevocable
  # copyright license to reproduce, prepare Derivative Works of,
  # publicly display, publicly perform, sublicense, and distribute the
  # Work and such Derivative Works in Source or Object form.

  # 3. Grant of Patent License. Subject to the terms and conditions of
  # this License, each Contributor hereby grants to You a perpetual,
  # worldwide, non-exclusive, no-charge, royalty-free, irrevocable
  # (except as stated in this section) patent license to make, have made,
  # use, offer to sell, sell, import, and otherwise transfer the Work,
  # where such license applies only to those patent claims licensable
  # by such Contributor that are necessarily infringed by their
  # Contribution(s) alone or by combination of their Contribution(s)
  # with the Work to which such Contribution(s) was submitted. If You
  # institute patent litigation against any entity (including a
  # cross-claim or counterclaim in a lawsuit) alleging that the Work
  # or a Contribution incorporated within the Work constitutes direct
  # or contributory patent infringement, then any patent licenses
  # granted to You under this License for that Work shall terminate
  # as of the date such litigation is filed.

  # 4. Redistribution. You may reproduce and distribute copies of the
  # Work or Derivative Works thereof in any medium, with or without
  # modifications, and in Source or Object form, provided that You
  # meet the following conditions:

  # (a) You must give any other recipients of the Work or
  # Derivative Works a copy of this License; and

  # (b) You must cause any modified files to carry prominent notices
  # stating that You changed the files; and

  # (c) You must retain, in the Source form of any Derivative Works
  # that You distribute, all copyright, patent, trademark, and
  # attribution notices from the Source form of the Work,
  # excluding those notices that do not pertain to any part of
  # the Derivative Works; and

  # (d) If the Work includes a "NOTICE" text file as part of its
  # distribution, then any Derivative Works that You distribute must
  # include a readable copy of the attribution notices contained
  # within such NOTICE file, excluding those notices that do not
  # pertain to any part of the Derivative Works, in at least one
  # of the following places: within a NOTICE text file distributed
  # as part of the Derivative Works; within the Source form or
  # documentation, if provided along with the Derivative Works; or,
  # within a display generated by the Derivative Works, if and
  # wherever such third-party notices normally appear. The contents
  # of the NOTICE file are for informational purposes only and
  # do not modify the License. You may add Your own attribution
  # notices within Derivative Works that You distribute, alongside
  # or as an addendum to the NOTICE text from the Work, provided
  # that such additional attribution notices cannot be construed
  # as modifying the License.

  # You may add Your own copyright statement to Your modifications and
  # may provide additional or different license terms and conditions
  # for use, reproduction, or distribution of Your modifications, or
  # for any such Derivative Works as a whole, provided Your use,
  # reproduction, and distribution of the Work otherwise complies with
  # the conditions stated in this License.

  # 5. Submission of Contributions. Unless You explicitly state otherwise,
  # any Contribution intentionally submitted for inclusion in the Work
  # by You to the Licensor shall be under the terms and conditions of
  # this License, without any additional terms or conditions.
  # Notwithstanding the above, nothing herein shall supersede or modify
  # the terms of any separate license agreement you may have executed
  # with Licensor regarding such Contributions.

  # 6. Trademarks. This License does not grant permission to use the trade
  # names, trademarks, service marks, or product names of the Licensor,
  # except as required for reasonable and customary use in describing the
  # origin of the Work and reproducing the content of the NOTICE file.

  # 7. Disclaimer of Warranty. Unless required by applicable law or
  # agreed to in writing, Licensor provides the Work (and each
  # Contributor provides its Contributions) on an "AS IS" BASIS,
  # WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
  # implied, including, without limitation, any warranties or conditions
  # of TITLE, NON-INFRINGEMENT, MERCHANTABILITY, or FITNESS FOR A
  # PARTICULAR PURPOSE. You are solely responsible for determining the
  # appropriateness of using or redistributing the Work and assume any
  # risks associated with Your exercise of permissions under this License.

  # 8. Limitation of Liability. In no event and under no legal theory,
  # whether in tort (including negligence), contract, or otherwise,
  # unless required by applicable law (such as deliberate and grossly
  # negligent acts) or agreed to in writing, shall any Contributor be
  # liable to You for damages, including any direct, indirect, special,
  # incidental, or consequential damages of any character arising as a
  # result of this License or out of the use or inability to use the
  # Work (including but not limited to damages for loss of goodwill,
  # work stoppage, computer failure or malfunction, or any and all
  # other commercial damages or losses), even if such Contributor
  # has been advised of the possibility of such damages.

  # 9. Accepting Warranty or Additional Liability. While redistributing
  # the Work or Derivative Works thereof, You may choose to offer,
  # and charge a fee for, acceptance of support, warranty, indemnity,
  # or other liability obligations and/or rights consistent with this
  # License. However, in accepting such obligations, You may act only
  # on Your own behalf and on Your sole responsibility, not on behalf
  # of any other Contributor, and only if You agree to indemnify,
  # defend, and hold each Contributor harmless for any liability
  # incurred by, or claims asserted against, such Contributor by reason
  # of your accepting any such warranty or additional liability.

  # END OF TERMS AND CONDITIONS

  def install(deps, opts \\ [])

  def install(deps, opts) when is_list(deps) and is_list(opts) do
    Mix.start()

    if Mix.Project.get() do
      Mix.raise("Mix.install/2 cannot be used inside a Mix project")
    end

    elixir_requirement = opts[:elixir]
    elixir_version = System.version()

    if !!elixir_requirement and not Version.match?(elixir_version, elixir_requirement) do
      Mix.raise(
        "Mix.install/2 declared it supports only Elixir #{elixir_requirement} " <>
          "but you're running on Elixir #{elixir_version}"
      )
    end

    deps =
      Enum.map(deps, fn
        dep when is_atom(dep) ->
          {dep, ">= 0.0.0"}

        {app, opts} when is_atom(app) and is_list(opts) ->
          {app, maybe_expand_path_dep(opts)}

        {app, requirement, opts} when is_atom(app) and is_binary(requirement) and is_list(opts) ->
          {app, requirement, maybe_expand_path_dep(opts)}

        other ->
          other
      end)

    config = Keyword.get(opts, :config, [])
    config_path = expand_path(opts[:config_path], deps, :config_path, "config/config.exs")
    system_env = Keyword.get(opts, :system_env, [])
    consolidate_protocols? = Keyword.get(opts, :consolidate_protocols, true)
    start_applications? = Keyword.get(opts, :start_applications, true)
    # custom elixirLS option
    stop_started_applications? = Keyword.get(opts, :stop_started_applications, true)

    id =
      {deps, config, system_env, consolidate_protocols?}
      |> :erlang.term_to_binary()
      |> :erlang.md5()
      |> Base.encode16(case: :lower)

    force? = System.get_env("MIX_INSTALL_FORCE") in ["1", "true"] or !!opts[:force]

    case Mix.State.get(:installed) do
      nil ->
        Application.put_all_env(config, persistent: true)
        System.put_env(system_env)

        install_dir = install_dir(id)

        if opts[:verbose] do
          Mix.shell().info("Mix.install/2 using #{install_dir}")
        end

        if force? do
          File.rm_rf!(install_dir)
        end

        config = [
          version: "0.1.0",
          build_embedded: false,
          build_per_environment: true,
          build_path: "_build",
          lockfile: "mix.lock",
          deps_path: "deps",
          deps: deps,
          app: :mix_install,
          erlc_paths: [],
          elixirc_paths: [],
          compilers: [],
          consolidate_protocols: consolidate_protocols?,
          config_path: config_path,
          prune_code_paths: false
        ]

        started_apps = Application.started_applications()
        :ok = Mix.ProjectStack.push(@mix_install_project, config, "nofile")
        build_dir = Path.join(install_dir, "_build")
        external_lockfile = expand_path(opts[:lockfile], deps, :lockfile, "mix.lock")

        try do
          first_build? = not File.dir?(build_dir)
          File.mkdir_p!(install_dir)

          File.cd!(install_dir, fn ->
            if config_path do
              Mix.Task.rerun("loadconfig")
            end

            cond do
              external_lockfile ->
                md5_path = Path.join(install_dir, "merge.lock.md5")

                old_md5 =
                  case File.read(md5_path) do
                    {:ok, data} -> Base.decode64!(data)
                    _ -> nil
                  end

                new_md5 = external_lockfile |> File.read!() |> :erlang.md5()

                if old_md5 != new_md5 do
                  lockfile = Path.join(install_dir, "mix.lock")
                  old_lock = Mix.Dep.Lock.read(lockfile)
                  new_lock = Mix.Dep.Lock.read(external_lockfile)
                  Mix.Dep.Lock.write(Map.merge(old_lock, new_lock), file: lockfile)
                  File.write!(md5_path, Base.encode64(new_md5))
                  Mix.Task.rerun("deps.get")
                end

              first_build? ->
                Mix.Task.rerun("deps.get")

              true ->
                # We already have a cache. If the user by any chance uninstalled Hex,
                # we make sure it is installed back (which mix deps.get would do anyway)
                Mix.Hex.ensure_installed?(true)
                :ok
            end

            Mix.Task.rerun("deps.loadpaths")

            # Hex and SSL can use a good amount of memory after the registry fetching,
            # so we stop any app started during deps resolution.
            if stop_started_applications? do
              stop_apps(Application.started_applications() -- started_apps)
            end

            Mix.Task.rerun("compile")

            if config_path do
              Mix.Task.rerun("app.config")
            end
          end)

          if start_applications? do
            for %{app: app, opts: opts} <- Mix.Dep.cached(),
                Keyword.get(opts, :runtime, true) and Keyword.get(opts, :app, true) do
              Application.ensure_all_started(app)
            end
          end

          Mix.State.put(:installed, id)
          :ok
        after
          Mix.ProjectStack.pop()
        end

      ^id when not force? ->
        :ok

      _ ->
        Mix.raise("Mix.install/2 can only be called with the same dependencies in the given VM")
    end
  end

  defp expand_path(_path = nil, _deps, _key, _), do: nil
  defp expand_path(path, _deps, _key, _) when is_binary(path), do: Path.expand(path)

  defp expand_path(app_name, deps, key, relative_path) when is_atom(app_name) do
    app_dir =
      case List.keyfind(deps, app_name, 0) do
        {_, _, opts} when is_list(opts) -> opts[:path]
        {_, opts} when is_list(opts) -> opts[:path]
        _ -> Mix.raise("unknown dependency #{inspect(app_name)} given to #{inspect(key)}")
      end

    unless app_dir do
      Mix.raise("#{inspect(app_name)} given to #{inspect(key)} must be a path dependency")
    end

    Path.join(app_dir, relative_path)
  end

  defp stop_apps([]), do: :ok

  defp stop_apps(apps) do
    :logger.add_primary_filter(:silence_app_exit, {&silence_app_exit/2, []})
    Enum.each(apps, fn {app, _, _} -> Application.stop(app) end)
    :logger.remove_primary_filter(:silence_app_exit)
    :ok
  end

  defp silence_app_exit(
         %{
           msg:
             {:report,
              %{
                label: {:application_controller, :exit},
                report: [application: _, exited: :stopped] ++ _
              }}
         },
         _extra
       ) do
    :stop
  end

  defp silence_app_exit(_message, _extra) do
    :ignore
  end

  defp install_dir(cache_id) do
    install_root =
      System.get_env("MIX_INSTALL_DIR") ||
        Path.join(Mix.Utils.mix_cache(), "installs")

    version = "elixir-#{System.version()}-erts-#{:erlang.system_info(:version)}"
    Path.join([install_root, version, cache_id])
  end

  defp maybe_expand_path_dep(opts) do
    if Keyword.has_key?(opts, :path) do
      Keyword.update!(opts, :path, &Path.expand/1)
    else
      opts
    end
  end
end

defmodule ElixirLS.Installer do
  defp local_dir, do: Path.expand("#{__DIR__}/..")

  defp run_mix_install({:local, dir}, force?) do
    ElixirLS.Mix.install(
      [
        {:elixir_ls, path: dir}
      ],
      force: force?,
      start_applications: false,
      stop_started_applications: false,
      consolidate_protocols: false,
      config_path: Path.join(dir, "config/config.exs"),
      lockfile: Path.join(dir, "mix.lock")
    )
  end

  defp run_mix_install({:tag, tag}, force?) do
    ElixirLS.Mix.install(
      [
        {:elixir_ls, github: "elixir-lsp/elixir-ls", tag: tag}
      ],
      force: force?,
      start_applications: false,
      stop_started_applications: false,
      consolidate_protocols: false
    )
  end

  defp local? do
    System.get_env("ELS_LOCAL") == "1"
  end

  defp get_release do
    version =
      Path.expand("#{__DIR__}/VERSION")
      |> File.read!()
      |> String.trim()

    {:tag, "v#{version}"}
  end

  def install(force?) do
    if local?() do
      dir = local_dir()
      IO.puts(:stderr, "Installing local ElixirLS from #{dir}")
      IO.puts(:stderr, "Running in #{File.cwd!()}")

      run_mix_install({:local, dir}, force?)
    else
      {:tag, tag} = get_release()
      IO.puts(:stderr, "Installing ElixirLS release #{tag}")
      IO.puts(:stderr, "Running in #{File.cwd!()}")

      run_mix_install({:tag, tag}, force?)
    end

    IO.puts(:stderr, "Install complete")
  end

  def install_for_launch do
    if local?() do
      dir = Path.expand("#{__DIR__}/..")
      run_mix_install({:local, dir}, false)
    else
      run_mix_install(get_release(), false)
    end
  end

  def install_with_retry do
    try do
      install(false)
    catch
      kind, error ->
        IO.puts(
          :stderr,
          "Mix.install failed with #{Exception.format(kind, error, __STACKTRACE__)}"
        )

        IO.puts(:stderr, "Retrying Mix.install with force: true")
        install(true)
    end
  end
end
