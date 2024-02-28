defmodule ElixirSense.Providers.ReferencesTest.Modules do
  defmodule Callee1 do
    def func() do
      IO.puts("")
    end

    def func(par1) do
      IO.puts(par1)
    end
  end

  defmodule Callee2 do
    def func() do
      IO.puts("")
    end
  end

  defmodule Callee3 do
    def func() do
      IO.puts("")
    end
  end

  defmodule Callee4 do
    def func_no_arg() do
      IO.puts("")
    end

    def func_arg(arg \\ "") do
      IO.puts("" <> arg)
    end
  end

  defmodule Caller1 do
    def func() do
      ElixirSense.Providers.ReferencesTest.Modules.Callee1.func()
    end
  end

  defmodule Caller2 do
    def func() do
      ElixirSense.Providers.ReferencesTest.Modules.Callee1.func("test")
    end
  end

  defmodule Caller3 do
    def func() do
      "test"
      |> ElixirSense.Providers.ReferencesTest.Modules.Callee4.func_arg()
    end
  end

  defmodule Caller4 do
    def func() do
      Task.start(&ElixirSense.Providers.ReferencesTest.Modules.Callee4.func_no_arg/0)
    end
  end

  defmodule CallerWithAliasesAndImports do
    alias ElixirSense.Providers.ReferencesTest.Modules.Callee1
    alias ElixirSense.Providers.ReferencesTest.Modules.Callee2, as: AliasedCallee2
    import ElixirSense.Providers.ReferencesTest.Modules.Callee3

    def call_all() do
      [Callee1.func(), AliasedCallee2.func(), func(), Callee1.func(), Callee1.func("1")]
    end

    def call_on_different_line() do
      Callee3.
        func()
    end

    def call_erlang() do
      :ets.new(:a, [])
    end
  end

  defmodule Callee5 do
    def func_arg(arg \\ "") do
      IO.puts("" <> arg)
    end

    def func_arg1(arg \\ "") do
      IO.puts("" <> arg)
    end
  end

  defmodule Caller5 do
    def func() do
      ElixirSense.Providers.ReferencesTest.Modules.Callee5.func_arg()
      ElixirSense.Providers.ReferencesTest.Modules.Callee5.func_arg1("a")
    end
  end

  defmodule Callee6 do
  end

  defmodule Caller6 do
    def func() do
      ElixirSense.Providers.ReferencesTest.Modules.Callee6.__info__(:function)
      ElixirSense.Providers.ReferencesTest.Modules.Callee6.module_info()
    end
  end

  defmodule Callee7 do
    def func_noarg() do
      IO.puts("")
    end
  end

  defmodule Caller7 do
    @attr ElixirSense.Providers.ReferencesTest.Modules.Callee7
    def func() do
      @attr.func_noarg()
    end
  end
end
