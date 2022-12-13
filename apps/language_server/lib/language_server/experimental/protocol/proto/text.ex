defmodule ElixirLS.LanguageServer.Experimental.Protocol.Proto.Text do
  def camelize(atom) when is_atom(atom) do
    atom |> Atom.to_string() |> camelize()
  end

  def camelize(string) do
    <<first::binary-size(1), rest::binary>> = Macro.camelize(string)
    String.downcase(first) <> rest
  end
end
