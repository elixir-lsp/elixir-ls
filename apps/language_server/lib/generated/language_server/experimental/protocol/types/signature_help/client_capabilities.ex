# This file's contents are auto-generated. Do not edit.
defmodule ElixirLS.LanguageServer.Experimental.Protocol.Types.SignatureHelp.ClientCapabilities do
  alias ElixirLS.LanguageServer.Experimental.Protocol.Proto
  alias ElixirLS.LanguageServer.Experimental.Protocol.Types

  defmodule ParameterInformation do
    use Proto
    deftype label_offset_support: optional(boolean())
  end

  defmodule SignatureInformation do
    use Proto

    deftype active_parameter_support: optional(boolean()),
            documentation_format: optional(list_of(Types.Markup.Kind)),
            parameter_information: optional(ParameterInformation)
  end

  use Proto

  deftype context_support: optional(boolean()),
          dynamic_registration: optional(boolean()),
          signature_information: optional(SignatureInformation)
end
