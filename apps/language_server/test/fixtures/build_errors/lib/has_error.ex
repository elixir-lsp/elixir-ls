defmodule ElixirLS.LanguageServer.Fixtures.BuildErrors.HasWarning do
  def my_fn2 do
    # Should cause build error
    does_not_exist()
  end
end
