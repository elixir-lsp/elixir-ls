# This code has originally been a part of https://github.com/elixir-lsp/elixir_sense

# Copyright (c) 2017 Marlus Saraiva
# Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the 'Software'), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
# The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

defmodule ElixirLS.LanguageServer.Providers.Completion.SuggestionTest do
  use ExUnit.Case, async: true
  alias ElixirSense.Core.Source
  alias ElixirLS.LanguageServer.Providers.Completion.Suggestion

  import ExUnit.CaptureIO

  test "empty hint" do
    buffer = """
    defmodule MyModule do

    end
    """

    list = Suggestion.suggestions(buffer, 2, 7)

    assert %{
             args: "module, opts",
             args_list: ["module", "opts"],
             arity: 2,
             def_arity: 2,
             name: "import",
             origin: "Kernel.SpecialForms",
             spec: "",
             summary: "Imports functions and macros from other modules.",
             type: :macro,
             metadata: %{},
             snippet: nil,
             visibility: :public
           } = Enum.find(list, fn s -> match?(%{name: "import", arity: 2}, s) end)

    assert %{
             arity: 2,
             def_arity: 2,
             origin: "Kernel.SpecialForms",
             spec: "",
             type: :macro,
             args: "opts, block",
             args_list: ["opts", "block"],
             name: "quote",
             summary: "Gets the representation of any expression.",
             metadata: %{},
             snippet: nil,
             visibility: :public
           } = Enum.find(list, fn s -> match?(%{name: "quote", arity: 2}, s) end)

    assert %{
             arity: 2,
             def_arity: 2,
             origin: "Kernel.SpecialForms",
             spec: "",
             type: :macro,
             args: "module, opts",
             args_list: ["module", "opts"],
             name: "require",
             metadata: %{},
             snippet: nil,
             visibility: :public
           } = Enum.find(list, fn s -> match?(%{name: "require", arity: 2}, s) end)
  end

  test "without empty hint" do
    buffer = """
    defmodule MyModule do
      is_b
    end
    """

    list = Suggestion.suggestions(buffer, 2, 7)

    assert [
             %{
               name: "is_binary",
               origin: "Kernel",
               arity: 1
             },
             %{
               name: "is_bitstring",
               origin: "Kernel",
               arity: 1
             },
             %{
               name: "is_boolean",
               origin: "Kernel",
               arity: 1
             },
             %{
               name: "is_number",
               origin: "Kernel",
               arity: 1
             }
           ] = list
  end

  test "capture hint" do
    buffer = """
    defmodule MyModule do
      @attr "asd"
      def a(arg) do
        arg
        |> Enum.filter(&)
      end
    end
    """

    list = Suggestion.suggestions(buffer, 5, 21)

    assert list |> Enum.any?(&(&1.type == :module))
    assert list |> Enum.any?(&(&1.type == :function))
    assert list |> Enum.any?(&(&1.type == :variable))
    assert list |> Enum.any?(&(&1.type == :attribute))
  end

  test "pin hint 1" do
    buffer = """
    defmodule MyModule do
      @attr "asd"
      def a(arg) do
        case x() do
          {^} -> :ok
        end
      end
    end
    """

    list = Suggestion.suggestions(buffer, 5, 9)

    refute list |> Enum.any?(&(&1.type == :module))
    refute list |> Enum.any?(&(&1.type == :function))
    assert list |> Enum.any?(&(&1.type == :variable))
    refute list |> Enum.any?(&(&1.type == :attribute))
  end

  test "pin hint 2" do
    buffer = """
    defmodule MyModule do
      @attr "asd"
      def a(arg) do
        with ^ <- abc(),
            x <- cde(),
            y <- efg() do
            :ok
        end
      end
    end
    """

    list = Suggestion.suggestions(buffer, 4, 11)

    refute list |> Enum.any?(&(&1.type == :module))
    refute list |> Enum.any?(&(&1.type == :function))
    assert list |> Enum.any?(&(&1.type == :variable))
    refute list |> Enum.any?(&(&1.type == :attribute))
  end

  test "pin hint 3" do
    buffer = """
    defmodule MyModule do
      @attr "asd"
      def a(arg) do
        with {^} <- abc(),
            x <- cde(),
            y <- efg() do
            :ok
        end
      end
    end
    """

    list = Suggestion.suggestions(buffer, 4, 12)

    refute list |> Enum.any?(&(&1.type == :module))
    refute list |> Enum.any?(&(&1.type == :function))
    assert list |> Enum.any?(&(&1.type == :variable))
    refute list |> Enum.any?(&(&1.type == :attribute))
  end

  test "pin hint 4" do
    buffer = """
    defmodule MyModule do
      @attr "asd"
      def a(arg) do
        with a <- abc(),
            x <- cde(),
            y <- efg() do
            :ok
        else
          ^ -> :ok
          :ok -> :ok
        end
      end
    end
    """

    list = Suggestion.suggestions(buffer, 9, 8)

    refute list |> Enum.any?(&(&1.type == :module))
    refute list |> Enum.any?(&(&1.type == :function))
    assert list |> Enum.any?(&(&1.type == :variable))
    refute list |> Enum.any?(&(&1.type == :attribute))
  end

  test "no typespecs in function scope" do
    buffer = """
    defmodule MyModule do
      def go, do:
    end
    """

    list = Suggestion.suggestions(buffer, 2, 15)

    refute list |> Enum.any?(&(&1.type == :type_spec))
    assert list |> Enum.any?(&(&1.type == :function))
  end

  test "functions from unicode module" do
    buffer = """
    defmodule :你好 do
      def 运行 do
        IO.puts("你好")
      end
    end

    :你好.
    """

    list = Suggestion.suggestions(buffer, 7, 5)

    assert list |> Enum.any?(&(&1.type == :function && &1.name == "运行"))
  end

  test "with an alias" do
    buffer = """
    defmodule MyModule do
      alias List, as: MyList
      MyList.flat
    end
    """

    list = Suggestion.suggestions(buffer, 3, 14)

    assert [
             %{
               args: "list",
               args_list: ["list"],
               arity: 1,
               def_arity: 1,
               name: "flatten",
               origin: "List",
               spec: "@spec flatten(deep_list) :: list() when deep_list: [any() | deep_list]",
               summary: "Flattens the given `list` of nested lists.",
               type: :function,
               metadata: %{},
               visibility: :public,
               snippet: nil
             },
             %{
               args: "list, tail",
               args_list: ["list", "tail"],
               arity: 2,
               def_arity: 2,
               name: "flatten",
               origin: "List",
               spec:
                 "@spec flatten(deep_list, [elem]) :: [elem] when deep_list: [elem | deep_list], elem: var",
               summary:
                 "Flattens the given `list` of nested lists.\nThe list `tail` will be added at the end of\nthe flattened list.",
               type: :function,
               metadata: %{},
               visibility: :public,
               snippet: nil
             }
           ] = list
  end

  test "with a require" do
    buffer = """
    defmodule MyModule do
      require ElixirSenseExample.BehaviourWithMacrocallback.Impl, as: Macros
      Macros.so
    end
    """

    list = Suggestion.suggestions(buffer, 3, 12)

    assert [
             %{
               args: "var",
               args_list: ["var"],
               arity: 1,
               def_arity: 1,
               name: "some",
               origin: "ElixirSenseExample.BehaviourWithMacrocallback.Impl",
               spec:
                 "@spec some(integer()) :: Macro.t()\n@spec some(b) :: Macro.t() when b: float()",
               summary: "some macro\n",
               type: :macro,
               metadata: %{},
               snippet: nil,
               visibility: :public
             }
           ] = list
  end

  test "with a module hint" do
    buffer = """
    defmodule MyModule do
      ElixirSenseExample.ModuleWithDo
    end
    """

    list = Suggestion.suggestions(buffer, 2, 34)

    assert [
             %{
               name: "ModuleWithDocFalse",
               full_name: "ElixirSenseExample.ModuleWithDocFalse",
               subtype: nil,
               summary: "",
               type: :module,
               metadata: %{}
             },
             %{
               name: "ModuleWithDocs",
               full_name: "ElixirSenseExample.ModuleWithDocs",
               subtype: :behaviour,
               summary: "An example module\n",
               type: :module,
               metadata: %{since: "1.2.3"}
             },
             %{
               metadata: %{},
               name: "ModuleWithNoDocs",
               full_name: "ElixirSenseExample.ModuleWithNoDocs",
               subtype: nil,
               summary: "",
               type: :module
             }
           ] = list
  end

  test "lists metadata modules" do
    buffer = """
    defmodule MyServer do
      @moduledoc "Some"
      @moduledoc since: "1.2.3"
    end
    MySe
    """

    list =
      Suggestion.suggestions(buffer, 5, 5)
      |> Enum.filter(fn s -> s.type == :module end)

    assert [
             %{
               name: "MyServer",
               summary: "Some",
               type: :module,
               full_name: "MyServer",
               metadata: %{since: "1.2.3"},
               required_alias: nil,
               subtype: nil
             }
           ] = list
  end

  test "returns subtype on local modules" do
    buffer = """
    defprotocol MyProto do
    end
    MyPr
    """

    list =
      Suggestion.suggestions(buffer, 3, 5)
      |> Enum.filter(fn s -> s.type == :module end)

    assert [
             %{
               name: "MyProto",
               subtype: :protocol
             }
           ] = list
  end

  test "lists callbacks" do
    buffer = """
    defmodule MyServer do
      use GenServer

    end
    """

    list =
      Suggestion.suggestions(buffer, 3, 7)
      |> Enum.filter(fn s -> s.type == :callback && s.name == "code_change" end)

    assert [
             %{
               args: "old_vsn, state, extra",
               arity: 3,
               name: "code_change",
               origin: "GenServer",
               spec: "@callback code_change(old_vsn, state :: term(), extra :: term()) ::" <> _,
               summary:
                 "Invoked to change the state of the `GenServer` when a different version of a\nmodule is loaded (hot code swapping) and the state's term structure should be\nchanged.",
               type: :callback
             }
           ] = list
  end

  test "lists metadata behaviour callbacks" do
    buffer = """
    defmodule MyBehaviour do
      @doc "Some callback"
      @callback my_callback(integer()) :: any()

      @callback my_callback_optional(integer(), atom()) :: any()

      @deprecated "Replace me"
      @macrocallback my_macrocallback(integer()) :: Macro.t()

      @optional_callbacks my_callback_optional: 2
    end

    defmodule MyServer do
      @behaviour MyBehaviour

    end
    """

    list =
      Suggestion.suggestions(buffer, 15, 3)
      |> Enum.filter(fn s -> s.type == :callback end)

    assert [
             %{
               args: "integer()",
               arity: 1,
               name: "my_callback",
               origin: "MyBehaviour",
               spec: "@callback my_callback(integer()) :: any()",
               summary: "Some callback",
               type: :callback,
               args_list: ["integer()"],
               metadata: %{},
               subtype: :callback
             },
             %{
               args: "integer()",
               args_list: ["integer()"],
               arity: 1,
               metadata: %{deprecated: "Replace me"},
               name: "my_macrocallback",
               origin: "MyBehaviour",
               spec: "@macrocallback my_macrocallback(integer()) :: Macro.t()",
               subtype: :macrocallback,
               summary: "",
               type: :callback
             },
             %{
               args: "integer(), atom()",
               args_list: ["integer()", "atom()"],
               arity: 2,
               metadata: %{optional: true},
               name: "my_callback_optional",
               origin: "MyBehaviour",
               spec: "@callback my_callback_optional(integer(), atom()) :: any()",
               subtype: :callback,
               summary: "",
               type: :callback
             }
           ] = list
  end

  test "lists metadata protocol functions" do
    buffer = """
    defprotocol MyProto do
      @doc "Some callback"
      @doc since: "1.2.3"
      def my_fun(t)

      @doc deprecated: "1.2.3"
      @spec my_fun_other(t(), integer()) :: any()
      def my_fun_other(t, a)
    end

    defimpl MyProto, for: List do
      
    end
    """

    list =
      Suggestion.suggestions(buffer, 12, 3)
      |> Enum.filter(fn s -> s.type == :protocol_function end)

    assert [
             %{
               args: "t()",
               args_list: ["t()"],
               arity: 1,
               metadata: %{since: "1.2.3"},
               name: "my_fun",
               origin: "MyProto",
               spec: "@callback my_fun(t()) :: term()",
               summary: "Some callback",
               type: :protocol_function
             },
             %{
               args: "t(), integer()",
               args_list: ["t()", "integer()"],
               arity: 2,
               metadata: %{deprecated: "1.2.3"},
               name: "my_fun_other",
               origin: "MyProto",
               spec: "@spec my_fun_other(t(), integer()) :: any()",
               summary: "",
               type: :protocol_function
             }
           ] = list
  end

  test "lists callbacks + def macros after de" do
    buffer = """
    defmodule MyServer do
      use GenServer

      de
      # ^
    end
    """

    list = Suggestion.suggestions(buffer, 4, 5)
    assert Enum.any?(list, fn s -> s.type == :callback end)
    assert Enum.any?(list, fn s -> s.type == :macro end)
    assert Enum.all?(list, fn s -> s.type in [:callback, :macro] end)
  end

  test "lists callbacks + def macros after def" do
    buffer = """
    defmodule MyServer do
      use GenServer

      def
      #  ^
    end
    """

    list = Suggestion.suggestions(buffer, 4, 6)
    assert Enum.any?(list, fn s -> s.type == :callback end)
    assert Enum.any?(list, fn s -> s.type == :macro end)
    assert Enum.all?(list, fn s -> s.type in [:callback, :macro] end)
  end

  test "lists only callbacks after def + space" do
    buffer = """
    defmodule MyServer do
      use GenServer

      def t
      #   ^
    end
    """

    assert Suggestion.suggestions(buffer, 4, 7) |> Enum.all?(fn s -> s.type == :callback end)

    buffer = """
    defmodule MyServer do
      use GenServer

      def t
      #    ^
    end
    """

    assert [%{name: "terminate", type: :callback}] = Suggestion.suggestions(buffer, 4, 8)
  end

  test "do not list callbacks inside functions" do
    buffer = """
    defmodule MyServer do
      use GenServer

      def init(_) do
        t
      #  ^
      end
    end
    """

    list = Suggestion.suggestions(buffer, 5, 6)
    assert Enum.any?(list, fn s -> s.type == :function end)
    refute Enum.any?(list, fn s -> s.type == :callback end)
  end

  test "lists macrocallbacks" do
    buffer = """
    defmodule MyServer do
      @behaviour ElixirSenseExample.BehaviourWithMacrocallback

    end
    """

    list =
      Suggestion.suggestions(buffer, 3, 7)
      |> Enum.filter(fn s -> s.type == :callback end)

    assert [
             %{
               args: "a",
               args_list: ["a"],
               arity: 1,
               name: "optional",
               subtype: :macrocallback,
               origin: "ElixirSenseExample.BehaviourWithMacrocallback",
               spec: "@macrocallback optional(a) :: Macro.t() when a: atom()",
               summary: "An optional macrocallback\n",
               type: :callback,
               metadata: %{optional: true, app: :language_server}
             },
             %{
               args: "atom",
               args_list: ["atom"],
               arity: 1,
               name: "required",
               subtype: :macrocallback,
               origin: "ElixirSenseExample.BehaviourWithMacrocallback",
               spec: "@macrocallback required(atom()) :: Macro.t()",
               summary: "A required macrocallback\n",
               type: :callback,
               metadata: %{optional: false, app: :language_server}
             }
           ] == list
  end

  test "lists macrocallbacks + def macros after defma" do
    buffer = """
    defmodule MyServer do
      @behaviour ElixirSenseExample.BehaviourWithMacrocallback

      defma
      #    ^
    end
    """

    list = Suggestion.suggestions(buffer, 4, 8)
    assert Enum.any?(list, fn s -> s.type == :callback end)
    assert Enum.any?(list, fn s -> s.type == :macro end)
    assert Enum.all?(list, fn s -> s.type in [:callback, :macro] end)
  end

  test "lists erlang callbacks" do
    buffer = """
    defmodule MyServer do
      @behaviour :gen_statem

    end
    """

    list =
      Suggestion.suggestions(buffer, 3, 7)
      |> Enum.filter(fn s -> s.type == :callback && s.name == "code_change" end)

    assert [
             %{
               args: "oldVsn, oldState, oldData, extra",
               arity: 4,
               name: "code_change",
               origin: ":gen_statem",
               spec: "@callback code_change" <> _,
               summary: summary,
               type: :callback,
               subtype: :callback
             }
           ] = list

    if System.otp_release() |> String.to_integer() >= 23 do
      if System.otp_release() |> String.to_integer() >= 27 do
        assert "Update the [state]" <> _ = summary
      else
        assert "- OldVsn = Vsn" <> _ = summary
      end
    end
  end

  test "callback suggestions should not crash with unquote(__MODULE__)" do
    buffer = """
    defmodule Dummy do
      @doc false
      defmacro __using__() do
        quote location: :keep do
          @behaviour unquote(__MODULE__)
        end
      end
    end
    """

    assert [%{} | _] = Suggestion.suggestions(buffer, 8, 5)
  end

  test "lists overridable callbacks" do
    buffer = """
    defmodule MyServer do
      use ElixirSenseExample.OverridableImplementation

    end
    """

    list =
      Suggestion.suggestions(buffer, 3, 7)
      |> Enum.filter(fn s -> s.type == :callback end)

    assert [
             %{
               args: "",
               arity: 0,
               name: "foo",
               origin: "ElixirSenseExample.OverridableBehaviour",
               spec: "@callback foo() :: any()",
               summary: "",
               type: :callback,
               subtype: :callback,
               metadata: %{optional: false, overridable: true}
             },
             %{
               args: "any",
               arity: 1,
               metadata: %{optional: false, overridable: true},
               name: "bar",
               origin: "ElixirSenseExample.OverridableBehaviour",
               spec: "@macrocallback bar(any()) :: Macro.t()",
               subtype: :macrocallback,
               summary: "",
               type: :callback
             }
           ] = list
  end

  test "lists overridable functions and macros" do
    buffer = """
    defmodule MyServer do
      use ElixirSenseExample.OverridableFunctions

    end
    """

    list =
      Suggestion.suggestions(buffer, 3, 7)
      |> Enum.filter(fn s -> s.type == :callback end)

    assert [
             %{
               args: "var",
               arity: 1,
               metadata: %{overridable: true},
               name: "required",
               origin: "ElixirSenseExample.OverridableFunctions",
               spec: "",
               summary: "",
               type: :callback,
               subtype: :macrocallback
             },
             %{
               args: "x, y",
               arity: 2,
               metadata: %{since: "1.2.3", overridable: true},
               name: "test",
               origin: "ElixirSenseExample.OverridableFunctions",
               spec: "@spec test(number(), number()) :: number()",
               summary: "Some overridable",
               type: :callback,
               subtype: :callback
             }
           ] = list
  end

  test "fuzzy match overridable functions" do
    buffer = """
    defmodule MyServer do
      use ElixirSenseExample.OverridableFunctions

      rqui
    end
    """

    list =
      Suggestion.suggestions(buffer, 4, 5)
      |> Enum.filter(fn s -> s.type == :callback end)

    assert [
             %{
               args: "var",
               arity: 1,
               metadata: %{},
               name: "required",
               origin: "ElixirSenseExample.OverridableFunctions",
               spec: "",
               summary: "",
               type: :callback,
               subtype: :macrocallback
             }
           ] = list
  end

  test "lists protocol functions" do
    buffer = """
    defimpl Enumerable, for: MyStruct do

    end
    """

    list =
      Suggestion.suggestions(buffer, 2, 3)
      |> Enum.filter(fn s -> s[:name] == "reduce" end)

    assert [
             %{
               args: "enumerable, acc, fun",
               arity: 3,
               name: "reduce",
               origin: "Enumerable",
               spec: "@callback reduce(t(), acc(), reducer()) :: result()",
               summary: "Reduces the `enumerable` into an element.",
               type: :protocol_function,
               metadata: %{}
             }
           ] = list
  end

  test "lists fuzzy protocol functions" do
    buffer = """
    defimpl Enumerable, for: MyStruct do
      reu
    end
    """

    list =
      Suggestion.suggestions(buffer, 2, 5)
      |> Enum.filter(fn s -> s[:type] == :protocol_function end)

    assert [
             %{
               args: "enumerable, acc, fun",
               arity: 3,
               name: "reduce",
               origin: "Enumerable",
               spec: "@callback reduce(t(), acc(), reducer()) :: result()",
               summary: "Reduces the `enumerable` into an element.",
               type: :protocol_function,
               metadata: %{}
             }
           ] = list
  end

  test "lists callback return values" do
    buffer = """
    defmodule MyServer do
      use ElixirSenseExample.ExampleBehaviour

      def handle_call(request, from, state) do

      end
    end
    """

    list =
      Suggestion.suggestions(buffer, 5, 5)
      |> Enum.filter(fn s -> s.type == :return end)

    assert [
             %{
               description: "{:reply, reply, new_state}",
               snippet: "{:reply, \"${1:reply}$\", \"${2:new_state}$\"}",
               spec:
                 "{:reply, reply, new_state} when reply: term(), new_state: term(), reason: term()",
               type: :return
             },
             %{
               description:
                 "{:reply, reply, new_state, timeout() | :hibernate | {:continue, term()}}",
               snippet:
                 "{:reply, \"${1:reply}$\", \"${2:new_state}$\", \"${3:timeout() | :hibernate | {:continue, term()}}$\"}",
               spec:
                 "{:reply, reply, new_state, timeout() | :hibernate | {:continue, term()}}" <> _,
               type: :return
             },
             %{
               description: "{:noreply, new_state}",
               snippet: "{:noreply, \"${1:new_state}$\"}",
               spec:
                 "{:noreply, new_state} when reply: term(), new_state: term(), reason: term()",
               type: :return
             },
             %{
               description: "{:noreply, new_state, timeout() | :hibernate | {:continue, term()}}",
               snippet:
                 "{:noreply, \"${1:new_state}$\", \"${2:timeout() | :hibernate | {:continue, term()}}$\"}",
               spec: "{:noreply, new_state, timeout() | :hibernate | {:continue, term()}}" <> _,
               type: :return
             },
             %{
               description: "{:stop, reason, reply, new_state}",
               snippet: "{:stop, \"${1:reason}$\", \"${2:reply}$\", \"${3:new_state}$\"}",
               spec:
                 "{:stop, reason, reply, new_state} when reply: term(), new_state: term(), reason: term()",
               type: :return
             },
             %{
               description: "{:stop, reason, new_state}",
               snippet: "{:stop, \"${1:reason}$\", \"${2:new_state}$\"}",
               spec:
                 "{:stop, reason, new_state} when reply: term(), new_state: term(), reason: term()",
               type: :return
             }
           ] = list
  end

  test "lists macrocallback return values" do
    buffer = """
    defmodule MyServer do
      @behaviour ElixirSenseExample.BehaviourWithMacrocallback

      defmacro required(arg) do

      end
    end
    """

    list =
      Suggestion.suggestions(buffer, 5, 5)
      |> Enum.filter(fn s -> s.type == :return end)

    assert list == [
             %{
               description: "Macro.t()",
               snippet: "\"${1:Macro.t()}$\"",
               spec: "Macro.t()",
               type: :return
             }
           ]
  end

  test "lists metadata callback return values" do
    buffer = """
    defmodule MyBehaviour do
      @callback required(term()) :: {:ok, term()} | :error
    end

    defmodule MyServer do
      @behaviour MyBehaviour

      def required(arg) do

      end
    end
    """

    list =
      Suggestion.suggestions(buffer, 9, 5)
      |> Enum.filter(fn s -> s.type == :return end)

    assert list == [
             %{
               description: "{:ok, term()}",
               snippet: "{:ok, \"${1:term()}$\"}",
               spec: "{:ok, term()}",
               type: :return
             },
             %{description: ":error", snippet: ":error", spec: ":error", type: :return}
           ]
  end

  test "lists protocol implementation return values" do
    buffer = """
    defimpl Enumerable, for: MyStruct do
      def count(t) do

      end
    end
    """

    list =
      Suggestion.suggestions(buffer, 3, 6)
      |> Enum.filter(fn s -> s.type == :return end)

    assert [
             %{
               description: "{:ok, non_neg_integer()}",
               snippet: "{:ok, \"${1:non_neg_integer()}$\"}",
               spec: "{:ok, non_neg_integer()}",
               type: :return
             },
             %{
               description: "{:error, module()}",
               snippet: "{:error, \"${1:module()}$\"}",
               spec: "{:error, module()}",
               type: :return
             }
           ] == list
  end

  test "lists metadata protocol implementation return values" do
    buffer = """
    defprotocol MyProto do
      @spec count(t()) :: {:ok, term()} | :error
      def count(t)
    end

    defimpl MyProto, for: MyStruct do
      def count(t) do

      end
    end
    """

    list =
      Suggestion.suggestions(buffer, 8, 6)
      |> Enum.filter(fn s -> s.type == :return end)

    assert [
             %{
               description: "{:ok, term()}",
               snippet: "{:ok, \"${1:term()}$\"}",
               spec: "{:ok, term()}",
               type: :return
             },
             %{description: ":error", snippet: ":error", spec: ":error", type: :return}
           ] == list
  end

  test "lists function with spec return values" do
    buffer = """
    defmodule SomeModule do
      @spec count(atom) :: :ok | {:error, any}
      def count(t) do

      end
    end
    """

    list =
      Suggestion.suggestions(buffer, 4, 6)
      |> Enum.filter(fn s -> s.type == :return end)

    assert [
             %{description: ":ok", snippet: ":ok", spec: ":ok", type: :return},
             %{
               description: "{:error, any()}",
               snippet: "{:error, \"${1:any()}$\"}",
               spec: "{:error, any()}",
               type: :return
             }
           ] == list
  end

  test "list metadata function - fallback to callback in metadata" do
    buffer = """
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
        MyLocalModule.flat
      end
    end
    """

    list =
      Suggestion.suggestions(buffer, 18, 23)
      |> Enum.filter(fn s -> s.type == :function end)

    assert [
             %{
               args: "list",
               arity: 1,
               def_arity: 1,
               metadata: %{implementing: MyBehaviour, hidden: true, since: "1.2.3"},
               name: "flatten",
               origin: "MyLocalModule",
               spec: "@callback flatten(list()) :: list()",
               summary: "Sample doc",
               type: :function,
               visibility: :public
             }
           ] = list
  end

  test "retrieve metadata function documentation - fallback to protocol function in metadata" do
    buffer = """
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

    list =
      Suggestion.suggestions(buffer, 13, 16)
      |> Enum.filter(fn s -> s.type == :function end)

    assert [
             %{
               args: "t",
               arity: 1,
               def_arity: 1,
               metadata: %{implementing: BB},
               name: "go",
               origin: "BB.String",
               spec: "@callback go(t()) :: integer()",
               summary: "asdf",
               type: :function,
               visibility: :public
             }
           ] = list
  end

  test "list metadata macro - fallback to macrocallback in metadata" do
    buffer = """
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

    list =
      Suggestion.suggestions(buffer, 19, 23)
      |> Enum.filter(fn s -> s.type == :macro end)

    assert [
             %{
               args: "list",
               arity: 1,
               def_arity: 1,
               metadata: %{implementing: MyBehaviour, hidden: true, since: "1.2.3"},
               name: "flatten",
               origin: "MyLocalModule",
               spec: "@macrocallback flatten(list()) :: list()",
               summary: "Sample doc",
               type: :macro,
               visibility: :public
             }
           ] = list
  end

  test "list metadata function - fallback to callback" do
    buffer = """
    defmodule MyLocalModule do
      @behaviour ElixirSenseExample.BehaviourWithMeta

      @impl true
      def flatten(list) do
        []
      end
    end

    defmodule MyModule do
      def func(list) do
        MyLocalModule.flat
      end
    end
    """

    list =
      Suggestion.suggestions(buffer, 12, 23)
      |> Enum.filter(fn s -> s.type == :function end)

    assert [
             %{
               args: "list",
               arity: 1,
               def_arity: 1,
               metadata: %{implementing: ElixirSenseExample.BehaviourWithMeta},
               name: "flatten",
               origin: "MyLocalModule",
               spec: "@callback flatten(list()) :: list()",
               summary: "Sample doc",
               type: :function,
               visibility: :public
             }
           ] = list
  end

  test "list metadata function - fallback to erlang callback" do
    buffer = """
    defmodule MyLocalModule do
      @behaviour :gen_statem

      @impl true
      def init(list) do
        []
      end
    end

    defmodule MyModule do
      def func(list) do
        MyLocalModule.ini
      end
    end
    """

    list =
      Suggestion.suggestions(buffer, 12, 22)
      |> Enum.filter(fn s -> s.type == :function end)

    if System.otp_release() |> String.to_integer() >= 23 do
      assert [
               %{
                 args: "list",
                 arity: 1,
                 def_arity: 1,
                 metadata: %{implementing: :gen_statem, since: "OTP 19.0"},
                 name: "init",
                 origin: "MyLocalModule",
                 spec: "@callback init(args :: term()) ::" <> _,
                 summary: documentation,
                 type: :function,
                 visibility: :public
               }
             ] = list

      if System.otp_release() |> String.to_integer() >= 27 do
        assert "Initialize the state machine" <> _ = documentation
      else
        assert "- Args = " <> _ = documentation
      end
    end
  end

  test "list metadata macro - fallback to macrocallback" do
    buffer = """
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
        MyLocalModule.ba
      end
    end
    """

    list =
      Suggestion.suggestions(buffer, 13, 21)
      |> Enum.filter(fn s -> s.type == :macro end)

    assert [
             %{
               args: "list",
               arity: 1,
               def_arity: 1,
               metadata: %{implementing: ElixirSenseExample.BehaviourWithMeta},
               name: "bar",
               origin: "MyLocalModule",
               spec: "@macrocallback bar(integer()) :: Macro.t()",
               summary: "Docs for bar",
               type: :macro,
               visibility: :public
             }
           ] = list
  end

  test "lists callbacks in function suggestion - elixir behaviour" do
    buffer = """
    defmodule MyServer do
      use GenServer

      def handle_call(request, _from, state) do
        term
      end

      def init(arg), do: arg

      def handle_cast(arg, _state) when is_atom(arg) do
        :ok
      end
    end
    """

    list =
      Suggestion.suggestions(buffer, 5, 9)
      |> Enum.filter(fn s -> s.type == :function end)

    assert [
             %{
               args: "_reason, _state",
               arity: 2,
               def_arity: 2,
               metadata: %{implementing: GenServer},
               name: "terminate",
               origin: "MyServer",
               spec: "@callback terminate(reason, state :: term()) :: term()" <> _,
               summary:
                 "Invoked when the server is about to exit. It should do any cleanup required.",
               type: :function,
               visibility: :public
             }
           ] = list
  end

  test "lists callbacks in function suggestion - erlang behaviour" do
    buffer = """
    defmodule MyServer do
      @behaviour :gen_event

      def handle_call(request, _from, state) do
        ini
      end

      def init(arg), do: arg

      def handle_cast(arg, _state) when is_atom(arg) do
        :ok
      end
    end
    """

    list =
      Suggestion.suggestions(buffer, 5, 8)
      |> Enum.filter(fn s -> s.type == :function end)

    assert [
             %{name: "init", origin: "MyServer", arity: 1} = init_res,
             %{name: "is_function", origin: "Kernel", arity: 1},
             %{name: "is_function", origin: "Kernel", arity: 2}
           ] = list

    if System.otp_release() |> String.to_integer() >= 23 do
      assert %{
               summary: documentation,
               metadata: %{implementing: :gen_event},
               spec: "@callback init(initArgs :: term()) ::" <> _,
               args_list: ["arg"]
             } = init_res

      if System.otp_release() |> String.to_integer() >= 27 do
        assert "Initialize the event handler" <> _ = documentation
      else
        assert "- InitArgs = Args" <> _ = documentation
      end
    end
  end

  test "lists fuzzy callbacks in function suggestion - erlang behaviour" do
    buffer = """
    defmodule MyServer do
      @behaviour :gen_server

      def handle_call(request, _from, state) do
        iit
      end

      def init(arg), do: arg

      def handle_cast(arg, _state) when is_atom(arg) do
        :ok
      end
    end
    """

    list =
      Suggestion.suggestions(buffer, 5, 8)
      |> Enum.filter(fn s -> s.type == :function end)

    assert [
             %{name: "init", origin: "MyServer", arity: 1},
             %{name: "is_bitstring", origin: "Kernel", arity: 1},
             %{name: "is_integer", origin: "Kernel", arity: 1},
             %{name: "is_list", origin: "Kernel", arity: 1}
           ] = list
  end

  test "suggest elixir behaviour callbacks on implementation" do
    buffer = """
    ElixirSenseExample.ExampleBehaviourWithDocCallbackImpl.ba
    """

    list =
      Suggestion.suggestions(buffer, 1, 57)
      |> Enum.filter(fn s -> s.type == :function end)

    assert [
             %{
               args: "a",
               args_list: ["a"],
               arity: 1,
               def_arity: 1,
               metadata: %{implementing: ElixirSenseExample.ExampleBehaviourWithDoc},
               name: "baz",
               origin: "ElixirSenseExample.ExampleBehaviourWithDocCallbackImpl",
               snippet: nil,
               spec: "@callback baz(integer()) :: :ok",
               summary: "Docs for baz",
               type: :function,
               visibility: :public
             }
           ] = list
  end

  test "suggest erlang behaviour callbacks on implementation" do
    buffer = """
    ElixirSenseExample.ExampleBehaviourWithDocCallbackErlang.ini
    """

    list =
      Suggestion.suggestions(buffer, 1, 60)
      |> Enum.filter(fn s -> s.type == :function end)

    if System.otp_release() |> String.to_integer() >= 23 do
      assert [
               %{
                 args: "_",
                 args_list: ["_"],
                 arity: 1,
                 def_arity: 1,
                 metadata: %{implementing: :gen_statem},
                 name: "init",
                 origin: "ElixirSenseExample.ExampleBehaviourWithDocCallbackErlang",
                 snippet: nil,
                 spec: "@callback init(args :: term()) :: init_result(state())",
                 summary: documentation,
                 type: :function,
                 visibility: :public
               }
             ] = list

      if System.otp_release() |> String.to_integer() >= 27 do
        assert "Initialize the state machine" <> _ = documentation
      else
        assert "- Args = " <> _ = documentation
      end
    end
  end

  if System.otp_release() |> String.to_integer() >= 25 do
    test "suggest erlang behaviour callbacks on erlang implementation" do
      buffer = """
      :file_server.ini
      """

      list =
        Suggestion.suggestions(buffer, 1, 17)
        |> Enum.filter(fn s -> s.type == :function end)

      assert [
               %{
                 args: "args",
                 args_list: ["args"],
                 arity: 1,
                 def_arity: 1,
                 metadata: %{implementing: :gen_server},
                 name: "init",
                 origin: ":file_server",
                 snippet: nil,
                 spec: "@callback init(args :: term()) ::" <> _,
                 summary: documentation,
                 type: :function,
                 visibility: :public
               }
             ] = list

      if System.otp_release() |> String.to_integer() >= 27 do
        assert "Initialize the server" <> _ = documentation
      else
        assert "- Args = " <> _ = documentation
      end
    end
  end

  test "lists params and vars" do
    buffer = """
    defmodule MyServer do
      use GenServer

      def handle_call(request, _from, state) do
        var1 = true

      end

      def init(arg), do: arg

      def handle_cast(arg, _state) when is_atom(arg) do
        :ok
      end
    end
    """

    list =
      Suggestion.suggestions(buffer, 6, 5)
      |> Enum.filter(fn s -> s.type == :variable end)

    assert list == [
             %{name: "_from", type: :variable},
             %{name: "request", type: :variable},
             %{name: "state", type: :variable},
             %{name: "var1", type: :variable}
           ]

    list =
      Suggestion.suggestions(buffer, 9, 22)
      |> Enum.filter(fn s -> s.type == :variable end)

    assert list == [
             %{name: "arg", type: :variable}
           ]

    list =
      Suggestion.suggestions(buffer, 11, 45)
      |> Enum.filter(fn s -> s.type == :variable end)

    assert list == [
             %{name: "_state", type: :variable},
             %{name: "arg", type: :variable}
           ]
  end

  test "lists params in fn's" do
    buffer = """
    defmodule MyServer do
      my = fn arg -> arg + 1 end
    end
    """

    list =
      Suggestion.suggestions(buffer, 2, 19)
      |> Enum.filter(fn s -> s.type == :variable end)

    assert list == [
             %{name: "arg", type: :variable}
           ]
  end

  test "lists params in protocol implementations" do
    buffer = """
    defimpl Enum, for: [MyStruct, MyOtherStruct] do
      def count(term), do:
    end
    """

    list =
      Suggestion.suggestions(buffer, 2, 24)
      |> Enum.filter(fn s -> s.type == :variable end)

    assert list == [
             %{name: "term", type: :variable}
           ]
  end

  test "lists vars in []" do
    buffer = """
    defmodule MyServer do
      my = %{}
      x = 4
      my[]

    end
    """

    list =
      Suggestion.suggestions(buffer, 4, 6)
      |> Enum.filter(fn s -> s.type == :variable end)

    assert list == [
             %{name: "my", type: :variable},
             %{name: "x", type: :variable}
           ]
  end

  test "lists vars in unfinished []" do
    buffer = """
    defmodule MyServer do
      my = %{}
      x = 4
      my[

    end
    """

    list =
      Suggestion.suggestions(buffer, 4, 6)
      |> Enum.filter(fn s -> s.type == :variable end)

    assert list == [
             %{name: "my", type: :variable},
             %{name: "x", type: :variable}
           ]
  end

  test "lists vars in string interpolation" do
    buffer = """
    defmodule MyServer do
      x = 4
      "abc\#{}"

    end
    """

    list =
      Suggestion.suggestions(buffer, 3, 9)
      |> Enum.filter(fn s -> s.type == :variable end)

    assert list == [
             %{name: "x", type: :variable}
           ]
  end

  test "lists vars in unfinished string interpolation" do
    buffer = """
    defmodule MyServer do
      x = 4
      "abc\#{

    end
    """

    list =
      Suggestion.suggestions(buffer, 3, 9)
      |> Enum.filter(fn s -> s.type == :variable end)

    assert list == [
             %{name: "x", type: :variable}
           ]

    buffer = """
    defmodule MyServer do
      x = 4
      "abc\#{"

    end
    """

    list =
      Suggestion.suggestions(buffer, 3, 9)
      |> Enum.filter(fn s -> s.type == :variable end)

    assert list == [
             %{name: "x", type: :variable}
           ]

    buffer = """
    defmodule MyServer do
      x = 4
      "abc\#{}

    end
    """

    list =
      Suggestion.suggestions(buffer, 3, 9)
      |> Enum.filter(fn s -> s.type == :variable end)

    assert list == [
             %{name: "x", type: :variable}
           ]

    buffer = """
    defmodule MyServer do
      x = 4
      "abc\#{x[

    end
    """

    list =
      Suggestion.suggestions(buffer, 3, 9)
      |> Enum.filter(fn s -> s.type == :variable end)

    assert list == [
             %{name: "x", type: :variable}
           ]
  end

  test "lists vars in heredoc interpolation" do
    buffer = """
    defmodule MyServer do
      x = 4
      \"\"\"
      abc\#{}
      \"\"\"

    end
    """

    list =
      Suggestion.suggestions(buffer, 4, 8)
      |> Enum.filter(fn s -> s.type == :variable end)

    assert list == [
             %{name: "x", type: :variable}
           ]
  end

  test "lists vars in unfinished heredoc interpolation" do
    buffer = """
    defmodule MyServer do
      x = 4
      \"\"\"
      abc\#{
      \"\"\"

    end
    """

    list =
      Suggestion.suggestions(buffer, 4, 8)
      |> Enum.filter(fn s -> s.type == :variable end)

    assert list == [
             %{name: "x", type: :variable}
           ]

    buffer = """
    defmodule MyServer do
      x = 4
      \"\"\"
      abc\#{

    end
    """

    list =
      Suggestion.suggestions(buffer, 4, 8)
      |> Enum.filter(fn s -> s.type == :variable end)

    assert list == [
             %{name: "x", type: :variable}
           ]

    buffer = """
    defmodule MyServer do
      x = 4
      \"\"\"
      abc\#{}

    end
    """

    list =
      Suggestion.suggestions(buffer, 4, 8)
      |> Enum.filter(fn s -> s.type == :variable end)

    assert list == [
             %{name: "x", type: :variable}
           ]
  end

  if Version.match?(System.version(), ">= 1.17.0") do
    test "lists params in fn's not finished multiline" do
      buffer = """
      defmodule MyServer do
        my = fn arg ->

      end
      """

      assert capture_io(:stderr, fn ->
               list =
                 Suggestion.suggestions(buffer, 3, 5)
                 |> Enum.filter(fn s -> s.type == :variable end)

               send(self(), {:result, list})
             end) =~ "an expression is always required on the right side of ->"

      assert_received {:result, list}

      assert list == [%{name: "arg", type: :variable}]
    end
  end

  if Version.match?(System.version(), ">= 1.17.0") do
    test "lists params in fn's not finished" do
      buffer = """
      defmodule MyServer do
        my = fn arg ->
      end
      """

      assert capture_io(:stderr, fn ->
               list =
                 Suggestion.suggestions(buffer, 2, 19)
                 |> Enum.filter(fn s -> s.type == :variable end)

               send(self(), {:result, list})
             end) =~ "an expression is always required on the right side of ->"

      assert_received {:result, list}

      assert list == [
               %{name: "arg", type: :variable}
             ]
    end
  end

  test "lists params in defs not finished" do
    buffer = """
    defmodule MyServer do
      def my(arg), do:
    end
    """

    list =
      Suggestion.suggestions(buffer, 2, 20)
      |> Enum.filter(fn s -> s.type == :variable end)

    assert list == [
             %{name: "arg", type: :variable}
           ]
  end

  test "lists params and vars in case clauses" do
    buffer = """
    defmodule MyServer do
      def fun(request) do
        case request do
          {:atom1, vara} ->
            :ok
          {:atom2, varb} -> :ok
          abc when is_atom(a)
        end

      end
    end
    """

    list =
      Suggestion.suggestions(buffer, 5, 9)
      |> Enum.filter(fn s -> s.type == :variable end)

    assert list == [
             %{name: "request", type: :variable},
             %{name: "vara", type: :variable}
           ]

    list =
      Suggestion.suggestions(buffer, 6, 25)
      |> Enum.filter(fn s -> s.type == :variable end)

    assert list == [
             %{name: "request", type: :variable},
             %{name: "varb", type: :variable}
           ]

    list =
      Suggestion.suggestions(buffer, 9, 4)
      |> Enum.filter(fn s -> s.type == :variable end)

    assert list == [
             %{name: "request", type: :variable}
           ]

    list =
      Suggestion.suggestions(buffer, 7, 25)
      |> Enum.filter(fn s -> s.type == :variable end)

    assert list == [
             %{name: "abc", type: :variable}
           ]
  end

  test "lists write vars in match context" do
    buffer = """
    defmodule MyServer do
      def my(arg = 1, a), do: :ok
    end
    """

    list =
      Suggestion.suggestions(buffer, 2, 20)
      |> Enum.filter(fn s -> s.type == :variable end)

    assert list == [
             %{name: "arg", type: :variable}
           ]
  end

  test "does not list write vars" do
    buffer = """
    defmodule MyServer do
      [arg = 1, a]
      a
    end
    """

    list =
      Suggestion.suggestions(buffer, 2, 14)
      |> Enum.filter(fn s -> s.type == :variable end)

    # arg is a write var and is not available for read in the cursor context
    assert list == []

    list =
      Suggestion.suggestions(buffer, 3, 4)
      |> Enum.filter(fn s -> s.type == :variable end)

    # arg is a read var here
    assert list == [%{name: "arg", type: :variable}]
  end

  test "lists params and vars in cond clauses" do
    buffer = """
    defmodule MyServer do
      def fun(request) do
        cond do
          vara = Enum.find(request, 4) ->
            :ok
          varb = Enum.find(request, 5) -> :ok
          true -> :error
        end

      end
    end
    """

    list =
      Suggestion.suggestions(buffer, 5, 9)
      |> Enum.filter(fn s -> s.type == :variable end)

    assert list == [
             %{name: "request", type: :variable},
             %{name: "vara", type: :variable}
           ]

    list =
      Suggestion.suggestions(buffer, 6, 39)
      |> Enum.filter(fn s -> s.type == :variable end)

    assert list == [
             %{name: "request", type: :variable},
             %{name: "varb", type: :variable}
           ]

    list =
      Suggestion.suggestions(buffer, 9, 4)
      |> Enum.filter(fn s -> s.type == :variable end)

    assert list == [
             %{name: "request", type: :variable}
           ]
  end

  test "only list defined params in guard" do
    buffer = """
    defmodule MyServer do
      def new(my_var) when is_integer(my
    end
    """

    list =
      Suggestion.suggestions(buffer, 2, 37)
      |> Enum.filter(fn s -> s.type in [:variable] end)

    assert list == [%{name: "my_var", type: :variable}]
  end

  if Version.match?(System.version(), ">= 1.15.0") do
    test "list vars in multiline struct" do
      buffer = """
      defmodule MyServer do
        def go do
          %Some{
            filed: my_var,
            other: my
          } = abc()
        end
      end
      """

      list =
        Suggestion.suggestions(buffer, 5, 16)
        |> Enum.filter(fn s -> s.type in [:variable] end)

      assert list == [%{name: "my_var", type: :variable}]
    end
  end

  test "tuple destructuring" do
    buffer = """
    defmodule MyServer do
      def new() do
        case NaiveDateTime.new(1, 2) do
          {:ok, x} -> x.h
        end
        case NaiveDateTime.new(1, 2) do
          {:ok, x} -> %{x | h}
        end
      end
    end
    """

    list =
      Suggestion.suggestions(buffer, 4, 22)
      |> Enum.filter(fn s -> s.type == :field end)

    assert [%{name: "hour", origin: "NaiveDateTime"}] = list

    list =
      Suggestion.suggestions(buffer, 7, 26)
      |> Enum.filter(fn s -> s.type == :field end)

    assert [%{name: "hour", origin: "NaiveDateTime"}] = list
  end

  test "nested binding" do
    buffer = """
    defmodule State do
      defstruct [formatted: nil]
      def new(socket) do
        %State{formatted: formatted} = state = socket.assigns.state
        state.for
        state = %{state | form}
      end
    end
    """

    list =
      Suggestion.suggestions(buffer, 5, 14)
      |> Enum.filter(fn s -> s.type == :field end)

    assert [%{name: "formatted", origin: "State"}] = list

    list =
      Suggestion.suggestions(buffer, 6, 27)
      |> Enum.filter(fn s -> s.type == :field end)

    assert [%{name: "formatted", origin: "State"}] = list
  end

  test "variable shadowing function" do
    buffer = """
    defmodule Mod do
      def my_fun(), do: :ok
      def some() do
        my_fun = 1
        my_f
      end
    end
    """

    assert [
             %{name: "my_fun", type: :variable},
             %{name: "my_fun", type: :function}
           ] = Suggestion.suggestions(buffer, 5, 9)
  end

  describe "suggestions for module attributes" do
    test "lists attributes" do
      buffer = """
      defmodule MyModule do
        @my_attribute1 true
        @my_attribute2 false
        @
      end
      """

      list =
        Suggestion.suggestions(buffer, 4, 4)
        |> Enum.filter(fn s -> s.type == :attribute and s.name |> String.starts_with?("@my") end)
        |> Enum.map(fn %{name: name} -> name end)

      assert list == ["@my_attribute1", "@my_attribute2"]
    end

    test "lists module attributes in module scope" do
      buffer = """
      defmodule MyModule do
        @myattr "asd"
        @moduledoc "asdf"
        def some do
          @m
        end
      end
      """

      list =
        Suggestion.suggestions(buffer, 3, 5)
        |> Enum.filter(fn s -> s.type == :attribute end)
        |> Enum.map(fn %{name: name} -> name end)

      if Version.match?(System.version(), ">= 1.15.0") do
        assert list == ["@macrocallback", "@moduledoc", "@myattr"]
      else
        assert list == ["@macrocallback", "@moduledoc"]
      end

      list =
        Suggestion.suggestions(buffer, 5, 7)
        |> Enum.filter(fn s -> s.type == :attribute end)
        |> Enum.map(fn %{name: name} -> name end)

      assert list == ["@myattr"]
    end

    test "built-in attributes should include documentation" do
      buffer = """
      defmodule MyModule do
        @call
        @enfor
      end
      """

      list =
        Suggestion.suggestions(buffer, 2, 7)
        |> Enum.filter(fn s -> s.type == :attribute end)

      assert [%{summary: "Provides a specification for a behaviour callback."}] = list

      list =
        Suggestion.suggestions(buffer, 3, 8)
        |> Enum.filter(fn s -> s.type == :attribute end)

      assert [
               %{
                 summary:
                   "Ensures the given keys are always set when building the struct defined in the current module."
               }
             ] = list
    end

    test "non built-in attributes should not include documentation" do
      buffer = """
      defmodule MyModule do
        @myattr "asd"
        def some do
          @m
        end
      end
      """

      list =
        Suggestion.suggestions(buffer, 4, 6)
        |> Enum.filter(fn s -> s.type == :attribute end)

      assert [%{summary: nil}] = list
    end
  end

  test "lists builtin module attributes on incomplete code" do
    buffer = """
    defmodule My do
      def start_link(id) do
        GenServer.start_link(__MODULE__, id, name: via_tuple(id))
      end

      @
      def init(id) do
        {:ok,
          %Some.Mod{
            id: id,
            events: [],
            version: 0
          }}
      end
    end
    """

    list =
      Suggestion.suggestions(buffer, 6, 4)
      |> Enum.filter(fn s -> s.type == :attribute end)

    assert Enum.any?(list, &(&1.name == "@impl"))
    assert Enum.any?(list, &(&1.name == "@spec"))
  end

  test "do not suggest @@" do
    buffer = """
    defmodule MyModule do
      @
      @my_attribute1 true
    end
    """

    list =
      Suggestion.suggestions(buffer, 2, 4)
      |> Enum.filter(fn s -> s.type == :attribute end)
      |> Enum.map(fn %{name: name} -> name end)

    refute "@@" in list
  end

  test "lists doc snippets in module body" do
    buffer = """
    defmodule MyModule do
      @
      #^

      @m
      # ^

      def some do
        @m
        # ^
      end
    end
    """

    [cursor_1, cursor_2, cursor_3] = cursors(buffer)

    list = suggestions_by_kind(buffer, cursor_1, :snippet)

    assert [
             %{label: ~s(@doc """"""), detail: detail, documentation: doc},
             %{label: ~s(@moduledoc """""")},
             %{label: ~s(@typedoc """""")},
             %{label: "@doc false"},
             %{label: "@moduledoc false"},
             %{label: "@typedoc false"}
           ] = list

    assert detail == "module attribute snippet"
    assert doc == "Documents a function/macro/callback"

    list = suggestions_by_kind(buffer, cursor_2, :snippet)
    assert [%{label: ~S(@moduledoc """""")}, %{label: "@moduledoc false"}] = list

    assert suggestions_by_kind(buffer, cursor_3, :snippet) == []
  end

  test "fuzzy suggestions for doc snippets" do
    buffer = """
    defmodule MyModule do
      @tydo
      #    ^
    end
    """

    list = Suggestion.suggestions(buffer, 2, 7)

    assert [
             %{label: ~s(@typedoc """""")},
             %{label: "@typedoc false"}
           ] = list |> Enum.filter(&(&1.type == :generic and &1.kind == :snippet))
  end

  test "functions defined in the module" do
    buffer = """
    defmodule ElixirSenseExample.ModuleA do
      def test_fun_pub(a), do: :ok
      defp test_fun_priv(), do: :ok
      defp is_boo_overlaps_kernel(), do: :ok
      defdelegate delegate_defined, to: Kernel, as: :is_binary
      defdelegate delegate_not_defined, to: Dummy, as: :hello
      defguard my_guard_pub(value) when is_integer(value) and rem(value, 2) == 0
      defguardp my_guard_priv(value) when is_integer(value)
      defmacro a_macro(a) do
        quote do: :ok
      end
      defmacrop a_macro_priv(a) do
        quote do: :ok
      end

      def some_fun() do
        test
        a = &test_fun_pr
        is_bo
        delegate_
        my_
        a_m
      end
    end
    """

    assert [
             %{
               arity: 0,
               name: "test_fun_priv",
               origin: "ElixirSenseExample.ModuleA",
               type: :function,
               visibility: :private
             },
             %{
               arity: 1,
               name: "test_fun_pub",
               origin: "ElixirSenseExample.ModuleA",
               type: :function,
               visibility: :public
             }
           ] = Suggestion.suggestions(buffer, 17, 9)

    assert [
             %{
               arity: 0,
               name: "test_fun_priv",
               origin: "ElixirSenseExample.ModuleA",
               type: :function
             }
           ] = Suggestion.suggestions(buffer, 18, 21)

    assert [
             %{
               arity: 0,
               name: "is_boo_overlaps_kernel",
               origin: "ElixirSenseExample.ModuleA",
               type: :function
             },
             %{
               arity: 1,
               name: "is_boolean",
               origin: "Kernel",
               type: :function
             }
           ] = Suggestion.suggestions(buffer, 19, 10)

    assert [
             %{
               arity: 0,
               name: "delegate_defined",
               origin: "ElixirSenseExample.ModuleA",
               type: :function
             },
             %{
               arity: 0,
               name: "delegate_not_defined",
               origin: "ElixirSenseExample.ModuleA",
               type: :function
             }
           ] = Suggestion.suggestions(buffer, 20, 14)

    assert [
             %{
               args: "value",
               arity: 1,
               name: "my_guard_priv",
               origin: "ElixirSenseExample.ModuleA",
               spec: "",
               summary: "",
               type: :macro,
               visibility: :private
             },
             %{
               args: "value",
               arity: 1,
               name: "my_guard_pub",
               origin: "ElixirSenseExample.ModuleA",
               spec: "",
               summary: "",
               type: :macro
             }
           ] = Suggestion.suggestions(buffer, 21, 8)

    assert [
             %{
               args: "a",
               arity: 1,
               name: "a_macro",
               origin: "ElixirSenseExample.ModuleA",
               spec: "",
               summary: "",
               type: :macro,
               visibility: :public
             },
             %{
               args: "a",
               arity: 1,
               name: "a_macro_priv",
               origin: "ElixirSenseExample.ModuleA",
               spec: "",
               summary: "",
               type: :macro
             }
           ] = Suggestion.suggestions(buffer, 22, 8)
  end

  test "suggest local macro" do
    buffer = """
    defmodule MyModule do
      defmacrop some_macro(var), do: Macro.expand(var, __CALLER__)

      defmacro other do
        some_ma
      end
    end
    """

    assert [%{name: "some_macro"}] = Suggestion.suggestions(buffer, 5, 12)
  end

  test "does not suggest local macro if it's defined after the cursor" do
    buffer = """
    defmodule MyModule do
      defmacro other do
        some_ma
      end

      defmacrop some_macro(var), do: Macro.expand(var, __CALLER__)
    end
    """

    assert [] == Suggestion.suggestions(buffer, 3, 12)
  end

  test "suggest local function even if it's defined after the cursor" do
    buffer = """
    defmodule MyModule do
      def other do
        some_fu
      end

      defp some_fun(var), do: :ok
    end
    """

    assert [%{name: "some_fun"}] = Suggestion.suggestions(buffer, 3, 12)
  end

  test "functions defined in other module fully qualified" do
    buffer = """
    defmodule ElixirSenseExample.ModuleO do
      def test_fun_pub(a), do: :ok
      defp test_fun_priv(), do: :ok
    end

    defmodule ElixirSenseExample.ModuleA do
      def some_fun() do
        ElixirSenseExample.ModuleO.te
      end
    end
    """

    assert [
             %{
               arity: 1,
               name: "test_fun_pub",
               origin: "ElixirSenseExample.ModuleO",
               type: :function
             }
           ] = Suggestion.suggestions(buffer, 8, 34)
  end

  test "functions defined in other module aliased" do
    buffer = """
    defmodule ElixirSenseExample.ModuleO do
      def test_fun_pub(a), do: :ok
      defp test_fun_priv(), do: :ok
    end

    defmodule ElixirSenseExample.ModuleA do
      alias ElixirSenseExample.ModuleO
      def some_fun() do
        ModuleO.te
      end
    end
    """

    assert [
             %{
               arity: 1,
               name: "test_fun_pub",
               origin: "ElixirSenseExample.ModuleO",
               type: :function
             }
           ] = Suggestion.suggestions(buffer, 9, 15)
  end

  test "functions defined in other module imported" do
    buffer = """
    defmodule ElixirSenseExample.ModuleO do
      @spec test_fun_pub(integer) :: atom
      def test_fun_pub(a), do: :ok
      defp test_fun_priv(), do: :ok
    end

    defmodule ElixirSenseExample.ModuleA do
      import ElixirSenseExample.ModuleO
      def some_fun() do
        test
        __info
      end
    end
    """

    assert [
             %{
               arity: 1,
               def_arity: 1,
               name: "test_fun_pub",
               origin: "ElixirSenseExample.ModuleO",
               type: :function,
               args: "a",
               args_list: ["a"],
               spec: "@spec test_fun_pub(integer()) :: atom()",
               summary: "",
               metadata: %{},
               snippet: nil,
               visibility: :public
             }
           ] = Suggestion.suggestions(buffer, 10, 9)

    # builtin functions not called locally
    assert [] == Suggestion.suggestions(buffer, 11, 11)
  end

  test "built-in functions not returned on local calls" do
    buffer = """
    defmodule ElixirSenseExample.ModuleO do
      
    end
    """

    refute Enum.any?(Suggestion.suggestions(buffer, 2, 2), &(&1[:name] == "module_info"))
  end

  test "built-in functions not returned on remote calls" do
    buffer = """
    defmodule ElixirSenseExample.ModuleO do
      ElixirSenseExample.ModuleO.
    end
    """

    assert Enum.any?(Suggestion.suggestions(buffer, 2, 30), &(&1[:name] == "module_info"))
  end

  test "functions and module suggestions with __MODULE__" do
    buffer = """
    defmodule ElixirSenseExample.SmodO do
      def test_fun_pub(a), do: :ok
      defp test_fun_priv(), do: :ok
    end

    defmodule ElixirSenseExample do
      defp test_fun_priv1(a), do: :ok
      def some_fun() do
        __MODULE__.Sm
        __MODULE__.SmodO.te
        __MODULE__.te
        __MODULE__.__in
      end
    end
    """

    assert [
             %{
               name: "SmodO",
               type: :module
             }
           ] =
             Suggestion.suggestions(buffer, 9, 18)
             |> Enum.filter(&(&1.name |> String.starts_with?("Smo")))

    assert [
             %{
               arity: 1,
               name: "test_fun_pub",
               origin: "ElixirSenseExample.SmodO",
               type: :function
             }
           ] = Suggestion.suggestions(buffer, 10, 24)

    # no private on external call
    assert [] = Suggestion.suggestions(buffer, 11, 18)

    assert [
             %{
               arity: 1,
               name: "__info__",
               origin: "ElixirSenseExample",
               type: :function
             }
           ] = Suggestion.suggestions(buffer, 12, 20)
  end

  test "Elixir module" do
    buffer = """
    defmodule MyModule do
      El
    end
    """

    list = Suggestion.suggestions(buffer, 2, 5)

    assert %{
             type: :module,
             name: "Elixir",
             full_name: "Elixir",
             subtype: :alias,
             summary: "",
             metadata: %{}
           } = Enum.at(list, 0)
  end

  test "suggestion for aliases modules defined by require clause" do
    buffer = """
    defmodule Mod do
      require Integer, as: I
      I.is_o
    end
    """

    list = Suggestion.suggestions(buffer, 3, 9)
    assert Enum.at(list, 0).name == "is_odd"
  end

  test "suggestion for struct fields" do
    buffer = """
    defmodule Mod do
      %ElixirSenseExample.IO.Stream{}
      %ArgumentError{}
    end
    """

    list =
      Suggestion.suggestions(buffer, 2, 33)
      |> Enum.filter(&(&1.type in [:field]))

    assert list == [
             %{
               name: "__struct__",
               origin: "ElixirSenseExample.IO.Stream",
               type: :field,
               call?: false,
               subtype: :struct_field,
               type_spec: "ElixirSenseExample.IO.Stream"
             },
             %{
               name: "device",
               origin: "ElixirSenseExample.IO.Stream",
               type: :field,
               call?: false,
               subtype: :struct_field,
               type_spec: "IO.device()"
             },
             %{
               name: "line_or_bytes",
               origin: "ElixirSenseExample.IO.Stream",
               type: :field,
               call?: false,
               subtype: :struct_field,
               type_spec: ":line | non_neg_integer()"
             },
             %{
               name: "raw",
               origin: "ElixirSenseExample.IO.Stream",
               type: :field,
               call?: false,
               subtype: :struct_field,
               type_spec: "boolean()"
             }
           ]

    list =
      Suggestion.suggestions(buffer, 3, 18)
      |> Enum.filter(&(&1.type in [:field]))

    assert list == [
             %{
               name: "__exception__",
               origin: "ArgumentError",
               type: :field,
               call?: false,
               subtype: :struct_field,
               type_spec: "true"
             },
             %{
               name: "__struct__",
               origin: "ArgumentError",
               type: :field,
               call?: false,
               subtype: :struct_field,
               type_spec: "ArgumentError"
             },
             %{
               name: "message",
               origin: "ArgumentError",
               type: :field,
               call?: false,
               subtype: :struct_field,
               type_spec: nil
             }
           ]
  end

  test "suggestion for aliased struct fields" do
    buffer = """
    defmodule Mod do
      alias ElixirSenseExample.IO.Stream
      %Stream{
    end
    """

    list =
      Suggestion.suggestions(buffer, 3, 11)
      |> Enum.filter(&(&1.type in [:field]))

    assert list == [
             %{
               name: "__struct__",
               origin: "ElixirSenseExample.IO.Stream",
               type: :field,
               call?: false,
               subtype: :struct_field,
               type_spec: "ElixirSenseExample.IO.Stream"
             },
             %{
               name: "device",
               origin: "ElixirSenseExample.IO.Stream",
               type: :field,
               call?: false,
               subtype: :struct_field,
               type_spec: "IO.device()"
             },
             %{
               name: "line_or_bytes",
               origin: "ElixirSenseExample.IO.Stream",
               type: :field,
               call?: false,
               subtype: :struct_field,
               type_spec: ":line | non_neg_integer()"
             },
             %{
               name: "raw",
               origin: "ElixirSenseExample.IO.Stream",
               type: :field,
               call?: false,
               subtype: :struct_field,
               type_spec: "boolean()"
             }
           ]
  end

  test "suggestion for builtin fields in struct pattern match" do
    buffer = """
    defmodule Mod do
      def my(%_{}), do: :ok
      def my(%var{}), do: var
    end
    """

    list =
      Suggestion.suggestions(buffer, 2, 13)
      |> Enum.filter(&(&1.type in [:field]))

    assert list == [
             %{
               name: "__struct__",
               origin: nil,
               type: :field,
               call?: false,
               subtype: :struct_field,
               type_spec: "atom()"
             }
           ]

    list =
      Suggestion.suggestions(buffer, 3, 15)
      |> Enum.filter(&(&1.type in [:field]))

    assert list == [
             %{
               name: "__struct__",
               origin: nil,
               type: :field,
               call?: false,
               subtype: :struct_field,
               type_spec: "atom()"
             }
           ]
  end

  test "suggestion for aliased struct fields atom module" do
    buffer = """
    defmodule Mod do
      alias ElixirSenseExample.IO.Stream
      %:"Elixir.Stream"{
    end
    """

    list =
      Suggestion.suggestions(buffer, 3, 21)
      |> Enum.filter(&(&1.type in [:field]))

    assert list == [
             %{
               name: "__struct__",
               origin: "ElixirSenseExample.IO.Stream",
               type: :field,
               call?: false,
               subtype: :struct_field,
               type_spec: "ElixirSenseExample.IO.Stream"
             },
             %{
               name: "device",
               origin: "ElixirSenseExample.IO.Stream",
               type: :field,
               call?: false,
               subtype: :struct_field,
               type_spec: "IO.device()"
             },
             %{
               name: "line_or_bytes",
               origin: "ElixirSenseExample.IO.Stream",
               type: :field,
               call?: false,
               subtype: :struct_field,
               type_spec: ":line | non_neg_integer()"
             },
             %{
               name: "raw",
               origin: "ElixirSenseExample.IO.Stream",
               type: :field,
               call?: false,
               subtype: :struct_field,
               type_spec: "boolean()"
             }
           ]
  end

  test "suggestion for metadata struct fields" do
    buffer = """
    defmodule MyServer do
      defstruct [
        field_1: nil,
        field_2: ""
      ]

      def func do
        %MyServer{}
        %MyServer{field_2: "2", }
      end
    end
    """

    list =
      Suggestion.suggestions(buffer, 8, 15)
      |> Enum.filter(&(&1.type in [:field]))

    assert list == [
             %{
               name: "__struct__",
               origin: "MyServer",
               type: :field,
               call?: false,
               subtype: :struct_field,
               type_spec: "MyServer"
             },
             %{
               name: "field_1",
               origin: "MyServer",
               type: :field,
               call?: false,
               subtype: :struct_field,
               type_spec: nil
             },
             %{
               name: "field_2",
               origin: "MyServer",
               type: :field,
               call?: false,
               subtype: :struct_field,
               type_spec: nil
             }
           ]

    list = Suggestion.suggestions(buffer, 9, 28)

    assert list == [
             %{
               name: "__struct__",
               origin: "MyServer",
               type: :field,
               call?: false,
               subtype: :struct_field,
               type_spec: "MyServer"
             },
             %{
               name: "field_1",
               origin: "MyServer",
               type: :field,
               call?: false,
               subtype: :struct_field,
               type_spec: nil
             }
           ]
  end

  test "suggestion for metadata struct fields atom module" do
    buffer = """
    defmodule :my_server do
      defstruct [
        field_1: nil,
        field_2: ""
      ]

      def func do
        %:my_server{}
        %:my_server{field_2: "2", }
      end
    end
    """

    list =
      Suggestion.suggestions(buffer, 8, 17)
      |> Enum.filter(&(&1.type in [:field]))

    assert list == [
             %{
               name: "__struct__",
               origin: ":my_server",
               type: :field,
               call?: false,
               subtype: :struct_field,
               type_spec: ":my_server"
             },
             %{
               name: "field_1",
               origin: ":my_server",
               type: :field,
               call?: false,
               subtype: :struct_field,
               type_spec: nil
             },
             %{
               name: "field_2",
               origin: ":my_server",
               type: :field,
               call?: false,
               subtype: :struct_field,
               type_spec: nil
             }
           ]

    list = Suggestion.suggestions(buffer, 9, 30)

    assert list == [
             %{
               name: "__struct__",
               origin: ":my_server",
               type: :field,
               call?: false,
               subtype: :struct_field,
               type_spec: ":my_server"
             },
             %{
               name: "field_1",
               origin: ":my_server",
               type: :field,
               call?: false,
               subtype: :struct_field,
               type_spec: nil
             }
           ]
  end

  test "suggestion for metadata struct fields multiline" do
    buffer = """
    defmodule MyServer do
      defstruct [
        field_1: nil,
        field_2: ""
      ]

      def func do
        %MyServer{
          field_2: "2",

        }
      end
    end
    """

    list = Suggestion.suggestions(buffer, 10, 7)

    assert list == [
             %{
               name: "__struct__",
               origin: "MyServer",
               type: :field,
               call?: false,
               subtype: :struct_field,
               type_spec: "MyServer"
             },
             %{
               name: "field_1",
               origin: "MyServer",
               type: :field,
               call?: false,
               subtype: :struct_field,
               type_spec: nil
             }
           ]
  end

  test "suggestion for metadata struct fields when using `__MODULE__`" do
    buffer = """
    defmodule MyServer do
      defstruct [
        field_1: nil,
        field_2: ""
      ]

      def func do
        %__MODULE__{field_2: "2", }
      end
    end
    """

    list = Suggestion.suggestions(buffer, 8, 31)

    assert list == [
             %{
               name: "__struct__",
               origin: "MyServer",
               type: :field,
               call?: false,
               subtype: :struct_field,
               type_spec: "MyServer"
             },
             %{
               name: "field_1",
               origin: "MyServer",
               type: :field,
               call?: false,
               subtype: :struct_field,
               type_spec: nil
             }
           ]
  end

  test "suggestion for struct fields in variable.key call syntax" do
    buffer = """
    defmodule MyServer do
      defstruct [
        field_1: nil,
        field_2: ""
      ]

      def func do
        var_1 = %MyServer{}
        var_1.f
      end
    end
    """

    list =
      Suggestion.suggestions(buffer, 9, 12)
      |> Enum.filter(&(&1.type in [:field]))

    assert list == [
             %{
               name: "field_1",
               origin: "MyServer",
               type: :field,
               call?: true,
               subtype: :struct_field,
               type_spec: nil
             },
             %{
               name: "field_2",
               origin: "MyServer",
               type: :field,
               call?: true,
               subtype: :struct_field,
               type_spec: nil
             }
           ]
  end

  test "suggestion for map fields in variable.key call syntax" do
    buffer = """
    defmodule MyServer do
      def func do
        var_1 = %{key_1: 1, key_2: %{abc: 123}}
        var_1.k
      end
    end
    """

    list =
      Suggestion.suggestions(buffer, 4, 12)
      |> Enum.filter(&(&1.type in [:field]))

    assert list == [
             %{
               name: "key_1",
               origin: nil,
               type: :field,
               call?: true,
               subtype: :map_key,
               type_spec: nil
             },
             %{
               name: "key_2",
               origin: nil,
               type: :field,
               call?: true,
               subtype: :map_key,
               type_spec: nil
             }
           ]
  end

  test "suggestion for map fields in @attribute.key call syntax" do
    buffer = """
    defmodule MyServer do
      @var_1 %{key_1: 1, key_2: %{abc: 123}}
      def func do
        @var_1.k
      end
    end
    """

    list =
      Suggestion.suggestions(buffer, 4, 13)
      |> Enum.filter(&(&1.type in [:field]))

    assert list == [
             %{
               name: "key_1",
               origin: nil,
               type: :field,
               call?: true,
               subtype: :map_key,
               type_spec: nil
             },
             %{
               name: "key_2",
               origin: nil,
               type: :field,
               call?: true,
               subtype: :map_key,
               type_spec: nil
             }
           ]
  end

  test "suggestion for functions in variable.key call syntax" do
    buffer = """
    defmodule MyServer do
      def func do
        var_1 = Atom
        var_1.to_str
      end
    end
    """

    list =
      Suggestion.suggestions(buffer, 4, 17)
      |> Enum.filter(&(&1.type in [:function]))

    assert [%{name: "to_string", origin: "Atom", type: :function}] = list
  end

  test "suggestion for vars in struct update" do
    buffer = """
    defmodule MyServer do
      defstruct [
        field_1: nil,
        some_field: ""
      ]

      def some_func() do
        false
      end

      def func(%MyServer{} = some_arg) do
        %MyServer{some
      end
    end
    """

    list = Suggestion.suggestions(buffer, 12, 19)

    assert [
             %{
               origin: "MyServer",
               type: :field,
               name: "some_field",
               call?: false,
               subtype: :struct_field
             },
             %{name: "some_arg", type: :variable},
             %{name: "some_func", type: :function}
           ] = list
  end

  test "suggestion for fields in struct update" do
    buffer = """
    defmodule MyServer do
      defstruct [
        field_1: nil,
        some_field: ""
      ]

      def func(%MyServer{} = some_arg) do
        %MyServer{some_arg | fiel
      end
    end
    """

    list = Suggestion.suggestions(buffer, 8, 30)

    assert list == [
             %{
               call?: false,
               name: "field_1",
               origin: "MyServer",
               subtype: :struct_field,
               type: :field,
               type_spec: nil
             }
           ]
  end

  test "suggestion for fields in struct update variable when module not set" do
    buffer = """
    defmodule MyServer do
      defstruct [
        field_1: nil,
        some_field: ""
      ]

      def func(%MyServer{} = some_arg) do
        %{some_arg | fiel
      end
    end
    """

    list = Suggestion.suggestions(buffer, 8, 22)

    assert list == [
             %{
               call?: false,
               name: "field_1",
               origin: "MyServer",
               subtype: :struct_field,
               type: :field,
               type_spec: nil
             }
           ]
  end

  test "suggestion for fields in struct update attribute when module not set" do
    buffer = """
    defmodule MyServer do
      defstruct [
        field_1: nil,
        some_field: ""
      ]

      @str %MyServer{}

      %{@str | fiel
    end
    """

    list = Suggestion.suggestions(buffer, 9, 16)

    assert list == [
             %{
               call?: false,
               name: "field_1",
               origin: "MyServer",
               subtype: :struct_field,
               type: :field,
               type_spec: nil
             }
           ]
  end

  test "suggestion for fields in struct update when struct type is var" do
    buffer = """
    defmodule MyServer do
      def func(%var{field_1: "asd"} = some_arg) do
        %{some_arg | fiel
      end
    end
    """

    list = Suggestion.suggestions(buffer, 3, 22)

    assert list == [
             %{
               call?: false,
               name: "field_1",
               origin: nil,
               subtype: :struct_field,
               type: :field,
               type_spec: nil
             }
           ]
  end

  test "suggestion for fields in struct when struct type is attribute" do
    buffer = """
    defmodule MyServer do
      @t Time
      %@t{ho
    end
    """

    list = Suggestion.suggestions(buffer, 3, 9)

    assert list == [
             %{
               call?: false,
               name: "hour",
               origin: "Time",
               subtype: :struct_field,
               type: :field,
               type_spec: "Calendar.hour()"
             }
           ]
  end

  test "suggestion for keys in map update" do
    buffer = """
    defmodule MyServer do
      def func(%{field_1: "asd"} = some_arg) do
        %{some_arg | fiel
      end
    end
    """

    list = Suggestion.suggestions(buffer, 3, 22)

    assert list == [
             %{
               call?: false,
               name: "field_1",
               origin: nil,
               subtype: :map_key,
               type: :field,
               type_spec: nil
             }
           ]
  end

  test "suggestion for fuzzy struct fields" do
    buffer = """
    defmodule MyServer do
      def func(%{field_1: "asd"} = some_arg) do
        %{some_arg | fie1
      end
    end
    """

    list = Suggestion.suggestions(buffer, 3, 22)

    assert list == [
             %{
               call?: false,
               name: "field_1",
               origin: nil,
               subtype: :map_key,
               type: :field,
               type_spec: nil
             }
           ]
  end

  test "suggestion for funcs and vars in struct" do
    buffer = """
    defmodule MyServer do
      defstruct [
        field_1: nil,
        some_field: ""
      ]

      def other_func(), do: :ok

      def func(%MyServer{} = some_arg, other_arg) do
        %MyServer{some_arg |
          field_1: ot
      end
    end
    """

    list = Suggestion.suggestions(buffer, 11, 18)

    assert [
             %{name: "other_arg", type: :variable},
             %{
               name: "other_func",
               type: :function,
               args: "",
               args_list: [],
               arity: 0,
               def_arity: 0,
               origin: "MyServer",
               spec: "",
               summary: "",
               visibility: :public,
               snippet: nil,
               metadata: %{}
             }
           ] = list
  end

  test "no suggestion of fields when the module is not a struct" do
    buffer = """
    defmodule Mod do
      %Enum{
    end
    """

    list = Suggestion.suggestions(buffer, 2, 9)
    assert Enum.any?(list, fn %{type: type} -> type == :field end) == false
  end

  test "suggest struct fields when metadata function evaluates to struct" do
    buffer = """
    defmodule Mod do
      defstruct [field: nil]
      @type t :: %__MODULE__{}

      @spec fun() :: t
      def fun(), do: %Mod{}

      def some do
        var = fun()
        var.
      end
    end
    """

    list = Suggestion.suggestions(buffer, 10, 9)

    assert [
             %{call?: true, name: "__struct__", origin: "Mod"},
             %{call?: true, name: "field", origin: "Mod", subtype: :struct_field, type: :field}
           ] = list
  end

  test "suggest struct fields when metadata function evaluates to remote type" do
    buffer = """
    defmodule Mod do
      @spec fun() :: NaiveDateTime.t()
      def fun(), do: NaiveDateTime.new(1, 2)

      def some do
        var = fun()
        var.h
      end
    end
    """

    list = Suggestion.suggestions(buffer, 7, 10)

    assert [%{name: "hour", origin: "NaiveDateTime"}] = list
  end

  test "suggest struct fields when metadata function evaluates to remote type aliased" do
    buffer = """
    defmodule Mod do
      alias NaiveDateTime, as: MyType
      @spec fun() :: MyType.t()
      def fun(), do: MyType.new(1, 2)

      def some do
        var = fun()
        var.h
      end
    end
    """

    list = Suggestion.suggestions(buffer, 8, 10)

    assert [%{name: "hour", origin: "NaiveDateTime"}] = list
  end

  test "suggest struct fields when metadata function evaluates to remote type __MODULE__" do
    buffer = """
    defmodule Mod do
      @type t :: NaiveDateTime.t()
      
      @spec fun() :: __MODULE__.t()
      def fun(), do: nil

      def some do
        var = fun()
        var.h
      end
    end
    """

    list = Suggestion.suggestions(buffer, 9, 10)

    assert [%{name: "hour", origin: "NaiveDateTime"}] = list
  end

  test "suggest struct fields when metadata function evaluates to remote type __MODULE__.Submodule" do
    buffer = """
    defmodule Mod do
      defmodule Sub do
        @type t :: NaiveDateTime.t()
      end
      
      @spec fun() :: __MODULE__.Sub.t()
      def fun(), do: nil

      def some do
        var = fun()
        var.h
      end
    end
    """

    list = Suggestion.suggestions(buffer, 11, 10)

    assert [%{name: "hour", origin: "NaiveDateTime"}] = list
  end

  test "suggest struct fields when variable is struct" do
    buffer = """
    defmodule Abc do
      defstruct [:cde]
    end

    defmodule Mod do
      def my() do
        some(abc)
        abc = %Abc{cde: 1}
        abc.
      end
    end
    """

    list = Suggestion.suggestions(buffer, 9, 9)

    assert [
             %{call?: true, name: "__struct__", origin: "Abc"},
             %{call?: true, name: "cde", origin: "Abc", subtype: :struct_field, type: :field}
           ] = list
  end

  test "suggest struct fields when variable is rebound to struct" do
    buffer = """
    defmodule Abc do
      defstruct [:cde]
    end

    defmodule Mod do
      def my() do
        abc = 1
        some(abc)
        abc = %Abc{cde: 1}
        abc.cde
        abc = 1
      end
    end
    """

    list = Suggestion.suggestions(buffer, 10, 9)

    assert [
             %{call?: true, name: "__struct__", origin: "Abc"},
             %{call?: true, name: "cde", origin: "Abc", subtype: :struct_field, type: :field}
           ] = list
  end

  test "suggest struct fields when attribute is struct" do
    buffer = """
    defmodule Abc do
      defstruct [:cde]
    end

    defmodule Mod do
      @abc %Abc{cde: 1}
      @abc.
    end
    """

    list = Suggestion.suggestions(buffer, 7, 8)

    assert [
             %{call?: true, name: "__struct__", origin: "Abc"},
             %{call?: true, name: "cde", origin: "Abc", subtype: :struct_field, type: :field}
           ] = list
  end

  test "suggest struct fields when attribute is rebound to struct" do
    buffer = """
    defmodule Abc do
      defstruct [:cde]
    end

    defmodule Mod do
      @abc 1
      @abc %Abc{cde: 1}
      @abc.
    end
    """

    list = Suggestion.suggestions(buffer, 8, 8)

    assert [
             %{call?: true, name: "__struct__", origin: "Abc"},
             %{call?: true, name: "cde", origin: "Abc", subtype: :struct_field, type: :field}
           ] = list
  end

  test "suggest modules to alias" do
    buffer = """
    defmodule MyModule do
      alias Str
    end
    """

    list =
      Suggestion.suggestions(buffer, 2, 12)
      |> Enum.filter(fn s -> s.type == :module end)

    assert [
             %{name: "Stream"},
             %{name: "StreamData"},
             %{name: "String"},
             %{name: "StringIO"}
           ] = list |> Enum.filter(&(&1.name |> String.starts_with?("Str")))
  end

  test "suggest modules to alias with __MODULE__" do
    buffer = """
    defmodule Stream do
      alias __MODULE__.Re
    end
    """

    list = Suggestion.suggestions(buffer, 2, 22)

    assert [%{name: "Reducers", type: :module} | _] = list
  end

  test "suggest modules to alias in multi alias syntax" do
    buffer = """
    defmodule MyModule do
      alias Stream.{Re
    end
    """

    list = Suggestion.suggestions(buffer, 2, 19)

    assert [%{name: "Reducers", type: :module}] = list
  end

  test "suggest modules to alias in multi alias syntax with __MODULE__" do
    buffer = """
    defmodule Stream do
      alias __MODULE__.{Re
    end
    """

    list = Suggestion.suggestions(buffer, 2, 23)

    assert [%{name: "Reducers", type: :module}] = list
  end

  describe "suggestion for param options" do
    test "suggest more than one option" do
      buffer = "Local.func_with_options("

      list = suggestions_by_type(:param_option, buffer)
      assert length(list) > 1
    end

    test "are fuzzy" do
      buffer = "Local.func_with_options(remo_wi"
      list = suggestions_by_type(:param_option, buffer)
      assert [%{name: "remote_with_params_o"}] = list
    end

    test "handles macros" do
      buffer = """
      require Local
      Local.macro_with_options(remo_wi\
      """

      list = suggestions_by_type(:param_option, buffer)
      assert [%{name: "remote_with_params_o"}] = list
    end

    test "suggest the same list when options are already set" do
      buffer1 = "Local.func_with_options("
      buffer2 = "Local.func_with_options(local_o: :an_atom, "

      capture_io(:stderr, fn ->
        result1 = suggestions_by_type(:param_option, buffer1)
        result2 = suggestions_by_type(:param_option, buffer2)
        send(self(), {:results, result1, result2})
      end)

      assert_received {:results, result1, result2}
      assert result1 == result2
    end

    test "options as inline list" do
      buffer = "Local.func_with_options_as_inline_list("

      assert %{type_spec: "local_t()", expanded_spec: "@type local_t() :: atom()"} =
               suggestion_by_name("local_o", buffer)

      assert %{
               type_spec: "keyword()",
               expanded_spec: """
               @type keyword() :: [
                 {atom(), any()}
               ]\
               """
             } = suggestion_by_name("builtin_o", buffer)
    end

    test "options vars defined in when" do
      type_spec = "local_t()"
      origin = "ElixirSenseExample.ModuleWithTypespecs.Local"
      spec = "@type local_t() :: atom()"

      buffer = "Local.func_with_option_var_defined_in_when("
      suggestion = suggestion_by_name("local_o", buffer)

      assert suggestion.type_spec == type_spec
      assert suggestion.origin == origin
      assert suggestion.expanded_spec == spec

      buffer = "Local.func_with_options_var_defined_in_when("
      suggestion = suggestion_by_name("local_o", buffer)

      assert suggestion.type_spec == type_spec
      assert suggestion.origin == origin
      assert suggestion.expanded_spec == spec
    end

    test "opaque type internal structure is not revealed" do
      buffer = "Local.func_with_options("
      suggestion = suggestion_by_name("opaque_o", buffer)

      assert suggestion.type_spec == "opaque_t()"
      assert suggestion.origin == "ElixirSenseExample.ModuleWithTypespecs.Local"
      assert suggestion.expanded_spec == "@opaque opaque_t()"
      assert suggestion.doc == "Local opaque type"
    end

    test "private type" do
      buffer = "Local.func_with_options("
      suggestion = suggestion_by_name("private_o", buffer)

      assert suggestion.type_spec == "private_t()"
      assert suggestion.origin == "ElixirSenseExample.ModuleWithTypespecs.Local"
      assert suggestion.expanded_spec == "@typep private_t() :: atom()"
      assert suggestion.doc == ""
    end

    test "local type" do
      buffer = "Local.func_with_options("
      suggestion = suggestion_by_name("local_o", buffer)

      assert suggestion.type_spec == "local_t()"
      assert suggestion.origin == "ElixirSenseExample.ModuleWithTypespecs.Local"
      assert suggestion.expanded_spec == "@type local_t() :: atom()"
      assert suggestion.doc == "Local type"
    end

    test "local type with params" do
      buffer = "Local.func_with_options("
      suggestion = suggestion_by_name("local_with_params_o", buffer)

      assert suggestion.type_spec == "local_t(atom(), integer())"
      assert suggestion.origin == "ElixirSenseExample.ModuleWithTypespecs.Local"
      assert suggestion.expanded_spec =~ "@type local_t(a, b) ::"
    end

    test "basic type" do
      buffer = "Local.func_with_options("
      suggestion = suggestion_by_name("basic_o", buffer)

      assert suggestion.type_spec == "pid()"
      assert suggestion.origin == ""
      assert suggestion.expanded_spec == ""
      assert suggestion.doc == "A process identifier, pid, identifies a process"
    end

    test "basic type with params" do
      buffer = "Local.func_with_options("
      suggestion = suggestion_by_name("basic_with_params_o", buffer)

      assert suggestion.type_spec == "[atom(), ...]"
      assert suggestion.origin == ""
      assert suggestion.expanded_spec == ""
      assert suggestion.doc == "Non-empty proper list"
    end

    test "built-in type" do
      buffer = "Local.func_with_options("
      suggestion = suggestion_by_name("builtin_o", buffer)

      assert suggestion.type_spec == "keyword()"
      assert suggestion.origin == ""

      assert suggestion.expanded_spec == """
             @type keyword() :: [
               {atom(), any()}
             ]\
             """

      assert suggestion.doc == "A keyword list"
    end

    test "built-in type with params" do
      buffer = "Local.func_with_options("
      suggestion = suggestion_by_name("builtin_with_params_o", buffer)

      assert suggestion.type_spec == "keyword(term())"
      assert suggestion.origin == ""
      assert suggestion.expanded_spec =~ "@type keyword(t()) ::"
      assert suggestion.doc == "A keyword list with values of type `t`"
    end

    test "union type" do
      buffer = "Local.func_with_options("
      suggestion = suggestion_by_name("union_o", buffer)

      assert suggestion.type_spec == "union_t()"
      assert suggestion.origin == "ElixirSenseExample.ModuleWithTypespecs.Local"

      assert suggestion.expanded_spec == """
             @type union_t() ::
               atom() | integer()\
             """
    end

    test "list type" do
      buffer = "Local.func_with_options("
      suggestion = suggestion_by_name("list_o", buffer)

      assert suggestion.type_spec == "list_t()"
      assert suggestion.origin == "ElixirSenseExample.ModuleWithTypespecs.Local"
      assert suggestion.expanded_spec =~ "@type list_t() ::"
    end

    test "remote type" do
      buffer = "Local.func_with_options("
      suggestion = suggestion_by_name("remote_o", buffer)

      assert suggestion.type_spec == "ElixirSenseExample.ModuleWithTypespecs.Remote.remote_t()"
      assert suggestion.origin == "ElixirSenseExample.ModuleWithTypespecs.Remote"
      assert suggestion.expanded_spec == "@type remote_t() :: atom()"
      assert suggestion.doc == "Remote type"
    end

    test "remote type with args" do
      buffer = "Local.func_with_options("
      suggestion = suggestion_by_name("remote_with_params_o", buffer)

      assert suggestion.type_spec ==
               "ElixirSenseExample.ModuleWithTypespecs.Remote.remote_t(atom(), integer())"

      assert suggestion.origin == "ElixirSenseExample.ModuleWithTypespecs.Remote"
      assert suggestion.expanded_spec =~ "@type remote_t(a, b) ::"
      assert suggestion.doc == "Remote type with params"
    end

    test "remote erlang type with doc" do
      buffer = "Local.func_with_erlang_type_options("
      suggestion = suggestion_by_name("erlang_t", buffer)

      assert suggestion.type_spec ==
               ":erlang.time_unit()"

      assert suggestion.origin == ":erlang"

      assert suggestion.expanded_spec ==
               "@type time_unit() ::\n  pos_integer()\n  | :second\n  | :millisecond\n  | :microsecond\n  | :nanosecond\n  | :native\n  | :perf_counter\n  | deprecated_time_unit()"

      if System.otp_release() |> String.to_integer() >= 23 do
        assert suggestion.doc =~ "Supported time unit representations"
      end
    end

    test "remote aliased type" do
      buffer = "Local.func_with_options("
      suggestion = suggestion_by_name("remote_aliased_o", buffer)

      assert suggestion.type_spec == "remote_aliased_t()"
      assert suggestion.origin == "ElixirSenseExample.ModuleWithTypespecs.Local"

      assert suggestion.expanded_spec == """
             @type remote_aliased_t() ::
               ElixirSenseExample.ModuleWithTypespecs.Remote.remote_t()
               | ElixirSenseExample.ModuleWithTypespecs.Remote.remote_list_t()\
             """

      assert suggestion.doc == "Remote type from aliased module"
    end

    test "remote aliased inline type" do
      buffer = "Local.func_with_options("
      suggestion = suggestion_by_name("remote_aliased_inline_o", buffer)

      assert suggestion.type_spec == "ElixirSenseExample.ModuleWithTypespecs.Remote.remote_t()"
      assert suggestion.origin == "ElixirSenseExample.ModuleWithTypespecs.Remote"
      assert suggestion.expanded_spec == "@type remote_t() :: atom()"
      assert suggestion.doc == "Remote type"
    end

    test "inline list type" do
      buffer = "Local.func_with_options("
      suggestion = suggestion_by_name("inline_list_o", buffer)

      assert suggestion.type_spec == "[:trace | :log]"
      assert suggestion.origin == ""
      assert suggestion.expanded_spec == ""
      assert suggestion.doc == ""
    end

    test "non existent type" do
      buffer = "Local.func_with_options("
      suggestion = suggestion_by_name("non_existent_o", buffer)

      assert suggestion.type_spec ==
               "ElixirSenseExample.ModuleWithTypespecs.Remote.non_existent()"

      assert suggestion.origin == "ElixirSenseExample.ModuleWithTypespecs.Remote"
      assert suggestion.expanded_spec == ""
      assert suggestion.doc == ""
    end

    test "named options" do
      buffer = "Local.func_with_named_options("
      assert suggestion_by_name("local_o", buffer).type_spec == "local_t()"
    end

    test "options with only one option" do
      buffer = "Local.func_with_one_option("
      assert suggestion_by_name("option_1", buffer).type_spec == "integer()"
    end

    test "union of options" do
      buffer = "Local.func_with_union_of_options("

      assert suggestion_by_name("local_o", buffer).type_spec == "local_t()"
      assert suggestion_by_name("option_1", buffer).type_spec == "atom()"
    end

    test "union of options inline" do
      buffer = "Local.func_with_union_of_options_inline("

      assert suggestion_by_name("local_o", buffer).type_spec == "local_t()"
      assert suggestion_by_name("option_1", buffer).type_spec == "atom()"
    end

    test "union of options (local and remote) as type + inline" do
      buffer = "Local.func_with_union_of_options_as_type("
      assert suggestion_by_name("option_1", buffer).type_spec == "boolean()"

      suggestion = suggestion_by_name("remote_option_1", buffer)
      assert suggestion.type_spec == "ElixirSenseExample.ModuleWithTypespecs.Remote.remote_t()"
      assert suggestion.expanded_spec == "@type remote_t() :: atom()"
      assert suggestion.doc == "Remote type"
    end

    test "atom only options" do
      buffer = ":ets.new(:name,"

      assert suggestion_by_name("duplicate_bag", buffer).type_spec == ""
      assert suggestion_by_name("named_table", buffer).doc == ""
    end

    test "format type spec" do
      buffer = "Local.func_with_options("

      assert suggestion_by_name("large_o", buffer).expanded_spec == """
             @type large_t() ::
               pid()
               | port()
               | (registered_name ::
                    atom())
               | {registered_name ::
                    atom(), node()}\
             """
    end
  end

  describe "suggestions for typespecs" do
    if Version.match?(System.version(), ">= 1.15.0") do
      test "remote types - filter list of typespecs" do
        buffer = """
        defmodule My do
          @type a :: Remote.remote_t\
        """

        list = suggestions_by_type(:type_spec, buffer)
        assert length(list) == 4
      end
    end

    if Version.match?(System.version(), ">= 1.15.0") do
      test "remote types - retrieve info from typespecs" do
        buffer = """
        defmodule My do
          @type a :: Remote.\
        """

        suggestion = suggestion_by_name("remote_list_t", buffer)

        assert suggestion.spec == """
               @type remote_list_t() :: [
                 remote_t()
               ]\
               """

        assert suggestion.signature == "remote_list_t()"
        assert suggestion.arity == 0
        assert suggestion.doc == "Remote list type"
        assert suggestion.origin == "ElixirSenseExample.ModuleWithTypespecs.Remote"
      end
    end

    test "on specs" do
      if Version.match?(System.version(), ">= 1.15.0") do
        buffer = """
        defmodule My do
          @spec a() :: Remote.\
        """

        assert %{name: "remote_list_t"} = suggestion_by_name("remote_list_t", buffer)
      end

      buffer = """
      defmodule My do
        @spec a(Remote.) :: integer
      end
      """

      assert %{name: "remote_list_t"} = suggestion_by_name("remote_list_t", buffer, 2, 18)

      buffer = """
      defmodule My do
        @spec a(Remote.)
      end
      """

      assert %{name: "remote_list_t"} = suggestion_by_name("remote_list_t", buffer, 2, 18)
    end

    test "on callbacks" do
      buffer = """
      defmodule My do
        @callback a() :: none
      end
      """

      assert [_, _] = suggestions_by_name("nonempty_list", buffer, 2, 24)

      buffer = """
      defmodule My do
        @callback a(none) :: integer
      end
      """

      assert [_, _] = suggestions_by_name("nonempty_list", buffer, 2, 19)

      buffer = """
      defmodule My do
        @callback a(none)
      end
      """

      assert [_, _] = suggestions_by_name("nonempty_list", buffer, 2, 19)
    end

    if Version.match?(System.version(), ">= 1.15.0") do
      test "remote types - by attribute" do
        buffer = """
        defmodule My do
          @type my_type :: integer
          @attr My
          @type some :: @attr.my\
        """

        [suggestion_1] = suggestions_by_name("my_type", buffer)

        assert suggestion_1.signature == "my_type()"
      end
    end

    if Version.match?(System.version(), ">= 1.15.0") do
      test "remote types - by __MODULE__" do
        buffer = """
        defmodule My do
          @type my_type :: integer
          @type some :: __MODULE__.my\
        """

        [suggestion_1] = suggestions_by_name("my_type", buffer)

        assert suggestion_1.signature == "my_type()"
      end
    end

    if Version.match?(System.version(), ">= 1.15.0") do
      test "remote types - retrieve info from typespecs with params" do
        buffer = """
        defmodule My do
          @type a :: Remote.\
        """

        [suggestion_1, suggestion_2] = suggestions_by_name("remote_t", buffer)

        assert suggestion_1.spec == "@type remote_t() :: atom()"
        assert suggestion_1.signature == "remote_t()"
        assert suggestion_1.arity == 0
        assert suggestion_1.doc == "Remote type"
        assert suggestion_1.origin == "ElixirSenseExample.ModuleWithTypespecs.Remote"

        assert suggestion_2.spec =~ "@type remote_t(a, b) ::"
        assert suggestion_2.signature == "remote_t(a, b)"
        assert suggestion_2.arity == 2
        assert suggestion_2.doc == "Remote type with params"
        assert suggestion_2.origin == "ElixirSenseExample.ModuleWithTypespecs.Remote"
      end
    end

    test "local types - filter list of typespecs" do
      buffer = """
      defmodule ElixirSenseExample.ModuleWithTypespecs.Local do
        # The types are defined in `test/support/module_with_typespecs.ex`
        @type my_type :: local_
        #                      ^
      end
      """

      list =
        Suggestion.suggestions(buffer, 3, 26)
        |> Enum.filter(fn %{type: t} -> t == :type_spec end)

      assert length(list) == 2
    end

    test "typespec fuzzy match" do
      buffer = """
      defmodule ElixirSenseExample.ModuleWithTypespecs.Local do
        # The types are defined in `test/support/module_with_typespecs.ex`
        @type fuzzy_type :: loca_
        #                        ^
      end
      """

      list =
        Suggestion.suggestions(buffer, 3, 27)
        |> Enum.filter(fn %{type: t} -> t == :type_spec end)

      [suggestion, _] = list

      assert suggestion.spec == "@type local_t() :: atom()"
      assert suggestion.signature == "local_t()"
      assert suggestion.arity == 0
      assert suggestion.doc == "Local type"
      assert suggestion.origin == "ElixirSenseExample.ModuleWithTypespecs.Local"
    end

    test "local types - retrieve info from typespecs" do
      buffer = """
      defmodule ElixirSenseExample.ModuleWithTypespecs.Local do
        # The types are defined in `test/support/module_with_typespecs.ex`
        @type my_type :: local_t
        #                       ^
      end
      """

      list =
        Suggestion.suggestions(buffer, 3, 27)
        |> Enum.filter(fn %{type: t} -> t == :type_spec end)

      [suggestion, _] = list

      assert suggestion.spec == "@type local_t() :: atom()"
      assert suggestion.signature == "local_t()"
      assert suggestion.arity == 0
      assert suggestion.doc == "Local type"
      assert suggestion.origin == "ElixirSenseExample.ModuleWithTypespecs.Local"
    end

    test "builtin types - filter list of typespecs" do
      buffer = "defmodule My, do: @type my_type :: lis"

      list = suggestions_by_type(:type_spec, buffer)
      assert length(list) == 2
    end

    test "builtin types - retrieve info from typespecs" do
      buffer = "defmodule My, do: @type my_type :: lis"

      [suggestion | _] = suggestions_by_type(:type_spec, buffer)

      assert suggestion.spec == "@type list() :: [any()]"
      assert suggestion.signature == "list()"
      assert suggestion.arity == 0
      assert suggestion.doc == "A list"
      assert suggestion.origin == nil
    end

    test "builtin types - retrieve info from typespecs with params" do
      buffer = "defmodule My, do: @type my_type :: lis"

      [_, suggestion | _] = suggestions_by_type(:type_spec, buffer)

      assert suggestion.spec == "@type list(t())"
      assert suggestion.signature == "list(t())"
      assert suggestion.arity == 1
      assert suggestion.doc == "Proper list ([]-terminated)"
      assert suggestion.origin == nil
    end

    test "builtin types - retrieve info from basic types" do
      buffer = "defmodule My, do: @type my_type :: int"

      [_, suggestion | _] = suggestions_by_type(:type_spec, buffer)

      assert suggestion.spec == "@type integer()"
      assert suggestion.signature == "integer()"
      assert suggestion.arity == 0
      assert suggestion.doc == "An integer number"
      assert suggestion.origin == nil
    end

    test "erlang types" do
      buffer = "defmodule My, do: @type my_type :: :erlang.time_"

      suggestions = suggestions_by_type(:type_spec, buffer)

      assert [
               %{
                 arity: 0,
                 doc: summary,
                 name: "time_unit",
                 origin: ":erlang",
                 signature: "time_unit()",
                 spec:
                   "@type time_unit() ::\n  pos_integer()\n  | :second\n  | :millisecond\n  | :microsecond\n  | :nanosecond\n  | :native\n  | :perf_counter\n  | deprecated_time_unit()",
                 type: :type_spec
               }
             ] = suggestions

      if System.otp_release() |> String.to_integer() >= 23 do
        if System.otp_release() |> String.to_integer() >= 27 do
          assert "The time unit used" <> _ = summary
        else
          assert summary =~ "Supported time unit representations:"
        end
      end
    end

    test "no erlang private types" do
      buffer = "defmodule My, do: @type my_type :: :dialyzer_plt.dialyzer_p"

      suggestions = suggestions_by_type(:type_spec, buffer)

      assert [] == suggestions
    end

    test "type with @typedoc false" do
      buffer =
        "defmodule My, do: @type my_type :: ElixirSenseExample.ModuleWithDocs.some_type_doc_false"

      suggestions = suggestions_by_type(:type_spec, buffer)

      assert [
               %{
                 arity: 0,
                 doc: "",
                 name: "some_type_doc_false",
                 origin: "ElixirSenseExample.ModuleWithDocs",
                 signature: "some_type_doc_false()",
                 spec: "@type some_type_doc_false() ::" <> _,
                 type: :type_spec,
                 metadata: %{}
               }
             ] = suggestions
    end

    test "local types from metadata" do
      buffer = """
      defmodule MyModule do
        @typep my_local_t :: integer
        @typep my_local_arg_t(a, b) :: {a, b}
        @type my_type :: my_loc
        #                      ^
      end
      """

      list =
        Suggestion.suggestions(buffer, 4, 26)
        |> Enum.filter(fn %{type: t} -> t == :type_spec end)

      assert [suggestion1, suggestion2] = list

      assert %{
               arity: 0,
               name: "my_local_t",
               origin: "MyModule",
               type: :type_spec,
               signature: "my_local_t()",
               args_list: [],
               doc: "",
               spec: "@typep my_local_t() :: integer()",
               metadata: %{}
             } == suggestion2

      assert %{
               arity: 2,
               name: "my_local_arg_t",
               origin: "MyModule",
               type: :type_spec,
               signature: "my_local_arg_t(a, b)",
               args_list: ["a", "b"],
               doc: "",
               spec: "@typep my_local_arg_t(a, b) :: {a, b}",
               metadata: %{}
             } == suggestion1
    end

    test "suggest local types from metadata even if defined after the cursor" do
      buffer = """
      defmodule MyModule do
        @type my_type :: my_loc
        #                      ^

        @typep my_local_t :: integer
      end
      """

      list =
        Suggestion.suggestions(buffer, 2, 26)
        |> Enum.filter(fn %{type: t} -> t == :type_spec end)

      assert [%{name: "my_local_t"}] = list
    end

    test "return docs and meta on local types" do
      buffer = """
      defmodule MyModule do
        @type my_type :: my_loc
        #                      ^

        @typedoc "Some"
        @typedoc since: "1.2.3"
        @type my_local_t :: integer
      end
      """

      list =
        Suggestion.suggestions(buffer, 2, 26)
        |> Enum.filter(fn %{type: t} -> t == :type_spec end)

      assert [%{name: "my_local_t", doc: "Some", metadata: %{since: "1.2.3"}}] = list
    end

    test "local types from metadata external call - private types are not suggested" do
      buffer = """
      defmodule MyModule do
        @type my_local_t :: integer
        @typep my_local_arg_t(a, b) :: {a, b}
        @type my_type :: MyModule.my_loc
        #                               ^
      end
      """

      list =
        Suggestion.suggestions(buffer, 4, 35)
        |> Enum.filter(fn %{type: t} -> t == :type_spec end)

      assert [suggestion1] = list

      assert %{
               arity: 0,
               name: "my_local_t",
               origin: "MyModule",
               type: :type_spec,
               signature: "my_local_t()",
               args_list: [],
               doc: "",
               spec: "@type my_local_t() :: integer()",
               metadata: %{}
             } == suggestion1
    end

    test "remote public and opaque types from metadata" do
      buffer = """
      defmodule SomeModule do
        @typep my_local_priv_t :: integer
        @type my_local_pub_t(a, b) :: {a, b}
        @opaque my_local_op_t() :: my_local_priv_t
      end

      defmodule MyModule do
        alias SomeModule, as: Some
        @type my_type :: Some.my_loc
        #                           ^
      end
      """

      list =
        Suggestion.suggestions(buffer, 9, 31)
        |> Enum.filter(fn %{type: t} -> t == :type_spec end)

      assert [suggestion1, suggestion2] = list

      assert %{
               arity: 2,
               name: "my_local_pub_t",
               origin: "SomeModule",
               type: :type_spec,
               signature: "my_local_pub_t(a, b)",
               args_list: ["a", "b"],
               doc: "",
               spec: "@type my_local_pub_t(a, b) :: {a, b}",
               metadata: %{}
             } == suggestion2

      assert %{
               arity: 0,
               name: "my_local_op_t",
               origin: "SomeModule",
               type: :type_spec,
               signature: "my_local_op_t()",
               args_list: [],
               doc: "",
               spec: "@opaque my_local_op_t()",
               metadata: %{opaque: true}
             } == suggestion1
    end
  end

  test "suggestion understands alias shadowing" do
    # ordinary alias
    buffer = """
    defmodule ElixirSenseExample.OtherModule do
      alias ElixirSenseExample.SameModule
      def some_fun() do
        SameModule.te
      end
    end
    """

    assert [
             %{origin: "ElixirSenseExample.SameModule"}
           ] = Suggestion.suggestions(buffer, 4, 17)

    # alias shadowing scope/inherited aliases
    buffer = """
    defmodule ElixirSenseExample.Abc.SameModule do
      alias List, as: SameModule
      alias ElixirSenseExample.SameModule
      def some_fun() do
        SameModule.te
      end
    end
    """

    assert [
             %{origin: "ElixirSenseExample.SameModule"}
           ] = Suggestion.suggestions(buffer, 5, 17)

    buffer = """
    defmodule ElixirSenseExample.Abc.SameModule do
      require Logger, as: ModuleB
      require ElixirSenseExample.SameModule, as: SameModule
      SameModule.so
    end
    """

    assert [
             %{origin: "ElixirSenseExample.SameModule"}
           ] = Suggestion.suggestions(buffer, 4, 15)
  end

  test "operator" do
    buffer = """
    defmodule ElixirSenseExample.OtherModule do
      def some_fun() do
        a +
      end
    end
    """

    assert [%{name: "+"}, %{name: "+"}, %{name: "++"}] =
             Suggestion.suggestions(buffer, 3, 8) |> Enum.filter(&("#{&1.name}" =~ "+"))
  end

  test "sigil" do
    buffer = """
    defmodule ElixirSenseExample.OtherModule do
      def some_fun() do
        ~
      end
    end
    """

    suggestions = Suggestion.suggestions(buffer, 3, 6)

    assert [
             %{
               args: "term, modifiers",
               arity: 2,
               name: "~w",
               summary: "Handles the sigil `~w` for list of words.",
               type: :macro
             }
           ] = suggestions |> Enum.filter(&(&1.name == "~w"))
  end

  test "bitstring options" do
    buffer = """
    defmodule ElixirSenseExample.OtherModule do
      alias ElixirSenseExample.SameModule
      def some_fun() do
        <<abc::>>
      end
    end
    """

    options =
      Suggestion.suggestions(buffer, 4, 12)
      |> Enum.filter(&(&1.type == :bitstring_option))
      |> Enum.map(& &1.name)

    assert "integer" in options
    assert "native" in options
    assert "signed" in options

    buffer = """
    defmodule ElixirSenseExample.OtherModule do
      alias ElixirSenseExample.SameModule
      def some_fun() do
        <<abc::int>>
      end
    end
    """

    ["integer"] =
      Suggestion.suggestions(buffer, 4, 15)
      |> Enum.filter(&(&1.type == :bitstring_option))
      |> Enum.map(& &1.name)

    buffer = """
    defmodule ElixirSenseExample.OtherModule do
      alias ElixirSenseExample.SameModule
      def some_fun() do
        <<abc::integer, asd::binary->>
      end
    end
    """

    options =
      Suggestion.suggestions(buffer, 4, 33)
      |> Enum.filter(&(&1.type == :bitstring_option))
      |> Enum.map(& &1.name)

    assert "unit" in options
    assert "size" in options

    buffer = """
    defmodule ElixirSenseExample.OtherModule do
      alias ElixirSenseExample.SameModule
      def some_fun() do
        <<abc::integer, asd::integer-n>>
      end
    end
    """

    ["native"] =
      Suggestion.suggestions(buffer, 4, 35)
      |> Enum.filter(&(&1.type == :bitstring_option))
      |> Enum.map(& &1.name)
  end

  # TODO change that to only output max arity
  test "function with default args generate multiple entries" do
    buffer = """
    ElixirSenseExample.FunctionsWithTheSameName.all
    """

    assert [
             %{
               arity: 1,
               def_arity: 2,
               name: "all?",
               summary: "all?/2 docs",
               type: :function
             },
             %{
               arity: 2,
               def_arity: 2,
               name: "all?",
               summary: "all?/2 docs",
               type: :function
             }
           ] = Suggestion.suggestions(buffer, 1, 48) |> Enum.filter(&(&1[:name] == "all?"))
  end

  test "functions with the same name but different arities generates independent entries" do
    buffer = """
    ElixirSenseExample.FunctionsWithTheSameName.con
    """

    assert [
             %{
               arity: 1,
               def_arity: 1,
               name: "concat",
               summary: "concat/1 docs",
               type: :function
             },
             %{
               arity: 2,
               def_arity: 2,
               name: "concat",
               summary: "concat/2 docs",
               type: :function
             }
           ] =
             Suggestion.suggestions(buffer, 1, 48) |> Enum.filter(&(&1[:name] == "concat"))
  end

  test "function with default args from metadata" do
    buffer = """
    defmodule SomeSchema do
      def my_func(a, b \\\\ "")
      def my_func(1, b), do: :ok
      def my_func(2, b), do: :ok

      def d() do
        my_
      end
    end
    """

    suggestions = Suggestion.suggestions(buffer, 7, 8)

    assert [
             %{args: "a, b \\\\ \"\"", arity: 1, def_arity: 2},
             %{args: "a, b \\\\ \"\"", arity: 2, def_arity: 2}
           ] = suggestions
  end

  test "records from metadata" do
    buffer = """
    defmodule SomeSchema do
      require Record
      Record.defrecord(:user, name: "john", age: 25)
      @type user :: record(:user, name: String.t(), age: integer)

      def d() do
        w = us
      end
    end
    """

    suggestions = Suggestion.suggestions(buffer, 7, 11)

    assert [
             %{
               args: "args \\\\ []",
               arity: 0,
               name: "user",
               summary: "",
               type: :macro,
               args_list: ["args \\\\ []"],
               def_arity: 1,
               metadata: %{},
               origin: "SomeSchema",
               snippet: nil,
               spec: "",
               visibility: :public
             },
             %{
               args: "args \\\\ []",
               arity: 1,
               name: "user",
               summary: "",
               type: :macro,
               args_list: ["args \\\\ []"],
               def_arity: 1,
               metadata: %{},
               origin: "SomeSchema",
               snippet: nil,
               spec: "",
               visibility: :public
             },
             %{
               args: "record, args",
               args_list: ["record", "args"],
               arity: 2,
               def_arity: 2,
               metadata: %{},
               name: "user",
               origin: "SomeSchema",
               snippet: nil,
               spec: "",
               summary: "",
               type: :macro,
               visibility: :public
             }
           ] = suggestions |> Enum.filter(&(&1.name == "user"))
  end

  test "records from introspection" do
    buffer = """
    defmodule SomeSchema do
      require ElixirSenseExample.ModuleWithRecord, as: M

      def d() do
        w = M.us
      end
    end
    """

    suggestions = Suggestion.suggestions(buffer, 5, 12)

    assert [
             %{
               args: "args \\\\ []",
               arity: 0,
               name: "user",
               summary: "",
               type: :macro,
               args_list: ["args \\\\ []"],
               def_arity: 1,
               metadata: %{},
               origin: "ElixirSenseExample.ModuleWithRecord",
               snippet: nil,
               spec: "",
               visibility: :public
             },
             %{
               args: "args \\\\ []",
               arity: 1,
               name: "user",
               summary: "",
               type: :macro,
               args_list: ["args \\\\ []"],
               def_arity: 1,
               metadata: %{},
               origin: "ElixirSenseExample.ModuleWithRecord",
               snippet: nil,
               spec: "",
               visibility: :public
             },
             %{
               args: "record, args",
               args_list: ["record", "args"],
               arity: 2,
               def_arity: 2,
               metadata: %{},
               name: "user",
               origin: "ElixirSenseExample.ModuleWithRecord",
               snippet: nil,
               spec: "",
               summary: "",
               type: :macro,
               visibility: :public
             }
           ] = suggestions |> Enum.filter(&(&1.name == "user"))
  end

  defp suggestions_by_type(type, buffer) do
    {line, column} = get_last_line_and_column(buffer)
    suggestions_by_type(type, buffer, line, column)
  end

  defp suggestions_by_type(type, buffer, line, column) do
    buffer
    |> add_aliases("Local, Remote")
    |> Suggestion.suggestions(line + 1, column)
    |> Enum.filter(fn %{type: t} -> t == type end)
    |> Enum.sort()
  end

  defp suggestions_by_name(name, buffer) do
    {line, column} = get_last_line_and_column(buffer)
    suggestions_by_name(name, buffer, line, column)
  end

  defp suggestions_by_name(name, buffer, line, column) do
    buffer
    |> add_aliases("Local, Remote")
    |> Suggestion.suggestions(line + 1, column)
    |> Enum.filter(fn
      %{name: n} -> n == name
      _ -> false
    end)
    |> Enum.sort()
  end

  defp suggestion_by_name(name, buffer) do
    {line, column} = get_last_line_and_column(buffer)
    suggestion_by_name(name, buffer, line, column)
  end

  defp suggestion_by_name(name, buffer, line, column) do
    [suggestion] = suggestions_by_name(name, buffer, line, column)
    suggestion
  end

  defp get_last_line_and_column(buffer) do
    str_lines = buffer |> Source.split_lines()
    line = length(str_lines)
    column = (str_lines |> List.last() |> String.length()) + 1
    {line, column}
  end

  defp add_aliases(buffer, aliases) do
    "alias ElixirSenseExample.ModuleWithTypespecs.{#{aliases}}\n" <> buffer
  end

  def cursors(text) do
    {_, cursors} =
      ElixirSense.Core.Source.walk_text(text, {false, []}, fn
        "#", rest, _, _, {_comment?, cursors} ->
          {rest, {true, cursors}}

        "\n", rest, _, _, {_comment?, cursors} ->
          {rest, {false, cursors}}

        "^", rest, line, col, {true, cursors} ->
          {rest, {true, [%{line: line - 1, col: col} | cursors]}}

        _, rest, _, _, acc ->
          {rest, acc}
      end)

    Enum.reverse(cursors)
  end

  def suggestions(buffer, cursor) do
    Suggestion.suggestions(buffer, cursor.line, cursor.col)
  end

  def suggestions(buffer, cursor, type) do
    suggestions(buffer, cursor)
    |> Enum.filter(fn s -> s.type == type end)
  end

  def suggestions_by_kind(buffer, cursor, kind) do
    suggestions(buffer, cursor)
    |> Enum.filter(fn s -> s[:kind] == kind end)
  end
end
