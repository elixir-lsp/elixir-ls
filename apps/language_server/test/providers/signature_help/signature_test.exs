# This code has originally been a part of https://github.com/elixir-lsp/elixir_sense

# Copyright (c) 2017 Marlus Saraiva
# Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the 'Software'), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
# The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

defmodule ElixirLS.LanguageServer.Providers.SignatureHelp.SignatureTest do
  use ExUnit.Case, async: true
  alias ElixirLS.LanguageServer.Providers.SignatureHelp.Signature

  describe "type signature" do
    test "find signatures from local type" do
      code = """
      defmodule MyModule do
        @typep my(a) :: {a, nil}
        @typep my(a, b) :: {a, b}
        @type a :: my(
      end
      """

      assert Signature.signature(code, 4, 19) == %{
               active_param: 0,
               signatures: [
                 %{
                   documentation: "",
                   name: "my",
                   params: ["a"],
                   spec: "@typep my(a) :: {a, nil}"
                 },
                 %{
                   documentation: "",
                   name: "my",
                   params: ["a", "b"],
                   spec: "@typep my(a, b) :: {a, b}"
                 }
               ]
             }
    end

    test "find signatures from local type, filter by arity" do
      code = """
      defmodule MyModule do
        @typep my(a) :: {a, nil}
        @typep my(a, b) :: {a, b}
        @type a :: my(atom,
      end
      """

      assert Signature.signature(code, 4, 25) == %{
               active_param: 1,
               signatures: [
                 %{
                   documentation: "",
                   name: "my",
                   params: ["a", "b"],
                   spec: "@typep my(a, b) :: {a, b}"
                 }
               ]
             }
    end

    test "find signatures from local type, filter by arity unfinished param" do
      code = """
      defmodule MyModule do
        @typep my(a) :: {a, nil}
        @typep my(a, b) :: {a, b}
        @type a :: my(atom
      end
      """

      assert Signature.signature(code, 4, 21) == %{
               active_param: 0,
               signatures: [
                 %{
                   documentation: "",
                   name: "my",
                   params: ["a"],
                   spec: "@typep my(a) :: {a, nil}"
                 },
                 %{
                   documentation: "",
                   name: "my",
                   params: ["a", "b"],
                   spec: "@typep my(a, b) :: {a, b}"
                 }
               ]
             }
    end

    test "find signatures from local type, filter by arity unfinished params" do
      code = """
      defmodule MyModule do
        @typep my(a) :: {a, nil}
        @typep my(a, b) :: {a, b}
        @type a :: my(atom, atom
      end
      """

      assert Signature.signature(code, 4, 27) == %{
               active_param: 1,
               signatures: [
                 %{
                   documentation: "",
                   name: "my",
                   params: ["a", "b"],
                   spec: "@typep my(a, b) :: {a, b}"
                 }
               ]
             }
    end

    test "find local metadata type signature even if it's defined after cursor" do
      buffer = """
      defmodule MyModule do
        @type remote_list_t :: [my_t(a)]
        #                            ^

        @typep my_t(abc) :: integer
      end
      """

      assert %{
               active_param: 0
             } =
               Signature.signature(buffer, 2, 32)
    end

    test "find type signatures" do
      code = """
      defmodule MyModule do
        @type a :: ElixirSenseExample.ModuleWithTypespecs.Remote.remote_t(
      end
      """

      assert Signature.signature(code, 2, 69) == %{
               active_param: 0,
               signatures: [
                 %{
                   documentation: "Remote type",
                   name: "remote_t",
                   params: [],
                   spec: "@type remote_t() :: atom()"
                 },
                 %{
                   documentation: "Remote type with params",
                   name: "remote_t",
                   params: ["a", "b"],
                   spec: "@type remote_t(a, b) ::\n  {a, b}"
                 }
               ]
             }
    end

    test "does not reveal opaque type details" do
      code = """
      defmodule MyModule do
        @type a :: ElixirSenseExample.ModuleWithTypespecs.Remote.some_opaque_options_t(
      end
      """

      assert Signature.signature(code, 2, 82) == %{
               active_param: 0,
               signatures: [
                 %{
                   documentation: "",
                   name: "some_opaque_options_t",
                   params: [],
                   spec: "@opaque some_opaque_options_t()"
                 }
               ]
             }
    end

    test "does not reveal local opaque type details" do
      code = """
      defmodule Some do
        @opaque my(a, b) :: {a, b}
      end
      defmodule MyModule do
        @type a :: Some.my(
      end
      """

      assert Signature.signature(code, 5, 22) == %{
               active_param: 0,
               signatures: [
                 %{
                   documentation: "",
                   name: "my",
                   params: ["a", "b"],
                   spec: "@opaque my(a, b)"
                 }
               ]
             }
    end

    test "find type signatures with @typedoc false" do
      code = """
      defmodule MyModule do
        @type a :: ElixirSenseExample.ModuleWithDocs.some_type_doc_false(
      end
      """

      assert Signature.signature(code, 2, 68) == %{
               active_param: 0,
               signatures: [
                 %{
                   documentation: "",
                   name: "some_type_doc_false",
                   params: ~c"",
                   spec: "@type some_type_doc_false() :: integer()"
                 }
               ]
             }
    end

    test "does not find builtin type signatures with Elixir prefix" do
      code = """
      defmodule MyModule do
        @type a :: Elixir.keyword(
      end
      """

      assert Signature.signature(code, 2, 29) == :none
    end

    test "find type signatures from erlang module" do
      code = """
      defmodule MyModule do
        @type a :: :erlang.time_unit(
      end
      """

      assert %{
               active_param: 0,
               signatures: [
                 %{
                   documentation: summary,
                   name: "time_unit",
                   params: [],
                   spec: "@type time_unit() ::" <> _
                 }
               ]
             } = Signature.signature(code, 2, 32)

      if System.otp_release() |> String.to_integer() >= 23 do
        if System.otp_release() |> String.to_integer() >= 27 do
          assert "The time unit" <> _ = summary
        else
          assert summary =~ "Supported time unit representations"
        end
      end
    end

    test "find type signatures from builtin type" do
      code = """
      defmodule MyModule do
        @type a :: number(
      end
      """

      assert Signature.signature(code, 2, 21) == %{
               active_param: 0,
               signatures: [
                 %{
                   params: [],
                   documentation: "An integer or a float",
                   name: "number",
                   spec: "@type number() :: integer() | float()"
                 }
               ]
             }
    end
  end

  describe "macro signature" do
    test "find signatures from aliased modules" do
      code = """
      defmodule MyModule do
        require ElixirSenseExample.BehaviourWithMacrocallback.Impl, as: Macros
        Macros.some(
      end
      """

      assert Signature.signature(code, 3, 15) == %{
               active_param: 0,
               signatures: [
                 %{
                   documentation: "some macro\n",
                   name: "some",
                   params: ["var"],
                   spec:
                     "@spec some(integer()) :: Macro.t()\n@spec some(b) :: Macro.t() when b: float()"
                 }
               ]
             }
    end

    test "find signatures special forms" do
      code = """
      defmodule MyModule do
        __MODULE__(
      end
      """

      assert Signature.signature(code, 2, 14) == %{
               active_param: 0,
               signatures: [
                 %{
                   documentation:
                     "Returns the current module name as an atom or `nil` otherwise.",
                   name: "__MODULE__",
                   params: [],
                   spec: ""
                 }
               ]
             }
    end
  end

  describe "function signature" do
    test "find signatures from erlang module" do
      code = """
      defmodule MyModule do
        :lists.flatten(
      end
      """

      assert %{
               active_param: 0,
               signatures: [
                 %{
                   documentation: summary1,
                   name: "flatten",
                   params: [_],
                   spec:
                     "@spec flatten(deepList) :: list when deepList: [term() | deepList], list: [term()]"
                 },
                 %{
                   documentation: summary2,
                   name: "flatten",
                   params: params,
                   spec:
                     "@spec flatten(deepList, tail) :: list when deepList: [term() | deepList], tail: [term()], list: [term()]"
                 }
               ]
             } = Signature.signature(code, 2, 24)

      if System.otp_release() |> String.to_integer() >= 23 do
        if System.otp_release() |> String.to_integer() >= 27 do
          assert params == ["DeepList", "Tail"]
        else
          assert params == ["deepList", "tail"]
        end

        assert "Returns a flattened version of `DeepList`" <> _ = summary1

        assert "Returns a flattened version of `DeepList` with tail `Tail` appended" <> _ =
                 summary2
      end
    end

    test "find signatures from aliased modules" do
      code = """
      defmodule MyModule do
        alias List, as: MyList
        MyList.flatten(
      end
      """

      assert Signature.signature(code, 3, 23) == %{
               active_param: 0,
               signatures: [
                 %{
                   name: "flatten",
                   params: ["list"],
                   documentation: "Flattens the given `list` of nested lists.",
                   spec: "@spec flatten(deep_list) :: list() when deep_list: [any() | deep_list]"
                 },
                 %{
                   name: "flatten",
                   params: ["list", "tail"],
                   documentation:
                     "Flattens the given `list` of nested lists.\nThe list `tail` will be added at the end of\nthe flattened list.",
                   spec:
                     "@spec flatten(deep_list, [elem]) :: [elem] when deep_list: [elem | deep_list], elem: var"
                 }
               ]
             }
    end

    test "find signatures from aliased modules aaa" do
      code = """
      defmodule MyModule do
        alias NonExisting, as: List
        Elixir.List.flatten(
      end
      """

      assert Signature.signature(code, 3, 28) == %{
               active_param: 0,
               signatures: [
                 %{
                   name: "flatten",
                   params: ["list"],
                   documentation: "Flattens the given `list` of nested lists.",
                   spec: "@spec flatten(deep_list) :: list() when deep_list: [any() | deep_list]"
                 },
                 %{
                   name: "flatten",
                   params: ["list", "tail"],
                   documentation:
                     "Flattens the given `list` of nested lists.\nThe list `tail` will be added at the end of\nthe flattened list.",
                   spec:
                     "@spec flatten(deep_list, [elem]) :: [elem] when deep_list: [elem | deep_list], elem: var"
                 }
               ]
             }
    end

    test "find signatures from imported modules" do
      code = """
      defmodule MyModule do
        import List
        flatten(
      end
      """

      assert Signature.signature(code, 3, 16) == %{
               active_param: 0,
               signatures: [
                 %{
                   name: "flatten",
                   params: ["list"],
                   documentation: "Flattens the given `list` of nested lists.",
                   spec: "@spec flatten(deep_list) :: list() when deep_list: [any() | deep_list]"
                 },
                 %{
                   name: "flatten",
                   params: ["list", "tail"],
                   documentation:
                     "Flattens the given `list` of nested lists.\nThe list `tail` will be added at the end of\nthe flattened list.",
                   spec:
                     "@spec flatten(deep_list, [elem]) :: [elem] when deep_list: [elem | deep_list], elem: var"
                 }
               ]
             }
    end

    test "find signatures when function with default args" do
      code = """
      defmodule MyModule do
        List.pop_at(par1,
      end
      """

      assert Signature.signature(code, 2, 21) == %{
               active_param: 1,
               signatures: [
                 %{
                   documentation:
                     "Returns and removes the value at the specified `index` in the `list`.",
                   name: "pop_at",
                   params: ["list", "index", "default \\\\ nil"],
                   spec: "@spec pop_at(list(), integer(), any()) :: {any(), list()}"
                 }
               ]
             }
    end

    test "find signatures when function with many clauses" do
      code = """
      defmodule MyModule do
        List.starts_with?(
      end
      """

      assert %{
               active_param: 0,
               signatures: [
                 %{
                   documentation:
                     "Returns `true` if `list` starts with the given `prefix` list" <> _,
                   name: "starts_with?",
                   params: ["list", "prefix"],
                   spec:
                     "@spec starts_with?([...], [...]) :: boolean()\n@spec starts_with?(list(), []) :: true\n@spec starts_with?([], [...]) :: false"
                 }
               ]
             } = Signature.signature(code, 2, 21)
    end

    test "find signatures for function with @doc false" do
      code = """
      defmodule MyModule do
        ElixirSenseExample.ModuleWithDocs.some_fun_doc_false(
      end
      """

      assert Signature.signature(code, 2, 56) == %{
               active_param: 0,
               signatures: [
                 %{
                   documentation: "",
                   name: "some_fun_doc_false",
                   params: ["a", "b \\\\ nil"],
                   spec: ""
                 }
               ]
             }
    end

    test "find signatures from atom modules" do
      code = """
      defmodule MyModule do
        :"Elixir.List".flatten(
      end
      """

      assert Signature.signature(code, 2, 31) == %{
               active_param: 0,
               signatures: [
                 %{
                   name: "flatten",
                   params: ["list"],
                   documentation: "Flattens the given `list` of nested lists.",
                   spec: "@spec flatten(deep_list) :: list() when deep_list: [any() | deep_list]"
                 },
                 %{
                   name: "flatten",
                   params: ["list", "tail"],
                   documentation:
                     "Flattens the given `list` of nested lists.\nThe list `tail` will be added at the end of\nthe flattened list.",
                   spec:
                     "@spec flatten(deep_list, [elem]) :: [elem] when deep_list: [elem | deep_list], elem: var"
                 }
               ]
             }
    end

    test "find signatures from __MODULE__" do
      code = """
      defmodule Inspect.Algebra do
        __MODULE__.glue(par1,
      end
      """

      assert Signature.signature(code, 2, 24) == %{
               active_param: 1,
               signatures: [
                 %{
                   documentation:
                     "Glues two documents (`doc1` and `doc2`) inserting the given\nbreak `break_string` between them.",
                   name: "glue",
                   params: ["doc1", "break_string \\\\ \" \"", "doc2"],
                   spec: "@spec glue(t(), binary(), t()) :: t()",
                   active_param: 2
                 }
               ]
             }
    end

    test "find signatures from __MODULE__ submodule" do
      code = """
      defmodule Inspect do
        __MODULE__.Algebra.glue(par1,
      end
      """

      assert Signature.signature(code, 2, 32) == %{
               active_param: 1,
               signatures: [
                 %{
                   documentation:
                     "Glues two documents (`doc1` and `doc2`) inserting the given\nbreak `break_string` between them.",
                   name: "glue",
                   params: ["doc1", "break_string \\\\ \" \"", "doc2"],
                   spec: "@spec glue(t(), binary(), t()) :: t()",
                   active_param: 2
                 }
               ]
             }
    end

    test "find signatures from attribute" do
      code = """
      defmodule MyMod do
        @attribute Inspect.Algebra
        @attribute.glue(par1,
      end
      """

      assert Signature.signature(code, 3, 24) == %{
               active_param: 1,
               signatures: [
                 %{
                   documentation:
                     "Glues two documents (`doc1` and `doc2`) inserting the given\nbreak `break_string` between them.",
                   name: "glue",
                   params: ["doc1", "break_string \\\\ \" \"", "doc2"],
                   spec: "@spec glue(t(), binary(), t()) :: t()",
                   active_param: 2
                 }
               ]
             }
    end

    @tag :capture_log
    test "find signatures from attribute submodule" do
      code = """
      defmodule Inspect do
        @attribute Inspect
        @attribute.Algebra.glue(par1,
      end
      """

      assert Signature.signature(code, 3, 32) == %{
               active_param: 1,
               signatures: [
                 %{
                   documentation:
                     "Glues two documents (`doc1` and `doc2`) inserting the given\nbreak `break_string` between them.",
                   name: "glue",
                   params: ["doc1", "break_string \\\\ \" \"", "doc2"],
                   spec: "@spec glue(t(), binary(), t()) :: t()",
                   active_param: 2
                 }
               ]
             }
    end

    test "find signatures from variable" do
      code = """
      defmodule MyMod do
        myvariable = Inspect.Algebra
        myvariable.glue(par1,
      end
      """

      assert Signature.signature(code, 3, 24) == %{
               active_param: 1,
               signatures: [
                 %{
                   documentation:
                     "Glues two documents (`doc1` and `doc2`) inserting the given\nbreak `break_string` between them.",
                   name: "glue",
                   params: ["doc1", "break_string \\\\ \" \"", "doc2"],
                   spec: "@spec glue(t(), binary(), t()) :: t()",
                   active_param: 2
                 }
               ]
             }
    end

    @tag :capture_log
    test "find signatures from variable submodule - don't crash" do
      code = """
      defmodule Inspect do
        myvariable = Inspect
        myvariable.Algebra.glue(par1,
      end
      """

      assert Signature.signature(code, 3, 32) == :none
    end

    test "find signatures from variable call" do
      code = """
      defmodule Inspect do
        myvariable = &Inspect.Algebra.glue/2
        myvariable.(par1,
      end
      """

      # TODO https://github.com/elixir-lsp/elixir_sense/issues/255
      # Type system needs to handle function captures
      assert Signature.signature(code, 3, 20) == :none
    end

    test "find signatures from attribute call" do
      code = """
      defmodule Inspect do
        @attribute &Inspect.Algebra.glue/2
        @attribute.(par1,
      end
      """

      # TODO https://github.com/elixir-lsp/elixir_sense/issues/255
      # Type system needs to handle function captures
      assert Signature.signature(code, 3, 20) == :none
    end

    test "finds signatures from Kernel functions" do
      code = """
      defmodule MyModule do
        apply(par1,
      end
      """

      assert %{
               active_param: 1,
               signatures: [
                 %{
                   name: "apply",
                   params: ["fun", "args"],
                   documentation:
                     "Invokes the given anonymous function `fun` with the list of\narguments `args`.",
                   spec: "@spec apply(" <> _
                 },
                 %{
                   name: "apply",
                   params: ["module", "function_name", "args"],
                   documentation:
                     "Invokes the given function from `module` with the list of\narguments `args`.",
                   spec: "@spec apply(module(), function_name :: atom(), [any()]) :: any()"
                 }
               ]
             } = Signature.signature(code, 2, 14)
    end

    test "finds signatures from local functions" do
      code = """
      defmodule MyModule do

        def run do
          sum(
        end

        defp sum(a, b) do
          a + b
        end

        defp sum({a, b}) do
          a + b
        end
      end
      """

      assert Signature.signature(code, 4, 9) == %{
               active_param: 0,
               signatures: [
                 %{
                   name: "sum",
                   params: ["tuple"],
                   documentation: "",
                   spec: ""
                 },
                 %{
                   name: "sum",
                   params: ["a", "b"],
                   documentation: "",
                   spec: ""
                 }
               ]
             }
    end

    test "finds signatures from local functions, filter by arity" do
      code = """
      defmodule MyModule do

        def run do
          sum(a,
        end

        defp sum(a, b) do
          a + b
        end

        defp sum({a, b}) do
          a + b
        end
      end
      """

      assert Signature.signature(code, 4, 12) == %{
               active_param: 1,
               signatures: [
                 %{
                   name: "sum",
                   params: ["a", "b"],
                   documentation: "",
                   spec: ""
                 }
               ]
             }
    end

    test "finds signatures from module with many function clauses" do
      code = """
      defmodule Other do
        alias ElixirSenseExample.ModuleWithManyClauses, as: MyModule
        def run do
          MyModule.sum(a,
        end
      end
      """

      assert Signature.signature(code, 4, 21) == %{
               active_param: 1,
               signatures: [
                 %{
                   documentation: "",
                   name: "sum",
                   spec: "",
                   params: ["s \\\\ nil", "f"],
                   active_param: 0
                 },
                 %{documentation: "", name: "sum", spec: "", params: ["arg", "x", "y"]}
               ]
             }
    end

    test "finds signatures from metadata module functions" do
      code = """
      defmodule MyModule do
        def sum(s \\\\ nil, f)
        def sum(a, nil), do: nil
        def sum(a, b) do
          a + b
        end

        def sum({a, b}, x, y) do
          a + b + x + y
        end
      end

      defmodule Other do
        def run do
          MyModule.sum(a,
        end
      end
      """

      assert Signature.signature(code, 15, 21) == %{
               active_param: 1,
               signatures: [
                 %{
                   documentation: "",
                   name: "sum",
                   params: ["s \\\\ nil", "f"],
                   spec: "",
                   active_param: 0
                 },
                 %{documentation: "", name: "sum", params: ["tuple", "x", "y"], spec: ""}
               ]
             }
    end

    test "does not finds signatures from metadata module private functions" do
      code = """
      defmodule MyModule do
        defp sum(a, nil), do: nil
        defp sum(a, b) do
          a + b
        end

        defp sum({a, b}) do
          a + b
        end
      end

      defmodule Other do
        def run do
          MyModule.sum(a,
        end
      end
      """

      assert Signature.signature(code, 14, 21) == :none
    end

    test "finds signatures from metadata module functions with default param" do
      code = """
      defmodule MyModule do
        @spec sum(integer, integer) :: integer
        defp sum(a, b \\\\ 0) do
          a + b
        end

        def run do
          sum(a,
        end
      end
      """

      assert Signature.signature(code, 8, 11) == %{
               active_param: 1,
               signatures: [
                 %{
                   name: "sum",
                   params: ["a", "b \\\\ 0"],
                   documentation: "",
                   spec: "@spec sum(integer(), integer()) :: integer()"
                 }
               ]
             }
    end

    test "finds signatures from metadata module functions with default param - correctly highlight active param" do
      code = """
      defmodule MyModule do
        @spec sum(integer, integer, integer, integer, integer, integer) :: integer
        defp sum(a \\\\ 1, b \\\\ 1, c, d, e \\\\ 1, f \\\\ 1) do
          a + b
        end

        def run do
          sum(1, 2, 3, 4, 5, 6)
        end
      end
      """

      assert Signature.signature(code, 8, 10) == %{
               active_param: 0,
               signatures: [
                 %{
                   name: "sum",
                   params: [
                     "a \\\\ 1",
                     "b \\\\ 1",
                     "c",
                     "d",
                     "e \\\\ 1",
                     "f \\\\ 1"
                   ],
                   documentation: "",
                   spec:
                     "@spec sum(integer(), integer(), integer(), integer(), integer(), integer()) :: integer()",
                   active_param: 2
                 }
               ]
             }

      assert %{
               active_param: 1,
               signatures: [%{active_param: 3}]
             } = Signature.signature(code, 8, 13)

      assert %{
               active_param: 2,
               signatures: [%{active_param: 0}]
             } = Signature.signature(code, 8, 16)

      assert %{
               active_param: 3,
               signatures: [%{active_param: 1}]
             } = Signature.signature(code, 8, 19)

      assert %{
               active_param: 4,
               signatures: [signature]
             } = Signature.signature(code, 8, 22)

      refute Map.has_key?(signature, :active_param)

      assert %{
               active_param: 5,
               signatures: [signature]
             } = Signature.signature(code, 8, 25)

      refute Map.has_key?(signature, :active_param)
    end

    test "finds signatures from metadata elixir behaviour call" do
      code = """
      defmodule MyModule do
        use GenServer

        def handle_call(request, _from, state) do
          terminate()
        end

        def init(arg), do: arg

        def handle_cast(arg, _state) when is_atom(arg) do
          :ok
        end
      end
      """

      assert %{
               active_param: 0,
               signatures: [
                 %{
                   name: "terminate",
                   params: ["_reason", "_state"],
                   documentation: "Invoked when the server is about to exit" <> _,
                   spec: "@callback terminate(reason, state :: term()) :: term()" <> _
                 }
               ]
             } = Signature.signature(code, 5, 15)
    end

    test "finds signatures from metadata erlang behaviour call" do
      code = """
      defmodule MyModule do
        @behaviour :gen_server

        def handle_call(request, _from, state) do
          init()
        end

        def init(arg), do: arg

        def handle_cast(arg, _state) when is_atom(arg) do
          :ok
        end
      end
      """

      assert %{
               active_param: 0,
               signatures: [
                 %{
                   name: "init",
                   params: ["arg"],
                   documentation: summary,
                   spec: "@callback init(args :: term()) ::" <> _
                 }
               ]
             } = Signature.signature(code, 5, 10)

      if System.otp_release() |> String.to_integer() >= 23 do
        if System.otp_release() |> String.to_integer() >= 27 do
          assert "Initialize the server" <> _ = summary
        else
          assert "- Args = " <> _ = summary
        end
      end
    end

    test "finds signatures from metadata elixir behaviour call from outside" do
      code = """
      require ElixirSenseExample.ExampleBehaviourWithDocCallbackImpl
      ElixirSenseExample.ExampleBehaviourWithDocCallbackImpl.bar()
      """

      assert %{
               active_param: 0,
               signatures: [
                 %{
                   documentation: "Docs for bar",
                   name: "bar",
                   params: ["b"],
                   spec: "@macrocallback bar(integer()) :: Macro.t()"
                 }
               ]
             } = Signature.signature(code, 2, 60)
    end

    test "finds signatures from metadata erlang behaviour implemented in elixir call from outside" do
      code = """
      ElixirSenseExample.ExampleBehaviourWithDocCallbackErlang.init()
      """

      res = Signature.signature(code, 1, 63)

      if System.otp_release() |> String.to_integer() >= 23 do
        assert %{
                 active_param: 0,
                 signatures: [
                   %{
                     documentation: documentation,
                     name: "init",
                     params: ["_"],
                     spec: "@callback init(args :: term()) :: init_result(state())"
                   }
                 ]
               } = res

        if System.otp_release() |> String.to_integer() >= 27 do
          assert "Initialize the state machine" <> _ = documentation
        else
          assert "- Args = " <> _ = documentation
        end
      end
    end

    if System.otp_release() |> String.to_integer() >= 25 do
      test "finds signatures from metadata erlang behaviour call from outside" do
        code = """
        :file_server.init()
        """

        res = Signature.signature(code, 1, 19)

        assert %{
                 active_param: 0,
                 signatures: [
                   %{
                     documentation: summary,
                     name: "init",
                     params: ["args"],
                     spec: "@callback init(args :: term()) ::" <> _
                   }
                 ]
               } = res

        if System.otp_release() |> String.to_integer() >= 27 do
          assert "Initialize the server" <> _ = summary
        else
          assert "- Args = " <> _ = summary
        end
      end
    end

    test "retrieve metadata function signature - fallback to callback in metadata" do
      code = """
      defmodule MyBehaviour do
        @doc "Sample doc"
        @doc since: "1.2.3"
        @callback flatten(list()) :: list()
      end

      defmodule MyLocalModule do
        @behaviour MyBehaviour

        @impl true
        def flatten(list) do
          []
        end
      end

      defmodule MyModule do
        def func(list) do
          MyLocalModule.flatten(list)
        end
      end
      """

      res = Signature.signature(code, 18, 27)

      assert %{
               active_param: 0,
               signatures: [
                 %{
                   documentation: "Sample doc",
                   name: "flatten",
                   params: ["list"],
                   spec: "@callback flatten(list()) :: list()"
                 }
               ]
             } = res
    end

    test "retrieve metadata function signature - fallback to protocol function in metadata" do
      code = """
      defprotocol BB do
        @doc "asdf"
        @spec go(t) :: integer()
        def go(t)
      end

      defimpl BB, for: String do
        def go(t), do: ""
      end

      defmodule MyModule do
        def func(list) do
          BB.String.go(list)
        end
      end
      """

      res = Signature.signature(code, 13, 18)

      assert %{
               active_param: 0,
               signatures: [
                 %{
                   documentation: "asdf",
                   name: "go",
                   params: ["t"],
                   spec: "@callback go(t()) :: integer()"
                 }
               ]
             } = res
    end

    test "retrieve metadata macro signature - fallback to macrocallback in metadata" do
      code = """
      defmodule MyBehaviour do
        @doc "Sample doc"
        @doc since: "1.2.3"
        @macrocallback flatten(list()) :: list()
      end

      defmodule MyLocalModule do
        @behaviour MyBehaviour

        @impl true
        defmacro flatten(list) do
          []
        end
      end

      defmodule MyModule do
        require MyLocalModule
        def func(list) do
          MyLocalModule.flatten(list)
        end
      end
      """

      res = Signature.signature(code, 19, 27)

      assert %{
               active_param: 0,
               signatures: [
                 %{
                   documentation: "Sample doc",
                   name: "flatten",
                   params: ["list"],
                   spec: "@macrocallback flatten(list()) :: list()"
                 }
               ]
             } = res
    end

    test "retrieve metadata function signature - fallback to callback" do
      code = """
      defmodule MyLocalModule do
        @behaviour ElixirSenseExample.BehaviourWithMeta

        @impl true
        def flatten(list) do
          []
        end
      end

      defmodule MyModule do
        def func(list) do
          MyLocalModule.flatten(list)
        end
      end
      """

      res = Signature.signature(code, 12, 27)

      assert %{
               active_param: 0,
               signatures: [
                 %{
                   documentation: "Sample doc",
                   name: "flatten",
                   params: ["list"],
                   spec: "@callback flatten(list()) :: list()"
                 }
               ]
             } = res
    end

    test "retrieve metadata function signature - fallback to erlang callback" do
      code = """
      defmodule MyLocalModule do
        @behaviour :gen_statem

        @impl true
        def init(list) do
          []
        end
      end

      defmodule MyModule do
        def func(list) do
          MyLocalModule.init(list)
        end
      end
      """

      res = Signature.signature(code, 12, 27)

      if System.otp_release() |> String.to_integer() >= 23 do
        assert %{
                 active_param: 0,
                 signatures: [
                   %{
                     documentation: summary,
                     name: "init",
                     params: ["list"],
                     spec: "@callback init(args :: term()) :: init_result(state())"
                   }
                 ]
               } = res

        if System.otp_release() |> String.to_integer() >= 27 do
          assert "Initialize the state machine" <> _ = summary
        else
          assert "- Args = term" <> _ = summary
        end
      end
    end

    test "retrieve metadata function signature - fallback to remote protocol callback" do
      code = """
      defimpl Enumerable, for: Date do
        def count(a) do
          :ok
        end
      end

      Enumerable.impl_for()
      """

      res = Signature.signature(code, 7, 21)

      if Version.match?(System.version(), ">= 1.18.0") do
        assert %{
                 active_param: 0,
                 signatures: [
                   %{
                     documentation: "A function available in all protocol definitions" <> _,
                     name: "impl_for",
                     params: ["data"],
                     spec: "@callback impl_for(term()) :: module() | nil"
                   }
                 ]
               } = res
      else
        assert %{
                 active_param: 0,
                 signatures: [
                   %{
                     documentation: "Returns the module" <> _,
                     name: "impl_for",
                     params: ["data"],
                     spec: "@spec impl_for(term) :: atom | nil"
                   }
                 ]
               } = res
      end
    end

    test "retrieve metadata macro signature - fallback to macrocallback" do
      code = """
      defmodule MyLocalModule do
        @behaviour ElixirSenseExample.BehaviourWithMeta

        @impl true
        defmacro bar(list) do
          []
        end
      end

      defmodule MyModule do
        require MyLocalModule
        def func(list) do
          MyLocalModule.bar(list)
        end
      end
      """

      res = Signature.signature(code, 13, 27)

      assert %{
               active_param: 0,
               signatures: [
                 %{
                   documentation: "Docs for bar",
                   name: "bar",
                   params: ["list"],
                   spec: "@macrocallback bar(integer()) :: Macro.t()"
                 }
               ]
             } = res
    end

    test "find signature of local macro" do
      code = """
      defmodule MyModule do
        defmacrop some(var), do: Macro.expand(var, __CALLER__)

        defmacro other do
          some(1)
        end
      end
      """

      res = Signature.signature(code, 5, 10)

      assert %{
               active_param: 0,
               signatures: [
                 %{
                   documentation: "",
                   name: "some",
                   params: ["var"],
                   spec: ""
                 }
               ]
             } = res
    end

    test "does not find signature of local macro if it's defined after the cursor" do
      code = """
      defmodule MyModule do
        defmacro other do
          some(1)
        end

        defmacrop some(var), do: Macro.expand(var, __CALLER__)
      end
      """

      assert Signature.signature(code, 3, 10) == :none
    end

    test "find signature of local function even if it's defined after the cursor" do
      code = """
      defmodule MyModule do
        def other do
          some(1)
        end

        defp some(var), do: :ok
      end
      """

      assert res = Signature.signature(code, 3, 10)

      assert res == %{
               active_param: 0,
               signatures: [%{documentation: "", name: "some", params: ["var"], spec: ""}]
             }
    end

    test "returns :none when it cannot identify a function call" do
      code = """
      defmodule MyModule do
        fn(a,
      end
      """

      if Version.match?(System.version(), "< 1.18.0") do
        assert Signature.signature(code, 2, 8) == :none
      else
        assert %{
                 signatures: [
                   %{name: "defmodule"}
                 ],
                 active_param: 1
               } = Signature.signature(code, 2, 8)
      end
    end

    test "return :none when no signature is found" do
      code = """
      defmodule MyModule do
        a_func(
      end
      """

      assert Signature.signature(code, 2, 10) == :none
    end

    test "after |>" do
      code = """
      defmodule MyModule do
        {1, 2} |> IO.inspect(
      end
      """

      assert %{
               active_param: 1,
               signatures: [
                 %{
                   name: "inspect",
                   params: ["item", "opts \\\\ []"],
                   documentation: "Inspects and writes the given `item`" <> _,
                   spec: "@spec inspect(" <> _
                 },
                 %{
                   name: "inspect",
                   params: ["device", "item", "opts"],
                   documentation:
                     "Inspects `item` according to the given options using the IO `device`.",
                   spec: "@spec inspect(device(), item, keyword()) :: item when item: var"
                 }
               ]
             } = Signature.signature(code, 2, 24)
    end

    test "after |> variable" do
      code = """
      s |> String.replace_prefix(
      """

      assert %{
               active_param: 1
             } = Signature.signature(code, 1, 28)
    end

    test "find built-in functions" do
      # module_info is defined by default for every elixir and erlang module
      # __info__ is defined for every elixir module
      # behaviour_info is defined for every behaviour and every protocol
      buffer = """
      defmodule MyModule do
        ElixirSenseExample.ModuleWithFunctions.module_info()
        #                                                  ^
        ElixirSenseExample.ModuleWithFunctions.__info__(:macros)
        #                                               ^
        ElixirSenseExample.ExampleBehaviour.behaviour_info(:callbacks)
        #                                                  ^
      end
      """

      assert %{
               active_param: 0,
               signatures: [
                 %{
                   documentation: "The `module_info/0` function" <> _,
                   name: "module_info",
                   params: [],
                   spec:
                     "@spec module_info :: [{:module | :attributes | :compile | :exports | :md5 | :native, term}]"
                 },
                 %{
                   documentation: "The call `module_info(Key)`" <> _,
                   name: "module_info",
                   params: ["key"],
                   spec: """
                   @spec module_info(:module) :: atom
                   @spec module_info(:attributes | :compile) :: [{atom, term}]
                   @spec module_info(:md5) :: binary
                   @spec module_info(:exports | :functions | :nifs) :: [{atom, non_neg_integer}]
                   @spec module_info(:native) :: boolean\
                   """
                 }
               ]
             } = Signature.signature(buffer, 2, 54)

      assert %{
               active_param: 0,
               signatures: [
                 %{
                   documentation: "Provides runtime informatio" <> _,
                   name: "__info__",
                   params: ["atom"],
                   spec: """
                   @spec __info__(:attributes) :: keyword()
                   @spec __info__(:compile) :: [term()]
                   @spec __info__(:functions) :: [{atom, non_neg_integer}]
                   @spec __info__(:macros) :: [{atom, non_neg_integer}]
                   @spec __info__(:md5) :: binary()
                   @spec __info__(:module) :: module()\
                   """
                 }
               ]
             } = Signature.signature(buffer, 4, 51)

      assert %{
               active_param: 0,
               signatures: [
                 %{
                   documentation: "The `behaviour_info(Key)`" <> _,
                   name: "behaviour_info",
                   params: ["key"],
                   spec:
                     "@spec behaviour_info(:callbacks | :optional_callbacks) :: [{atom, non_neg_integer}]"
                 }
               ]
             } = Signature.signature(buffer, 6, 54)
    end

    test "built-in functions cannot be called locally" do
      # module_info is defined by default for every elixir and erlang module
      # __info__ is defined for every elixir module
      # behaviour_info is defined for every behaviour and every protocol
      buffer = """
      defmodule MyModule do
        import GenServer
        @ callback cb() :: term
        module_info()
        #           ^
        __info__(:macros)
        #        ^
        behaviour_info(:callbacks)
        #              ^
      end
      """

      assert :none = Signature.signature(buffer, 4, 15)

      assert :none = Signature.signature(buffer, 6, 12)

      assert :none = Signature.signature(buffer, 8, 18)
    end

    if System.otp_release() |> String.to_integer() >= 23 do
      test "find built-in erlang functions" do
        buffer = """
        defmodule MyModule do
          :erlang.orelse()
          #             ^
          :erlang.or()
          #         ^
        end
        """

        %{
          active_param: 0,
          signatures: [
            %{
              documentation: "",
              name: "orelse",
              params: ["term", "term"],
              spec: ""
            }
          ]
        } = Signature.signature(buffer, 2, 18)

        assert %{
                 active_param: 0,
                 signatures: [
                   %{
                     documentation: "",
                     name: "or",
                     params: [_, _],
                     spec: "@spec boolean() or boolean() :: boolean()"
                   }
                 ]
               } = Signature.signature(buffer, 4, 14)
      end
    end

    test "find :erlang module functions with different forms of typespecs" do
      buffer = """
      defmodule MyModule do
        :erlang.date()
        #           ^
        :erlang.cancel_timer()
        #                   ^
      end
      """

      %{
        active_param: 0,
        signatures: [
          %{
            documentation: summary,
            name: "date",
            params: [],
            spec: "@spec date() :: date when date: :calendar.date()"
          }
        ]
      } = Signature.signature(buffer, 2, 16)

      if System.otp_release() |> String.to_integer() >= 23 do
        assert "Returns the current date as" <> _ = summary
      end

      assert %{
               active_param: 0,
               signatures: [
                 %{
                   documentation: summary1,
                   name: "cancel_timer",
                   params: [_],
                   spec: "@spec cancel_timer(timerRef) :: result" <> _
                 },
                 %{
                   documentation: summary2,
                   name: "cancel_timer",
                   params: params,
                   spec: "@spec cancel_timer(timerRef, options) :: result" <> _
                 }
               ]
             } = Signature.signature(buffer, 4, 24)

      if System.otp_release() |> String.to_integer() >= 23 do
        assert "Cancels a timer that has been created by" <> _ = summary2

        if System.otp_release() |> String.to_integer() >= 27 do
          assert "" == summary1
          assert params == ["TimerRef", "Options"]
        else
          assert "Cancels a timer\\." <> _ = summary1
          assert params == ["timerRef", "options"]
        end
      end
    end
  end
end
