defmodule ElixirSenseExample.CaseTemplateExample do
  use ExUnit.CaseTemplate

  using do
    quote do
      alias Some.Module
    end
  end
end
