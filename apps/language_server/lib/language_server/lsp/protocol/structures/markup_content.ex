# codegen: do not edit
defmodule GenLSP.Structures.MarkupContent do
  @moduledoc """
  A `MarkupContent` literal represents a string value which content is interpreted base on its
  kind flag. Currently the protocol supports `plaintext` and `markdown` as markup kinds.

  If the kind is `markdown` then the value can contain fenced code blocks like in GitHub issues.
  See https://help.github.com/articles/creating-and-highlighting-code-blocks/#syntax-highlighting

  Here is an example how such a string can be constructed using JavaScript / TypeScript:
  ```ts
  let markdown: MarkdownContent = {
   kind: MarkupKind.Markdown,
   value: [
     '# Header',
     'Some text',
     '```typescript',
     'someCode();',
     '```'
   ].join('\n')
  };
  ```

  *Please Note* that clients might sanitize the return markdown. A client could decide to
  remove HTML from the markdown to avoid script execution.
  """

  import SchematicV, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * kind: The type of the Markup
  * value: The content itself
  """

  typedstruct do
    field(:kind, GenLSP.Enumerations.MarkupKind.t(), enforce: true)
    field(:value, String.t(), enforce: true)
  end

  @doc false
  @spec schematic() :: SchematicV.t()
  def schematic() do
    schema(__MODULE__, %{
      {"kind", :kind} => GenLSP.Enumerations.MarkupKind.schematic(),
      {"value", :value} => str()
    })
  end
end
