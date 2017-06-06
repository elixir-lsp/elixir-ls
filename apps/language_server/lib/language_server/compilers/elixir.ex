defmodule ElixirLS.LanguageServer.Compilers.Elixir do
  @moduledoc """
  A forked version of Elixir 1.4's compiler
  
  Changes are annotated with comments. Some major changes are:

  1. Use our custom ParallelCompiler.
  2. Accept parameter "source_files" with SourceFile structs that are open in the IDE with unsaved
     changes. We assume these as stale files and recompile them.
  3. Use the WarningsTracker to track warnings.
  4. Pass an additional callback into the custom parallel compiler to handle compilation errors.
  5. Save warnings and errors to the manifest. Since we've modified the parallel compiler to finish
     compiling even if it encounters an error, the build should complete even if some modules fail.
     We need to keep track of which sources successfully compiled and which failed so we can retry
     the failed ones upon changes. Also, tracking the warnings in the manifest allow us to get all
     warnings after each rebuild (not just new warnings) without recompiling everything.
  6. Return the manifest, since it contains the warning and error information we need.
  """

  @manifest_vsn :elixir_ls_v1
  @manifest ".compile.elixir_ls"

  alias ElixirLS.LanguageServer.BuildError
  import Record

  defrecord :module, [:module, :kind, :source, :beam, :binary]
  defrecord :source, [
    source: nil,
    compile_references: [],
    runtime_references: [],
    compile_dispatches: [],
    runtime_dispatches: [],
    external: [],
    timestamp: nil,
    error: nil,
    warnings: [],
    text: nil
  ]

  @doc """
  Compiles stale Elixir files.

  It expects a `manifest` file, the source directories, the destination
  directory, a flag to know if compilation is being forced or not, and a
  list of any additional compiler options.

  The `manifest` is written down with information including dependencies
  between modules, which helps it recompile only the modules that
  have changed at runtime.
  """
  def compile(manifest, srcs, source_files, dest, force, opts) do
    # We fetch the time from before we read files so any future
    # change to files are still picked up by the compiler. This
    # timestamp is used when writing BEAM files and the manifest.
    timestamp = :calendar.universal_time()

    all = Enum.uniq(Mix.Utils.extract_files(srcs, [:ex]))

    {all_modules, all_sources} = parse_manifest(manifest, dest)
    modified = Mix.Utils.last_modified(manifest)
    
    removed =
      for source(source: source) <- all_sources,
          not(source in all),
          do: source

    changed =
      if force do
        # A config, path dependency or manifest has
        # changed, let's just compile everything
        all
      else
        sources_mtimes = mtimes(all_sources)

        # Otherwise let's start with the new sources
        for(source <- all,
            not List.keymember?(all_sources, source, source(:source)),
            do: source)
          ++
        # Plus the sources that have changed in disk
        # CHANGED: Or had errors on the last compile
        for(source(source: source, external: external, error: error) <- all_sources,
            times = Enum.map([source | external], &Map.fetch!(sources_mtimes, &1)),
            Mix.Utils.stale?(times, [modified]) or error != nil or 
              Enum.find(source_files, &(&1.path == source)),
            do: source)
      end

    {modules, changed} =
      update_stale_entries(
        all_modules,
        all_sources,
        removed ++ changed,
        stale_local_deps(manifest, modified)
      )

    stale   = changed -- removed
    sources = update_stale_sources(all_sources, removed, changed, timestamp)

    # CHANGED: Return all {modules, sources} instead of only {stale, removed}
    cond do
      stale != [] ->
        compile_manifest(source_files, manifest, modules, sources, stale, dest, timestamp, opts)
      removed != [] ->
        write_manifest(manifest, modules, sources, dest, timestamp)
        {modules, sources}
      true ->
        {modules, sources}
    end
  end

  defp mtimes(manifest_sources) do
    Enum.reduce manifest_sources, %{}, fn source(source: source, external: external), map ->
      Enum.reduce [source | external], map, fn file, map ->
        Map.put_new_lazy(map, file, fn -> Mix.Utils.last_modified(file) end)
      end
    end
  end

  @doc """
  Removes compiled files for the given `manifest`.
  """
  def clean(manifest, compile_path) do
    Enum.each(read_manifest(manifest, compile_path), fn
      module(beam: beam) ->
        File.rm(beam)
      _ ->
        :ok
    end)
  end

  @doc """
  Returns protocols and implementations for the given `manifest`.
  """
  def protocols_and_impls(manifest, compile_path) do
    for module(beam: beam, module: module, kind: kind) <- read_manifest(manifest, compile_path),
        match?(:protocol, kind) or match?({:impl, _}, kind),
        do: {module, kind, beam}
  end

  @doc """
  Reads the manifest.
  """
  def read_manifest(manifest, compile_path) do
    try do
      manifest |> File.read!() |> :erlang.binary_to_term()
    else
      [@manifest_vsn | data] ->
        expand_beam_paths(data, compile_path)
      _ ->
        []
    rescue
      _ -> []
    end
  end

  defp compile_manifest(source_files, manifest, modules, sources, stale, dest, timestamp, opts) do
    Mix.Utils.compiling_n(length(stale), :ex)
    Mix.Project.ensure_structure()
    File.mkdir_p(dest)
    true = Code.prepend_path(dest)
    set_compiler_opts(opts)
    cwd = File.cwd!

    extra =
      if opts[:verbose] do
        [each_file: &each_file/1]
      else
        []
      end

    # Starts a server responsible for keeping track which files
    # were compiled and the dependencies between them.
    {:ok, pid} = Agent.start_link(fn -> {modules, sources} end)
    long_compilation_threshold = opts[:long_compilation_threshold] || 10

    # CHANGED: Pass in {path, text} tuples instead of just path strings so we can use the in-memory
    # contents of dirty files and avoid reading them from disk
    stale_files = 
      for path <- stale do
        source_file = Enum.find(source_files, &(&1.path == path))
        case source_file do
          %ElixirLS.LanguageServer.SourceFile{text: text} -> %{path: path, text: text}
          _ -> %{path: path, text: nil}
        end
      end

    # CHANGED: Capture warnings sent to :standard_error
    alias ElixirLS.LanguageServer.WarningsTracker
    WarningsTracker.start_link

    try do
      _ = ElixirLS.LanguageServer.ParallelCompiler.files stale_files,
            [each_module: &each_module(pid, cwd, &1, &2, &3),
             each_long_compilation: &each_long_compilation(&1, long_compilation_threshold),
             each_failed_file: &each_failed_file(pid, &1, &2),
             long_compilation_threshold: long_compilation_threshold,
             dest: dest] ++ extra

      Agent.cast pid, fn {modules, sources} ->
        # CHANGED: Add captured warnings to sources for manifest
        sources = apply_warnings(sources, stale, WarningsTracker.warnings)
        write_manifest(manifest, modules, sources, dest, timestamp)
        {modules, sources}
      end

      # CHANGED: Return manifest
      Agent.get(pid, &(&1))
    after
      # CHANGED: Stop capturing standard error
      WarningsTracker.stop
      Agent.stop(pid, :normal, :infinity)
    end
  end

  # CHANGED: This callback is called when a file fails to compile
  def each_failed_file(pid, source_file, reason) do
    path = source_file.path
    compile_error = BuildError.from_compile_error(reason, source_file.path)

    Agent.update pid, fn {modules, sources} ->
      sources = 
        for source_entry <- sources do
          if source(source_entry, :source) == path do
            source(source_entry, error: compile_error)
          else
            source_entry
          end
        end
      {modules, sources}
    end
  end

  defp set_compiler_opts(opts) do
    opts
    |> Keyword.take(Code.available_compiler_options)
    |> Code.compiler_options()
  end

  # CHANGED: "source" has changed to "source_file" which is a ElixirLS.LanguageServer.SourceFile
  defp each_module(pid, cwd, source_file, module, binary) do
    {compile_references, runtime_references} = Kernel.LexicalTracker.remote_references(module)

    compile_references =
      compile_references
      |> List.delete(module)
      |> Enum.reject(&match?("elixir_" <> _, Atom.to_string(&1)))

    runtime_references =
      runtime_references
      |> List.delete(module)

    {compile_dispatches, runtime_dispatches} = Kernel.LexicalTracker.remote_dispatches(module)

    compile_dispatches =
      compile_dispatches
      |> Enum.reject(&match?("elixir_" <> _, Atom.to_string(elem(&1, 0))))

    runtime_dispatches =
      runtime_dispatches
      |> Enum.to_list

    kind     = detect_kind(module)
    source   = source_file.path
    external = get_external_resources(module, cwd)

    Agent.cast pid, fn {modules, sources} ->
      old_source = List.keyfind(sources, source, source(:source))

      external = case old_source do
        source(external: old_external) -> external ++ old_external
        nil -> external
      end

      new_module = module(
        module: module,
        kind: kind,
        source: source,
        beam: nil, # They are calculated when writing the manifest
        binary: binary
      )

      new_source = source(
        old_source,
        source: source,
        compile_references: compile_references,
        runtime_references: runtime_references,
        compile_dispatches: compile_dispatches,
        runtime_dispatches: runtime_dispatches,
        external: external
      )

      modules = List.keystore(modules, module, module(:module), new_module)
      sources = List.keystore(sources, source, source(:source), new_source)
      {modules, sources}
    end
  end

  defp detect_kind(module) do
    impl = Module.get_attribute(module, :impl)

    cond do
      is_list(impl) and impl[:protocol] ->
        {:impl, impl[:protocol]}
      is_list(Module.get_attribute(module, :protocol)) ->
        :protocol
      true ->
        :module
    end
  end

  defp get_external_resources(module, cwd) do
    for file <- Module.get_attribute(module, :external_resource),
        do: Path.relative_to(file, cwd)
  end

  # CHANGED: arg is now a ElixirLS.LanguageServer.SourceFile struct
  defp each_file(source_file) do
    Mix.shell.info "Compiled #{source_file.path}"
  end

  defp each_long_compilation(source, threshold) do
    Mix.shell.info "Compiling #{source} (it's taking more than #{threshold}s)"
  end

  # NEW: Extract warnings from build log and apply them to sources
  def apply_warnings(sources, stale_paths, warnings) do

    for s <- sources do
      path = source(s, :source)
      if path in stale_paths do
        source_warnings = Enum.filter warnings, fn warning -> warning.file == path end
        source(s, warnings: source_warnings)
      else
        s
      end
    end
  end

  # NEW: Used by custom Xref task
  def manifests do 
    [manifest()]
  end

  def manifest do
    Path.join(Mix.Project.manifest_path, @manifest)
  end

  ## Resolution

  defp update_stale_sources(sources, removed, changed, timestamp) do
    # Remove delete sources
    sources =
      Enum.reduce(removed, sources, &List.keydelete(&2, &1, source(:source)))
    # Store empty sources for the changed ones as the compiler appends data
    Enum.reduce(changed, sources, &List.keystore(&2, &1, source(:source), source(source: &1, timestamp: timestamp)))
  end

  # This function receives the manifest entries and some source
  # files that have changed. It then, recursively, figures out
  # all the files that changed (via the module dependencies) and
  # return the non-changed entries and the removed sources.
  defp update_stale_entries(modules, _sources, [], stale) when stale == %{} do
    {modules, []}
  end

  defp update_stale_entries(modules, sources, changed, stale) do
    removed = Enum.into(changed, %{}, &{&1, true})
    remove_stale_entries(modules, sources, stale, removed)
  end

  defp remove_stale_entries(modules, sources, old_stale, old_removed) do
    {rest, new_stale, new_removed} =
      Enum.reduce modules, {[], old_stale, old_removed}, &remove_stale_entry(&1, &2, sources)

    if map_size(new_stale) > map_size(old_stale) or
       map_size(new_removed) > map_size(old_removed) do
      remove_stale_entries(rest, sources, new_stale, new_removed)
    else
      {rest, Map.keys(new_removed)}
    end
  end

  defp remove_stale_entry(module(module: module, beam: beam, source: source) = entry,
                          {rest, stale, removed}, sources) do
    source(compile_references: compile_references, runtime_references: runtime_references) =
      List.keyfind(sources, source, source(:source))

    cond do
      # If I changed in disk or have a compile time reference to
      # something stale, I need to be recompiled.
      Map.has_key?(removed, source) or Enum.any?(compile_references, &Map.has_key?(stale, &1)) ->
        remove_and_purge(beam, module)
        {rest, Map.put(stale, module, true), Map.put(removed, source, true)}

      # If I have a runtime references to something stale,
      # I am stale too.
      Enum.any?(runtime_references, &Map.has_key?(stale, &1)) ->
        {[entry | rest], Map.put(stale, module, true), removed}

      # Otherwise, we don't store it anywhere
      true ->
        {[entry | rest], stale, removed}
    end
  end

  defp stale_local_deps(manifest, modified) do
    base = Path.basename(manifest)
    for %{scm: scm, opts: opts} = dep <- Mix.Dep.cached(),
        not scm.fetchable?,
        Mix.Utils.last_modified(Path.join(opts[:build], base)) > modified,
        path <- Mix.Dep.load_paths(dep),
        beam <- Path.wildcard(Path.join(path, "*.beam")),
        Mix.Utils.last_modified(beam) > modified,
        do: {beam |> Path.basename |> Path.rootname |> String.to_atom, true},
        into: %{}
  end

  defp remove_and_purge(beam, module) do
    _ = File.rm(beam)
    _ = :code.purge(module)
    _ = :code.delete(module)
  end

  ## Manifest handling

  # Similar to read_manifest, but supports data migration.
  defp parse_manifest(manifest, compile_path) do
    try do
      manifest |> File.read!() |> :erlang.binary_to_term()
    rescue
      _ -> {[], []}
    else
      [@manifest_vsn | data] -> do_parse_manifest(data, compile_path)
      _ -> {[], []}
    end
  end

  defp do_parse_manifest(data, compile_path) do
    Enum.reduce(data, {[], []}, fn
      module() = module, {modules, sources} ->
        {[expand_beam_path(module, compile_path) | modules], sources}
      source() = source, {modules, sources} ->
        {modules, [source | sources]}
    end)
  end

  defp expand_beam_path(module(beam: beam) = module, compile_path) do
    module(module, beam: Path.join(compile_path, beam))
  end

  defp expand_beam_paths(modules, ""), do: modules
  defp expand_beam_paths(modules, compile_path) do
    Enum.map(modules, fn
      module() = module ->
        expand_beam_path(module, compile_path)
      other ->
        other
    end)
  end

  defp write_manifest(manifest, [], [], _compile_path, _timestamp) do
    File.rm(manifest)
    :ok
  end

  defp write_manifest(manifest, modules, sources, compile_path, timestamp) do
    File.mkdir_p!(Path.dirname(manifest))

    modules =
      for module(binary: binary, module: module) = entry <- modules do
        beam = Atom.to_string(module) <> ".beam"
        if binary do
          beam_path = Path.join(compile_path, beam)
          File.write!(beam_path, binary)
          File.touch!(beam_path, timestamp)
        end
        module(entry, binary: nil, beam: beam)
      end

    manifest_data =
      [@manifest_vsn | modules ++ sources]
      |> :erlang.term_to_binary(compressed: 9)

    File.write!(manifest, manifest_data)
    File.touch!(manifest, timestamp)

    # Since Elixir is a dependency itself, we need to touch the lock
    # so the current Elixir version, used to compile the files above,
    # is properly stored.
    Mix.Dep.ElixirSCM.update
  end
end
