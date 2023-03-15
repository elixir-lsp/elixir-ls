defmodule ElixirLS.Experimental.ProjectTest do
  alias ElixirLS.LanguageServer.Experimental.Project
  alias ElixirLS.LanguageServer.SourceFile
  alias ElixirLS.LanguageServer.Test.Paths

  use ExUnit.Case, async: false
  use Patch

  def fixture(opts \\ []) do
    signature_help? = Keyword.get(opts, :signature_help?, false)
    dynamic_registration? = Keyword.get(opts, :dynamic_registration?, false)
    hierarchical_symbols? = Keyword.get(opts, :hierarchical_symbols?, false)
    snippet? = Keyword.get(opts, :snippet?, false)
    deprecated? = Keyword.get(opts, :deprecated?, false)
    tag? = Keyword.get(opts, :tag?, false)

    %{
      "textDocument" => %{
        "signatureHelp" => signature_help?,
        "codeAction" => %{"dynamicRegistration" => dynamic_registration?},
        "documentSymbol" => %{"hierarchicalDocumentSymbolSupport" => hierarchical_symbols?},
        "completion" => %{
          "completionItem" => %{
            "snippetSupport" => snippet?,
            "deprecatedSupport" => deprecated?,
            "tagSupport" => tag?
          }
        }
      }
    }
  end

  def root_uri do
    System.tmp_dir!()
    |> Path.join("my_project")
    |> SourceFile.Path.to_uri()
  end

  def with_a_root_uri(_) do
    {:ok, root_uri: root_uri()}
  end

  setup do
    patch(File, :cd, :ok)
    patch(File, :dir?, true)
    patch(Mix, :env, :ok)
    :ok
  end

  describe "new/2" do
    setup [:with_a_root_uri]

    test "should set the root uri" do
      patch(File, :cwd, {:ok, SourceFile.Path.absolute_from_uri(root_uri())})
      project = Project.new(root_uri())
      assert project.root_uri == root_uri()
    end

    test "should handle a nil root uri" do
      project = Project.new(nil)
      assert project.root_uri == nil
    end

    test "should cd to the root uri if it exists" do
      Project.new(root_uri())
      root_path = SourceFile.Path.absolute_from_uri(root_uri())

      assert_called(File.cd(^root_path))
    end

    test "shouldn't cd to the root uri if it doesn't exist" do
      non_existent_uri = "file:///hopefully/doesn_t/exist"
      patch(File, :cd, {:error, :enoent})

      project = Project.new(non_existent_uri)

      assert project.root_uri == nil
    end
  end

  def with_a_valid_root_uri(_) do
    {:ok, project: Project.new(root_uri())}
  end

  describe "changing mix.env" do
    setup [:with_a_valid_root_uri]

    test "overwrites an unset env ", ctx do
      assert {:ok, %Project{} = project} = Project.change_mix_env(ctx.project, "dev")

      assert project.mix_env == :dev
      assert_called(Mix.env(:dev))
    end

    test "defaults to test", ctx do
      assert {:ok, %Project{} = project} = Project.change_mix_env(ctx.project, "")

      assert project.mix_env == :test
      assert_called(Mix.env(:test))
    end

    test "defaults to test with an empty param", ctx do
      assert {:ok, %Project{} = project} = Project.change_mix_env(ctx.project, nil)
      assert project.mix_env == :test
      assert_called(Mix.env(:test))
    end

    test "with the same mix env has no effect ", ctx do
      project = %{ctx.project | mix_env: :dev}

      assert {:ok, %Project{} = project} = Project.change_mix_env(project, "dev")
      assert project.mix_env == :dev
      refute_called(Mix.env(_))
    end

    test "overriding with nil has no effect", ctx do
      project = %{ctx.project | mix_env: :dev}

      assert {:ok, %Project{} = project} = Project.change_mix_env(project, nil)
      assert project.mix_env == :dev
      refute_called(Mix.env(_))
    end

    test "overriding with an emppty string has no effect", ctx do
      project = %{ctx.project | mix_env: :dev}

      assert {:ok, %Project{} = project} = Project.change_mix_env(project, "")
      assert project.mix_env == :dev
      refute_called(Mix.env(_))
    end

    test "to a new env requires a restar", ctx do
      project = %{ctx.project | mix_env: :prod}

      assert {:restart, :warning, message} = Project.change_mix_env(project, "dev")
      assert message =~ "Mix env change detected."
      refute_called(Mix.env(_))
    end
  end

  def with_patched_system_put_env(_) do
    patch(System, :put_env, :ok)
    on_exit(fn -> restore(System) end)
    :ok
  end

  describe "setting env vars" do
    setup [:with_a_valid_root_uri, :with_patched_system_put_env]

    test "sets env vars if it wasn't set", ctx do
      vars = %{"first_var" => "first_value", "second_var" => "second_value"}
      assert {:ok, %Project{} = project} = Project.change_environment_variables(ctx.project, vars)

      expected_env_vars = %{
        "first_var" => "first_value",
        "second_var" => "second_value"
      }

      assert project.env_variables == expected_env_vars
      assert_called(System.put_env(^expected_env_vars))
    end

    test "keeps existing env vars if they're the same as the old ones", ctx do
      vars = %{"first_var" => "first_value", "second_var" => "second_value"}
      project = %Project{ctx.project | env_variables: vars}

      expected_env_vars = %{
        "first_var" => "first_value",
        "second_var" => "second_value"
      }

      assert {:ok, %Project{} = project} = Project.change_environment_variables(project, vars)
      assert project.env_variables == expected_env_vars
      refute_called(System.put_env(_))
    end

    test "rejects env variables that aren't a compatible format", ctx do
      vars = ["a", "b", "c"]

      assert {:ok, %Project{} = project} = Project.change_environment_variables(ctx.project, vars)
      assert project.env_variables == nil
      refute_called(System.put_env(_))
    end

    test "requires a restart if the variables have been set and are being overridden", ctx do
      project = %{ctx.project | env_variables: %{}}
      vars = %{"foo" => "6"}

      assert {:restart, :warning, message} = Project.change_environment_variables(project, vars)
      assert message =~ "Environment variables have changed"
      refute_called(System.put_env(_))
    end
  end

  def with_patched_mix_target(_) do
    patch(Mix, :target, :ok)
    :ok
  end

  describe "setting the mix target" do
    setup [:with_a_valid_root_uri, :with_patched_mix_target]

    test "allows you to set the mix target if it was unset", ctx do
      assert {:ok, %Project{} = project} = Project.change_mix_target(ctx.project, "local")
      assert project.mix_target == :local
      assert_called(Mix.target(:local))
    end

    test "rejects nil for the new target", ctx do
      assert {:ok, %Project{} = project} = Project.change_mix_target(ctx.project, nil)
      assert project.mix_target == nil
      refute_called(Mix.target(:local))
    end

    test "rejects empty string for the new target", ctx do
      assert {:ok, %Project{} = project} = Project.change_mix_target(ctx.project, "")
      assert project.mix_target == nil
      refute_called(Mix.target(:local))
    end

    test "does nothing if the mix target is the same as the old target", ctx do
      project = %Project{ctx.project | mix_target: :local}

      assert {:ok, %Project{} = project} = Project.change_mix_target(project, "local")
      assert project.mix_target == :local
      refute_called(Mix.target(:local))
    end

    test "requires a restart if it was changed after being previously set", ctx do
      project = %Project{ctx.project | mix_target: :local}

      assert {:restart, :warning, message} = Project.change_mix_target(project, "docs")
      assert message =~ "Mix target change detected."
      refute_called(Mix.target(_))
    end
  end

  describe("setting the project dir") do
    setup [:with_a_valid_root_uri]

    test "becomes part of the project if the state is empty", ctx do
      patch(File, :exists?, fn path, _ ->
        String.ends_with?(path, "mix.exs")
      end)

      sub_dir = Path.join(~w(sub_dir new dir))
      assert {:ok, %Project{} = project} = Project.change_project_directory(ctx.project, sub_dir)

      assert Project.project_path(project) ==
               [File.cwd!(), "sub_dir", "new", "dir"]
               |> Path.join()
               |> Paths.maybe_fix_separators()

      assert project.mix_project?
    end

    test "only sets the project directory if the root uri is set" do
      project = Project.new(nil)
      sub_dir = Path.join(~w(sub_dir new dir))

      assert {:ok, project} = Project.change_project_directory(project, sub_dir)
      assert project.root_uri == nil
      assert Project.project_path(project) == nil
    end

    test "defaults to the root uri's directory", ctx do
      assert {:ok, project} = Project.change_project_directory(ctx.project, nil)
      root_path = SourceFile.Path.absolute_from_uri(project.root_uri)
      assert Project.project_path(project) == Paths.maybe_fix_separators(root_path)
    end

    test "defaults to the root uri's directory if the project directory is empty", ctx do
      assert {:ok, project} = Project.change_project_directory(ctx.project, "")
      root_path = SourceFile.Path.absolute_from_uri(project.root_uri)
      assert Project.project_path(project) == Paths.maybe_fix_separators(root_path)
    end

    test "normalizes the project directory", ctx do
      subdirectory = Path.join(~w(sub_dir .. sub_dir new .. new dir))

      patch(File, :exists?, fn path, _ ->
        String.ends_with?(path, "mix.exs")
      end)

      assert {:ok, %Project{} = project} =
               Project.change_project_directory(ctx.project, subdirectory)

      assert sub_dir = Path.join([File.cwd!(), "sub_dir", "new", "dir"])
      assert Project.project_path(project) == Paths.maybe_fix_separators(sub_dir)
      assert project.mix_project?

      assert Project.mix_exs_path(project) ==
               sub_dir
               |> Path.join("mix.exs")
               |> Paths.maybe_fix_separators()
    end

    test "sets mix project to false if the mix.exs doesn't exist", ctx do
      patch(File, :exists?, fn file_name ->
        !String.ends_with?(file_name, "mix.exs")
      end)

      sub_dir = Path.join(~w(sub_dir new dir))
      assert {:ok, %Project{} = project} = Project.change_project_directory(ctx.project, sub_dir)

      assert Project.project_path(project) ==
               File.cwd!()
               |> Path.join(sub_dir)
               |> Paths.maybe_fix_separators()

      refute project.mix_project?
    end

    test "asks for a restart if the project directory was set and the new one isn't the same",
         ctx do
      foo_sub_dir = Path.join(~w(sub_dir foo))
      {:ok, project} = Project.change_project_directory(ctx.project, foo_sub_dir)

      new_dir_sub_dir = Path.join(~w(sub_dir new dir))

      assert {:restart, :warning, message} =
               Project.change_project_directory(project, new_dir_sub_dir)

      assert message =~ "Project directory change detected"
    end

    test "shows an error if the project directory doesn't exist", ctx do
      {:ok, project} = Project.change_project_directory(ctx.project, "sub_dir/foo")

      patch(File, :dir?, false)

      new_directory = Path.join(~w(sub_dir new dir))
      expected_message_directory = Path.join(File.cwd!(), new_directory)

      assert {:error, message} = Project.change_project_directory(project, new_directory)
      assert message =~ "Project directory #{expected_message_directory} does not exist"
    end

    test "rejects a change if the project directory isn't a subdirectory of the project root",
         ctx do
      not_in_project = Path.join(~w(.. .. .. .. not-a-subdir))

      assert {:error, message} = Project.change_project_directory(ctx.project, not_in_project)

      assert message =~ "is not a subdirectory of"
    end
  end
end
