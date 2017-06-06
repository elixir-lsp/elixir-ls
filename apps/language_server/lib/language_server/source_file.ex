defmodule ElixirLS.LanguageServer.SourceFile do
  defstruct [
    text: nil, 
    path: nil, 
    version: nil, 
    changed_since_compile?: true
  ]

  def lines(%__MODULE__{text: text}) do
    String.split(text, ["\r\n", "\r", "\n"])
  end

  def apply_content_changes(source_file, []) do
    source_file
  end

  # TODO: Support incremental changes
  def apply_content_changes(source_file, [%{"text" => text} | rest]) do
    apply_content_changes(%{source_file | text: text}, rest)
  end
end