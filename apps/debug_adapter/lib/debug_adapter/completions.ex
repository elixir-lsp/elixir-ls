defmodule ElixirLS.DebugAdapter.Completions do
  # type CompletionItemType = 'method' | 'function' | 'constructor' | 'field'
  #   | 'variable' | 'class' | 'interface' | 'module' | 'property' | 'unit'
  #   | 'value' | 'enum' | 'keyword' | 'snippet' | 'text' | 'color' | 'file'
  #   | 'reference' | 'customcolor';
  def map(%{
        type: type,
        name: name,
        arity: arity,
        snippet: snippet
      })
      when type in [:function, :macro] do
    %{
      type: "function",
      detail: Atom.to_string(type),
      label: "#{name}/#{arity}",
      text: snippet || name
    }
  end

  def map(%{
        type: :module,
        subtype: subtype,
        name: name
      }) do
    text =
      case name do
        ":" <> rest -> rest
        other -> other
      end

    %{
      type: "module",
      detail: if(subtype != nil, do: Atom.to_string(subtype)),
      label: name,
      text: text
    }
  end

  def map(%{
        type: :variable,
        name: name
      }) do
    %{
      type: "variable",
      label: name
    }
  end

  def map(%{
        type: :field,
        subtype: subtype,
        name: name
      }) do
    detail =
      case subtype do
        :struct_field -> "struct field"
        :map_key -> "map key"
      end

    %{
      type: "field",
      detail: detail,
      label: name
    }
  end
end
