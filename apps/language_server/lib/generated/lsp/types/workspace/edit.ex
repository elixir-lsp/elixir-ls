# This file's contents are auto-generated. Do not edit.
defmodule LSP.Types.Workspace.Edit do
  alias ElixirLS.LanguageServer.Experimental.Protocol.Proto
  alias LSP.Types
  use Proto

  deftype change_annotations: optional(map_of(Types.ChangeAnnotation)),
          changes: optional(map_of(list_of(Types.TextEdit))),
          document_changes:
            optional(
              list_of(
                one_of([
                  Types.TextDocument.Edit,
                  Types.CreateFile,
                  Types.RenameFile,
                  Types.DeleteFile
                ])
              )
            )
end
