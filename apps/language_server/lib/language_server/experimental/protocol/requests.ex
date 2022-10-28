defmodule ElixirLS.LanguageServer.Experimental.Protocol.Requests do
  alias ElixirLS.LanguageServer.Experimental.Protocol.LspTypes
  alias ElixirLS.LanguageServer.Experimental.Protocol.Proto
  alias ElixirLS.LanguageServer.Experimental.Protocol.Types

  defmodule Initialize do
    use Proto

    defrequest "initialize", :shared,
      process_id: optional(integer()),
      client_info: optional(LspTypes.ClientInfo),
      locale: optional(string()),
      root_path: optional(string()),
      root_uri: string(),
      initialization_options: optional(map_of(any())),
      trace: optional(string()),
      workspace_folders: optional(Types.WorkspaceFolder),
      capabilities: optional(map_of(any()))
  end

  defmodule FindReferences do
    use Proto

    defrequest("textDocument/references", :exclusive,
      text_document: Types.TextDocument.Identifier,
      position: Types.Position
    )
  end

  defmodule Formatting do
    use Proto

    defrequest("textDocument/formatting", :exclusive,
      text_document: Types.TextDocument.Identifier,
      options: Types.FormattingOptions
    )
  end

  defmodule RegisterCapability do
    use Proto

    defrequest("client/registerCapability", :shared,
      registrations: optional(list_of(LspTypes.Registration))
    )
  end

  use Proto, decoders: :requests
end
