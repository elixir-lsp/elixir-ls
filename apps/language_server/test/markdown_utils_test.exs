defmodule ElixirLS.LanguageServer.MarkdownUtilsTest do
  use ExUnit.Case

  alias ElixirLS.LanguageServer.MarkdownUtils

  @main_document """
  # Main Title

  ## Sub Title

  ### Section to Embed Fragment

  """

  describe "adjust_headings/3" do
    test "no headings" do
      fragment = """
      Regular text without any heading.
      """

      adjusted_fragment = MarkdownUtils.adjust_headings(fragment, 3)

      main_document = @main_document <> adjusted_fragment

      assert main_document == """
             # Main Title

             ## Sub Title

             ### Section to Embed Fragment

             Regular text without any heading.
             """
    end

    test "headings lower than main document" do
      fragment = """
      # Fragment Title

      ## Fragment Subtitle
      """

      adjusted_fragment = MarkdownUtils.adjust_headings(fragment, 3)

      main_document = @main_document <> adjusted_fragment

      assert main_document == """
             # Main Title

             ## Sub Title

             ### Section to Embed Fragment

             #### Fragment Title

             ##### Fragment Subtitle
             """
    end

    test "headings higher than main document" do
      fragment = """
      ##### Fragment Title

      ###### Fragment Subtitle
      """

      adjusted_fragment = MarkdownUtils.adjust_headings(fragment, 3)

      main_document = @main_document <> adjusted_fragment

      assert main_document == """
             # Main Title

             ## Sub Title

             ### Section to Embed Fragment

             #### Fragment Title

             ##### Fragment Subtitle
             """
    end
  end

  test "join_with_horizontal_rule/1" do
    part_1 = """

    Foo

    """

    part_2 = """
    Bar
    """

    assert MarkdownUtils.join_with_horizontal_rule([part_1, part_2]) == """
           Foo

           ---

           Bar
           """
  end
end
