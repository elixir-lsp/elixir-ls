defmodule ElixirLS.Debugger.Completions do
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
      label: "#{name}/#{arity}",
      text: snippet || name
    }
  end

  def map(%{
        type: :module,
        name: name
      }) do
    text =
      case name do
        ":" <> rest -> rest
        other -> other
      end

    %{
      type: "module",
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
        name: name
      }) do
    %{
      type: "field",
      label: name
    }
  end
end
