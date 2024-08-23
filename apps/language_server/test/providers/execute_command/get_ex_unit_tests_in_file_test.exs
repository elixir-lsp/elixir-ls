defmodule ElixirLS.LanguageServer.Providers.ExecuteCommand.GetExUnitTestsInFileTest do
  alias ElixirLS.LanguageServer.{ExUnitTestTracer, SourceFile}
  alias ElixirLS.LanguageServer.Providers.ExecuteCommand.GetExUnitTestsInFile
  use ElixirLS.Utils.MixTest.Case, async: false

  setup do
    {:ok, _} = start_supervised(ExUnitTestTracer)

    {:ok, %{}}
  end

  @tag fixture: true
  test "return tests" do
    in_fixture(Path.join(__DIR__, "../../../test_fixtures"), "project_with_tests", fn ->
      uri = SourceFile.Path.to_uri(Path.join(File.cwd!(), "test/fixture_test.exs"))

      assert {:ok,
              [
                %{
                  describes: [
                    %{
                      describe: nil,
                      line: nil,
                      tests: [
                        %{
                          line: 19,
                          name: "this will be a test in future",
                          type: :test
                        },
                        %{line: 6, name: "fixture test", type: :test}
                      ]
                    },
                    %{
                      describe: "describe with test",
                      line: 10,
                      tests: [
                        %{line: 11, name: "fixture test", type: :test}
                      ]
                    }
                  ],
                  line: 0,
                  module: "FixtureTest"
                }
              ]} = GetExUnitTestsInFile.execute([uri], nil)
    end)
  end

  @tag fixture: true
  test "return empty when file fails to compile" do
    in_fixture(Path.join(__DIR__, "../../../test_fixtures"), "project_with_tests", fn ->
      uri = SourceFile.Path.to_uri(Path.join(File.cwd!(), "test/error_test.exs"))

      assert {:ok, []} =
               GetExUnitTestsInFile.execute([uri], nil)
    end)
  end
end
