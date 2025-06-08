defmodule ElixirLS.LanguageServer.Providers.SymbolUtils do
  @symbol_enum %{
    file: GenLSP.Enumerations.SymbolKind.file(),
    module: GenLSP.Enumerations.SymbolKind.module(),
    namespace: GenLSP.Enumerations.SymbolKind.namespace(),
    package: GenLSP.Enumerations.SymbolKind.package(),
    class: GenLSP.Enumerations.SymbolKind.class(),
    method: GenLSP.Enumerations.SymbolKind.method(),
    property: GenLSP.Enumerations.SymbolKind.property(),
    field: GenLSP.Enumerations.SymbolKind.field(),
    constructor: GenLSP.Enumerations.SymbolKind.constructor(),
    enum: GenLSP.Enumerations.SymbolKind.enum(),
    interface: GenLSP.Enumerations.SymbolKind.interface(),
    function: GenLSP.Enumerations.SymbolKind.function(),
    variable: GenLSP.Enumerations.SymbolKind.variable(),
    constant: GenLSP.Enumerations.SymbolKind.constant(),
    string: GenLSP.Enumerations.SymbolKind.string(),
    number: GenLSP.Enumerations.SymbolKind.number(),
    boolean: GenLSP.Enumerations.SymbolKind.boolean(),
    array: GenLSP.Enumerations.SymbolKind.array(),
    object: GenLSP.Enumerations.SymbolKind.object(),
    key: GenLSP.Enumerations.SymbolKind.key(),
    null: GenLSP.Enumerations.SymbolKind.null(),
    enum_member: GenLSP.Enumerations.SymbolKind.enum_member(),
    struct: GenLSP.Enumerations.SymbolKind.struct(),
    event: GenLSP.Enumerations.SymbolKind.event(),
    operator: GenLSP.Enumerations.SymbolKind.operator(),
    type_parameter: GenLSP.Enumerations.SymbolKind.type_parameter()
  }

  for {kind, code} <- @symbol_enum do
    def symbol_kind_to_code(unquote(kind)), do: unquote(code)
  end
end
