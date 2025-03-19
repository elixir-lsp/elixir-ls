# This code has originally been a part of https://github.com/elixir-lsp/elixir_sense

# Copyright (c) 2017 Marlus Saraiva
# Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the 'Software'), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
# The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

# This file includes modified code extracted from the elixir project. Namely:
#
# https://github.com/elixir-lang/elixir/blob/v1.9/lib/iex/test/iex/autocomplete_test.exs
#
# The original code is licensed as follows:
#
# Copyright 2012 Plataformatec
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

defmodule ElixirLS.Utils.CompletionEngineTest do
  use ExUnit.Case, async: true

  alias ElixirLS.Utils.CompletionEngine
  alias ElixirSense.Core.Metadata
  alias ElixirSense.Core.State.Env
  alias ElixirSense.Core.State.{ModFunInfo, SpecInfo, VarInfo, AttributeInfo}

  def expand(
        expr,
        env \\ %Env{functions: :elixir_env.new().functions, macros: :elixir_env.new().macros},
        metadata \\ %Metadata{},
        opts \\ []
      ) do
    CompletionEngine.do_expand(expr, env, metadata, {1, 1}, opts)
  end

  test "erlang module completion" do
    assert [
             %{
               name: ":zlib",
               full_name: ":zlib",
               subtype: nil,
               summary: summary,
               type: :module,
               metadata: metadata
             }
           ] = expand(~c":zl")

    if System.otp_release() |> String.to_integer() >= 23 do
      assert summary =~ "zlib"
      assert %{otp_doc_vsn: {1, 0, 0}} = metadata
    end
  end

  test "erlang module no completion" do
    assert expand(~c":unknown") == []
  end

  test "erlang module multiple values completion" do
    list = expand(~c":logger")
    assert list |> Enum.find(&(&1.name == ":logger"))
    assert list |> Enum.find(&(&1.name == ":logger_proxy"))
  end

  test "erlang root completion" do
    list = expand(~c":")
    assert is_list(list)
    assert list |> Enum.find(&(&1.name == ":lists"))
    assert [] == list |> Enum.filter(&(&1.name |> String.contains?("Elixir.List")))
  end

  test "elixir proxy" do
    list = expand(~c"E")
    assert list |> Enum.find(&(&1.name == "Elixir" and &1.full_name == "Elixir"))
  end

  test "elixir completion" do
    assert [_ | _] = expand(~c"En")

    assert [%{name: "Enumerable", full_name: "Enumerable", subtype: :protocol, type: :module}] =
             expand(~c"Enumera")
  end

  test "elixir module completion with @moduledoc false" do
    assert [%{name: "ModuleWithDocFalse", summary: ""}] =
             expand(~c"ElixirLS.Utils.Example.ModuleWithDocFals")
  end

  test "elixir function completion with @doc false" do
    assert [
             %{
               name: "some_fun_doc_false",
               summary: "",
               args: "a, b \\\\ nil",
               arity: 1,
               origin: "ElixirLS.Utils.Example.ModuleWithDocs",
               spec: "",
               type: :function
             },
             %{
               args: "a, b \\\\ nil",
               arity: 2,
               name: "some_fun_doc_false",
               origin: "ElixirLS.Utils.Example.ModuleWithDocs",
               spec: "",
               summary: "",
               type: :function
             },
             %{
               args: "a, b \\\\ nil",
               arity: 1,
               name: "some_fun_no_doc",
               origin: "ElixirLS.Utils.Example.ModuleWithDocs",
               spec: "",
               summary: "",
               type: :function
             },
             %{
               args: "a, b \\\\ nil",
               arity: 2,
               name: "some_fun_no_doc",
               origin: "ElixirLS.Utils.Example.ModuleWithDocs",
               spec: "",
               summary: "",
               type: :function
             }
           ] = expand(~c"ElixirLS.Utils.Example.ModuleWithDocs.some_fun_")
  end

  test "elixir completion with self" do
    assert [%{name: "Enumerable", subtype: :protocol}] = expand(~c"Enumerable")
  end

  test "elixir completion macro with default args" do
    assert [
             %{
               args: "a \\\\ :asdf, b, var \\\\ 0",
               arity: 1,
               name: "with_default",
               origin: "ElixirLS.Utils.Example.BehaviourWithMacrocallback.Impl",
               spec: "@spec with_default(atom(), list(), integer()) :: Macro.t()",
               summary: "some macro with default arg\n",
               type: :macro
             },
             %{
               args: "a \\\\ :asdf, b, var \\\\ 0",
               arity: 2,
               name: "with_default",
               origin: "ElixirLS.Utils.Example.BehaviourWithMacrocallback.Impl",
               spec: "@spec with_default(atom(), list(), integer()) :: Macro.t()",
               summary: "some macro with default arg\n",
               type: :macro
             },
             %{
               args: "a \\\\ :asdf, b, var \\\\ 0",
               arity: 3,
               name: "with_default",
               origin: "ElixirLS.Utils.Example.BehaviourWithMacrocallback.Impl",
               spec: "@spec with_default(atom(), list(), integer()) :: Macro.t()",
               summary: "some macro with default arg\n",
               type: :macro
             }
           ] = expand(~c"ElixirLS.Utils.Example.BehaviourWithMacrocallback.Impl.wit")
  end

  test "elixir completion on modules from load path" do
    assert [
             %{name: "Stream", subtype: :struct, type: :module},
             %{name: "String", subtype: nil, type: :module},
             %{name: "StringIO", subtype: nil, type: :module}
           ] = expand(~c"Str") |> Enum.filter(&(&1.name |> String.starts_with?("Str")))

    assert [
             %{name: "Macro"},
             %{name: "Map"},
             %{name: "MapSet"},
             %{name: "MatchError"}
           ] = expand(~c"Ma") |> Enum.filter(&(&1.name |> String.starts_with?("Ma")))

    assert [%{name: "Dict"}] =
             expand(~c"Dic") |> Enum.filter(&(&1.name |> String.starts_with?("Dic")))

    assert suggestions = expand(~c"Ex")
    assert Enum.any?(suggestions, &(&1.name == "ExUnit"))
    assert Enum.any?(suggestions, &(&1.name == "Exception"))
  end

  test "Elixir no completion for underscored functions with no doc" do
    {:module, _, bytecode, _} =
      defmodule Elixir.Sample do
        def __foo__(), do: 0
        @doc "Bar doc"
        def __bar__(), do: 1
      end

    File.write!("Elixir.Sample.beam", bytecode)

    case Code.fetch_docs(Sample) do
      {:docs_v1, _, _, _, _, _, _} -> :ok
      {:error, :chunk_not_found} -> :ok
    end

    # IEx version asserts expansion on Sample._ but we also include :__info__ and there is more than 1 match
    assert [%{name: "__bar__"}] = expand(~c"Sample.__b")
  after
    File.rm("Elixir.Sample.beam")
    :code.purge(Sample)
    :code.delete(Sample)
  end

  test "completion for functions added when compiled module is reloaded" do
    {:module, _, bytecode, _} =
      defmodule Sample do
        def foo(), do: 0
      end

    File.write!("ElixirLS.Utils.CompletionEngineTest.Sample.beam", bytecode)

    assert [%{name: "foo"}] = expand(~c"ElixirLS.Utils.CompletionEngineTest.Sample.foo")

    Code.compiler_options(ignore_module_conflict: true)

    defmodule Sample do
      def foo(), do: 0
      def foobar(), do: 0
    end

    assert [%{name: "foo"}, %{name: "foobar"}] =
             expand(~c"ElixirLS.Utils.CompletionEngineTest.Sample.foo")
  after
    File.rm("ElixirLS.Utils.CompletionEngineTest.Sample.beam")
    Code.compiler_options(ignore_module_conflict: false)
    :code.purge(Sample)
    :code.delete(Sample)
  end

  test "elixir no completion" do
    assert expand(~c".") == []
    assert expand(~c"Xyz") == []
    assert expand(~c"x.Foo") == []
    assert expand(~c"x.Foo.get_by") == []
    # assert expand('@foo.bar') == {:no, '', []}
  end

  test "elixir root submodule completion" do
    assert [
             %{
               name: "Access",
               full_name: "Access",
               summary: "Key-based access to data structures."
             }
           ] = expand(~c"Elixir.Acce")

    assert [_ | _] = expand(~c"Elixir.")
  end

  test "elixir submodule completion" do
    assert [
             %{
               name: "Chars",
               full_name: "String.Chars",
               subtype: :protocol,
               summary:
                 "The `String.Chars` protocol is responsible for\nconverting a structure to a binary (only if applicable)."
             }
           ] = expand(~c"String.Cha")
  end

  if Version.match?(System.version(), ">= 1.14.0") do
    test "elixir submodule completion with __MODULE__" do
      assert [
               %{
                 name: "Chars",
                 full_name: "String.Chars",
                 subtype: :protocol,
                 summary:
                   "The `String.Chars` protocol is responsible for\nconverting a structure to a binary (only if applicable)."
               }
             ] = expand(~c"__MODULE__.Cha", %Env{module: String})
    end
  end

  if Version.match?(System.version(), ">= 1.14.0") do
    test "elixir submodule completion with attribute bound to module" do
      assert [
               %{
                 name: "Chars",
                 full_name: "String.Chars",
                 subtype: :protocol,
                 summary:
                   "The `String.Chars` protocol is responsible for\nconverting a structure to a binary (only if applicable)."
               }
             ] =
               expand(~c"@my_attr.Cha", %Env{
                 attributes: [
                   %AttributeInfo{
                     name: :my_attr,
                     type: {:atom, String}
                   }
                 ]
               })
    end
  end

  test "find elixir modules that require alias" do
    assert [
             %{
               metadata: %{},
               name: "Chars",
               full_name: "List.Chars",
               required_alias: "List.Chars"
             },
             %{
               metadata: %{},
               name: "Chars",
               full_name: "String.Chars",
               required_alias: "String.Chars"
             }
           ] = expand(~c"Char", %Env{}, %Metadata{}, required_alias: true)
  end

  test "does not suggest required_alias when alias already exists" do
    env = %Env{
      aliases: [{MyChars, String.Chars}]
    }

    results = expand(~c"Char", env, %Metadata{}, required_alias: true)

    refute Enum.find(results, fn expansion -> expansion[:required_alias] == String.Chars end)
  end

  test "does not suggest required_alias for Elixir proxy" do
    env = %Env{
      aliases: []
    }

    results = expand(~c"Elixi", env, %Metadata{}, required_alias: true)

    refute Enum.find(results, fn expansion -> expansion[:required_alias] == Elixir end)
  end

  test "does not suggest required_alias for when hint has more than one part" do
    results = expand(~c"Elixir.Char", %Env{}, %Metadata{}, required_alias: true)

    refute Enum.find(results, fn expansion -> expansion[:required_alias] == String.Chars end)

    results = expand(~c"String.", %Env{}, %Metadata{}, required_alias: true)

    refute Enum.find(results, fn expansion ->
             expansion[:required_alias] == String.Tokenizer.Security
           end)
  end

  test "elixir submodule no completion" do
    assert expand(~c"IEx.Xyz") == []
  end

  test "function completion" do
    assert [%{name: "version", origin: "System"}] = expand(~c"System.ve")
    assert [%{name: "fun2ms", origin: ":ets"}] = expand(~c":ets.fun2")
  end

  if Version.match?(System.version(), ">= 1.14.0") do
    test "function completion on __MODULE__" do
      assert [%{name: "version", origin: "System"}] =
               expand(~c"__MODULE__.ve", %Env{module: System})
    end
  end

  if Version.match?(System.version(), ">= 1.14.0") do
    test "function completion on __MODULE__ submodules" do
      assert [%{name: "to_string", origin: "String.Chars"}] =
               expand(~c"__MODULE__.Chars.to", %Env{module: String})
    end
  end

  if Version.match?(System.version(), ">= 1.14.0") do
    test "function completion on attribute bound to module" do
      assert [%{name: "version", origin: "System"}] =
               expand(~c"@my_attr.ve", %Env{
                 attributes: [
                   %AttributeInfo{
                     name: :my_attr,
                     type: {:atom, System}
                   }
                 ]
               })
    end
  end

  test "function completion with arity" do
    assert [
             %{
               name: "printable?",
               arity: 1,
               spec:
                 "@spec printable?(t(), 0) :: true\n@spec printable?(t(), pos_integer() | :infinity) :: boolean()",
               summary:
                 "Checks if a string contains only printable characters up to `character_limit`."
             },
             %{
               name: "printable?",
               arity: 2,
               spec:
                 "@spec printable?(t(), 0) :: true\n@spec printable?(t(), pos_integer() | :infinity) :: boolean()",
               summary:
                 "Checks if a string contains only printable characters up to `character_limit`."
             }
           ] = expand(~c"String.printable?")

    assert [%{name: "printable?", arity: 1}, %{name: "printable?", arity: 2}] =
             expand(~c"String.printable?/")

    assert [
             %{
               name: "count",
               arity: 1
             },
             %{
               name: "count",
               arity: 2
             },
             %{
               name: "count_until",
               arity: 2
             },
             %{
               name: "count_until",
               arity: 3
             }
           ] = expand(~c"Enum.count")

    assert [
             %{
               name: "count",
               arity: 1
             },
             %{
               name: "count",
               arity: 2
             }
           ] = expand(~c"Enum.count/")
  end

  test "operator completion" do
    assert [%{name: "+", arity: 1}, %{name: "+", arity: 2}, %{name: "++", arity: 2}] =
             expand(~c"+")

    assert [%{name: "+", arity: 1}, %{name: "+", arity: 2}] = expand(~c"+/")
    assert [%{name: "++", arity: 2}] = expand(~c"++/")

    assert entries = expand(~c"+ ")
    assert entries |> Enum.any?(&(&1.name == "div"))
  end

  test "sigil completion" do
    sigils = expand(~c"~")
    assert sigils |> Enum.any?(fn s -> s.name == "~C" end)
    # We choose not to provide sigil quotations
    # {:yes, '', sigils} = expand('~r')
    # assert '"' in sigils
    # assert '(' in sigils
    assert [] == expand(~c"~r")
  end

  if Version.match?(System.version(), ">= 1.18.0") do
    test "function completion using a capture arg" do
      env = %Env{
        vars: [
          %VarInfo{
            name: :"&12",
            version: 1
          }
        ]
      }

      assert [%{name: "&12", type: :variable}] =
               expand(~c"&1", env)
    end
  end

  test "function completion using a variable bound to a module" do
    env = %Env{
      vars: [
        %VarInfo{
          name: :mod,
          version: 1,
          type: {:atom, String}
        }
      ]
    }

    assert [%{name: "printable?", arity: 1}, %{name: "printable?", arity: 2}] =
             expand(~c"mod.print", env)
  end

  test "map atom key completion is supported" do
    env = %Env{
      vars: [
        %VarInfo{
          name: :map,
          version: 1,
          type: {:map, [foo: 1, bar_1: 23, bar_2: 14], nil}
        }
      ]
    }

    assert expand(~c"map.f", env) ==
             [
               %{
                 name: "foo",
                 subtype: :map_key,
                 type: :field,
                 origin: nil,
                 call?: true,
                 type_spec: nil
               }
             ]

    assert [_ | _] = expand(~c"map.b", env)

    assert expand(~c"map.bar_", env) ==
             [
               %{
                 name: "bar_1",
                 subtype: :map_key,
                 type: :field,
                 origin: nil,
                 call?: true,
                 type_spec: nil
               },
               %{
                 name: "bar_2",
                 subtype: :map_key,
                 type: :field,
                 origin: nil,
                 call?: true,
                 type_spec: nil
               }
             ]

    assert expand(~c"map.c", env) == []

    assert expand(~c"map.", env) ==
             [
               %{
                 name: "bar_1",
                 subtype: :map_key,
                 type: :field,
                 origin: nil,
                 call?: true,
                 type_spec: nil
               },
               %{
                 name: "bar_2",
                 subtype: :map_key,
                 type: :field,
                 origin: nil,
                 call?: true,
                 type_spec: nil
               },
               %{
                 name: "foo",
                 subtype: :map_key,
                 type: :field,
                 origin: nil,
                 call?: true,
                 type_spec: nil
               }
             ]

    assert expand(~c"map.foo", env) == [
             %{
               call?: true,
               name: "foo",
               origin: nil,
               subtype: :map_key,
               type: :field,
               type_spec: nil
             }
           ]
  end

  test "struct key completion is supported" do
    env = %Env{
      vars: [
        %VarInfo{
          name: :struct,
          version: 1,
          type: {:struct, [], {:atom, DateTime}, nil}
        },
        %VarInfo{
          name: :other,
          version: 1,
          type: {:call, {:atom, DateTime}, :utc_now, []}
        },
        %VarInfo{
          name: :from_metadata,
          version: 1,
          type: {:struct, [], {:atom, MyStruct}, nil}
        },
        %VarInfo{
          name: :var,
          version: 1,
          type: {:variable, :struct, 1}
        },
        %VarInfo{
          name: :yyyy,
          version: 1,
          type: {:map, [date: {:struct, [], {:atom, DateTime}, nil}], []}
        },
        %VarInfo{
          name: :xxxx,
          version: 1,
          type: {:call, {:atom, Map}, :fetch!, [{:variable, :yyyy, 1}, {:atom, :date}]}
        }
      ]
    }

    metadata = %Metadata{
      types: %{
        {MyStruct, :t, 0} => %ElixirSense.Core.State.TypeInfo{
          name: :t,
          args: [[]],
          specs: ["@type t :: %MyStruct{some: integer}"],
          kind: :type
        }
      },
      structs: %{
        MyStruct => %ElixirSense.Core.State.StructInfo{type: :defstruct, fields: [some: 1]}
      }
    }

    assert expand(~c"struct.h", env, metadata) ==
             [
               %{
                 call?: true,
                 name: "hour",
                 origin: "DateTime",
                 subtype: :struct_field,
                 type: :field,
                 type_spec: "Calendar.hour()"
               }
             ]

    assert expand(~c"other.d", env, metadata) ==
             [
               %{
                 call?: true,
                 name: "day",
                 origin: "DateTime",
                 subtype: :struct_field,
                 type: :field,
                 type_spec: "Calendar.day()"
               }
             ]

    assert expand(~c"from_metadata.s", env, metadata) ==
             [
               %{
                 call?: true,
                 name: "some",
                 origin: "MyStruct",
                 subtype: :struct_field,
                 type: :field,
                 type_spec: "integer"
               }
             ]

    assert expand(~c"var.h", env, metadata) ==
             [
               %{
                 call?: true,
                 name: "hour",
                 origin: "DateTime",
                 subtype: :struct_field,
                 type: :field,
                 type_spec: "Calendar.hour()"
               }
             ]

    assert expand(~c"xxxx.h", env, metadata) ==
             [
               %{
                 call?: true,
                 name: "hour",
                 origin: "DateTime",
                 subtype: :struct_field,
                 type: :field,
                 type_spec: "Calendar.hour()"
               }
             ]
  end

  test "map atom key completion is supported on attributes" do
    env = %Env{
      attributes: [
        %AttributeInfo{
          name: :map,
          type: {:map, [foo: 1, bar_1: 23, bar_2: 14], nil}
        }
      ]
    }

    assert expand(~c"@map.f", env) ==
             [
               %{
                 name: "foo",
                 subtype: :map_key,
                 type: :field,
                 origin: nil,
                 call?: true,
                 type_spec: nil
               }
             ]

    assert [_ | _] = expand(~c"@map.b", env)

    assert expand(~c"@map.bar_", env) ==
             [
               %{
                 name: "bar_1",
                 subtype: :map_key,
                 type: :field,
                 origin: nil,
                 call?: true,
                 type_spec: nil
               },
               %{
                 name: "bar_2",
                 subtype: :map_key,
                 type: :field,
                 origin: nil,
                 call?: true,
                 type_spec: nil
               }
             ]

    assert expand(~c"@map.c", env) == []

    assert expand(~c"@map.", env) ==
             [
               %{
                 name: "bar_1",
                 subtype: :map_key,
                 type: :field,
                 origin: nil,
                 call?: true,
                 type_spec: nil
               },
               %{
                 name: "bar_2",
                 subtype: :map_key,
                 type: :field,
                 origin: nil,
                 call?: true,
                 type_spec: nil
               },
               %{
                 name: "foo",
                 subtype: :map_key,
                 type: :field,
                 origin: nil,
                 call?: true,
                 type_spec: nil
               }
             ]

    assert expand(~c"@map.foo", env) == [
             %{
               call?: true,
               name: "foo",
               origin: nil,
               subtype: :map_key,
               type: :field,
               type_spec: nil
             }
           ]
  end

  test "nested map atom key completion is supported" do
    env = %Env{
      vars: [
        %VarInfo{
          name: :map,
          version: 1,
          type:
            {:map,
             [
               nested:
                 {:map,
                  [
                    deeply:
                      {:map,
                       [
                         foo: 1,
                         bar_1: 23,
                         bar_2: 14,
                         mod: {:atom, String},
                         num: 1
                       ], nil}
                  ], nil}
             ], nil}
        }
      ]
    }

    assert expand(~c"map.nested.deeply.f", env) ==
             [
               %{
                 name: "foo",
                 subtype: :map_key,
                 type: :field,
                 origin: nil,
                 call?: true,
                 type_spec: nil
               }
             ]

    assert [_ | _] = expand(~c"map.nested.deeply.b", env)

    assert expand(~c"map.nested.deeply.bar_", env) ==
             [
               %{
                 name: "bar_1",
                 subtype: :map_key,
                 type: :field,
                 origin: nil,
                 call?: true,
                 type_spec: nil
               },
               %{
                 name: "bar_2",
                 subtype: :map_key,
                 type: :field,
                 origin: nil,
                 call?: true,
                 type_spec: nil
               }
             ]

    assert expand(~c"map.nested.deeply.", env) ==
             [
               %{
                 name: "bar_1",
                 subtype: :map_key,
                 type: :field,
                 origin: nil,
                 call?: true,
                 type_spec: nil
               },
               %{
                 name: "bar_2",
                 subtype: :map_key,
                 type: :field,
                 origin: nil,
                 call?: true,
                 type_spec: nil
               },
               %{
                 name: "foo",
                 subtype: :map_key,
                 type: :field,
                 origin: nil,
                 call?: true,
                 type_spec: nil
               },
               %{
                 name: "mod",
                 subtype: :map_key,
                 type: :field,
                 origin: nil,
                 call?: true,
                 type_spec: nil
               },
               %{
                 name: "num",
                 subtype: :map_key,
                 type: :field,
                 origin: nil,
                 call?: true,
                 type_spec: nil
               }
             ]

    assert [_ | _] = expand(~c"map.nested.deeply.mod.print", env)

    assert expand(~c"map.nested", env) ==
             [
               %{
                 name: "nested",
                 subtype: :map_key,
                 type: :field,
                 origin: nil,
                 call?: true,
                 type_spec: nil
               }
             ]

    assert expand(~c"map.nested.deeply", env) ==
             [
               %{
                 name: "deeply",
                 subtype: :map_key,
                 type: :field,
                 origin: nil,
                 call?: true,
                 type_spec: nil
               }
             ]

    assert expand(~c"map.nested.deeply.foo", env) == [
             %{
               call?: true,
               name: "foo",
               origin: nil,
               subtype: :map_key,
               type: :field,
               type_spec: nil
             }
           ]

    assert expand(~c"map.nested.deeply.c", env) == []
    assert expand(~c"map.a.b.c.f", env) == []
  end

  test "map string key completion is not supported" do
    env = %Env{
      vars: [
        %VarInfo{
          name: :map,
          version: 1,
          type: {:map, [{"foo", 124}], nil}
        }
      ]
    }

    assert expand(~c"map.f", env) == []
  end

  test "autocompletion off a bound variable only works for modules and maps" do
    env = %Env{
      vars: [
        %VarInfo{
          name: :map,
          version: 1,
          type: {:map, [nested: {:map, [num: 23], nil}], nil}
        }
      ]
    }

    assert expand(~c"num.print", env) == []
    assert expand(~c"map.nested.num.f", env) == []
    assert expand(~c"map.nested.num.key.f", env) == []
  end

  test "autocomplete map fields from call binding" do
    env = %Env{
      vars: [
        %VarInfo{
          name: :map,
          version: 1,
          type: {:map, [{:foo, {:atom, String}}], nil}
        },
        %VarInfo{
          name: :call,
          version: 1,
          type: {:call, {:variable, :map, 1}, :foo, []}
        }
      ]
    }

    assert [_ | _] = expand(~c"call.print", env)
  end

  test "autocomplete call return binding" do
    env = %Env{
      vars: [
        %VarInfo{
          name: :call,
          version: 1,
          type: {:call, {:atom, DateTime}, :utc_now, []}
        }
      ]
    }

    assert [_ | _] = expand(~c"call.ho", env)
    assert [_ | _] = expand(~c"DateTime.utc_now.ho", env)
    # TODO expand expression {:dot, :expr, []} {:dot, :expr, ~c"ho"} on 1.15+
    # Code.cursor_context returns :none for those cases
    assert [] == expand(~c"DateTime.utc_now().", env)
    assert [] == expand(~c"DateTime.utc_now().ho", env)
    assert [] == expand(~c"DateTime.utc_now().calendar.da", env)
  end

  test "autocompletion off of unbound variables is not supported" do
    assert expand(~c"other_var.f") == []
    assert expand(~c"a.b.c.d") == []
  end

  test "macro completion" do
    assert [_ | _] = expand(~c"Kernel.is_")
  end

  test "imports completion" do
    list = expand(~c"")
    assert is_list(list)

    assert list |> Enum.find(&(&1.name == "unquote"))
    # IEX version asserts IEx.Helpers are imported
    # assert list |> Enum.find(& &1.name == "h")
    # assert list |> Enum.find(& &1.name == "pwd")
  end

  test "imports completion in call arg" do
    # local call
    list = expand(~c"asd(")
    assert is_list(list)

    assert list |> Enum.find(&(&1.name == "unquote"))

    list = expand(~c"asd(un")
    assert is_list(list)

    assert list |> Enum.find(&(&1.name == "unquote"))

    # remote call

    list = expand(~c"Abc.asd(")
    assert is_list(list)

    assert list |> Enum.find(&(&1.name == "unquote"))

    list = expand(~c"Abc.asd(un")
    assert is_list(list)

    assert list |> Enum.find(&(&1.name == "unquote"))

    # local call on var

    if Version.match?(System.version(), "< 1.16.0") do
      assert [] == expand(~c"asd.(")
      assert [] == expand(~c"@asd.(")
    else
      expr_suggestions = expand(~c"") |> Enum.map(& &1.type) |> MapSet.new()

      assert expr_suggestions == expand(~c"asd.(") |> Enum.map(& &1.type) |> MapSet.new()
      assert expr_suggestions == expand(~c"@asd.(") |> Enum.map(& &1.type) |> MapSet.new()
    end

    # list = expand('asd.(')
    # assert is_list(list)

    # assert list |> Enum.find(&(&1.name == "unquote"))

    list = expand(~c"asd.(un")
    assert is_list(list)

    assert list |> Enum.find(&(&1.name == "unquote"))
  end

  test "kernel import completion" do
    assert [
             %{
               args: "fields",
               arity: 1,
               name: "defstruct",
               origin: "Kernel",
               spec: "",
               summary: "Defines a struct.",
               type: :macro
             }
           ] = expand(~c"defstru")

    assert [
             %{arity: 3, name: "put_elem"},
             %{arity: 2, name: "put_in"},
             %{arity: 3, name: "put_in"}
           ] = expand(~c"put_")
  end

  test "variable name completion" do
    env = %Env{
      vars: [
        %VarInfo{
          name: :numeral,
          version: 1
        },
        %VarInfo{
          name: :number,
          version: 1
        },
        %VarInfo{
          name: :nothing,
          version: 1
        }
      ]
    }

    assert expand(~c"numb", env) == [%{type: :variable, name: "number"}]

    assert expand(~c"num", env) ==
             [%{type: :variable, name: "number"}, %{type: :variable, name: "numeral"}]

    assert [%{type: :variable, name: "nothing"} | _] = expand(~c"no", env)
  end

  test "variable name completion after pin" do
    env = %Env{
      vars: [
        %VarInfo{
          name: :number,
          version: 1
        }
      ]
    }

    assert expand(~c"^numb", env) == [%{type: :variable, name: "number"}]
    assert expand(~c"^", env) == [%{type: :variable, name: "number"}]
  end

  test "attribute name completion" do
    env = %Env{
      attributes: [
        %AttributeInfo{
          name: :numeral
        },
        %AttributeInfo{
          name: :number
        },
        %AttributeInfo{
          name: :nothing
        }
      ],
      module: My,
      function: {:some, 0}
    }

    assert expand(~c"@numb", env) == [%{type: :attribute, name: "@number", summary: nil}]

    assert expand(~c"@num", env) ==
             [
               %{type: :attribute, name: "@number", summary: nil},
               %{type: :attribute, name: "@numeral", summary: nil}
             ]

    assert expand(~c"@", env) ==
             [
               %{name: "@nothing", type: :attribute, summary: nil},
               %{type: :attribute, name: "@number", summary: nil},
               %{type: :attribute, name: "@numeral", summary: nil}
             ]
  end

  test "builtin attribute name completion" do
    env_function = %Env{
      attributes: [],
      module: Some.Module,
      function: {:some, 0}
    }

    env_module = %Env{
      attributes: [],
      module: Some.Module
    }

    env_outside_module = %Env{
      attributes: []
    }

    assert expand(~c"@befo", env_function) == []
    assert expand(~c"@befo", env_outside_module) == []

    assert expand(~c"@befo", env_module) ==
             [
               %{
                 type: :attribute,
                 name: "@before_compile",
                 summary: "A hook that will be invoked before the module is compiled."
               }
             ]
  end

  test "kernel special form completion" do
    assert [%{name: "unquote_splicing", origin: "Kernel.SpecialForms"}] = expand(~c"unquote_spl")
  end

  test "completion inside expression" do
    assert [_ | _] = expand(~c"1 En")
    assert [_ | _] = expand(~c"Test(En")
    assert [_] = expand(~c"Test :zl")
    assert [_] = expand(~c"[:zl")
    assert [_] = expand(~c"{:zl")
  end

  test "ampersand completion" do
    assert [_ | _] = expand(~c"&Enu")

    assert [
             %{name: "all?", arity: 1},
             %{name: "all?", arity: 2},
             %{name: "any?", arity: 1},
             %{name: "any?", arity: 2},
             %{name: "at", arity: 2},
             %{name: "at", arity: 3}
           ] = expand(~c"&Enum.a")

    assert [
             %{name: "all?", arity: 1},
             %{name: "all?", arity: 2},
             %{name: "any?", arity: 1},
             %{name: "any?", arity: 2},
             %{name: "at", arity: 2},
             %{name: "at", arity: 3}
           ] = expand(~c"f = &Enum.a")
  end

  defmodule SublevelTest.LevelA.LevelB do
  end

  test "elixir completion sublevel" do
    assert [%{name: "LevelA"}] =
             expand(~c"ElixirLS.Utils.CompletionEngineTest.SublevelTest.")
  end

  defmodule MyServer do
    def current_env do
      %Macro.Env{aliases: [{MyList, List}, {EList, :lists}]}
    end
  end

  test "complete aliases of elixir modules" do
    env = %Env{
      aliases: [{MyList, List}]
    }

    assert [%{name: "MyList"}] = expand(~c"MyL", env)
    assert [%{name: "MyList"}] = expand(~c"MyList", env)

    assert [%{arity: 1, name: "to_integer"}, %{arity: 2, name: "to_integer"}] =
             expand(~c"MyList.to_integer", env)
  end

  test "complete aliases of erlang modules" do
    env = %Env{
      aliases: [{ErpList, :lists}]
    }

    assert [%{name: "ErpList"}] = expand(~c"ErpL", env)
    assert [%{name: "ErpList"}] = expand(~c"ErpList", env)

    assert [
             %{arity: 2, name: "map"},
             %{arity: 3, name: "mapfoldl"},
             %{arity: 3, name: "mapfoldr"}
           ] = expand(~c"ErpList.map", env)
  end

  test "complete local funs from scope module" do
    env = %Env{
      module: MyModule
    }

    metadata = %Metadata{
      mods_funs_to_positions: %{
        {MyModule, nil, nil} => %ModFunInfo{type: :defmodule},
        {MyModule, :my_fun_priv, 2} => %ModFunInfo{
          type: :defp,
          params: [[{:some, [], nil}, {:other, [], nil}]]
        },
        {MyModule, :my_fun_pub, 1} => %ModFunInfo{type: :def, params: [[{:some, [], nil}]]},
        {MyModule, :my_macro_priv, 1} => %ModFunInfo{
          type: :defmacrop,
          params: [[{:some, [], nil}]]
        },
        {MyModule, :my_macro_pub, 1} => %ModFunInfo{type: :defmacro, params: [[{:some, [], nil}]]},
        {MyModule, :my_guard_priv, 1} => %ModFunInfo{
          type: :defguardp,
          params: [[{:some, [], nil}]]
        },
        {MyModule, :my_guard_pub, 1} => %ModFunInfo{type: :defguard, params: [[{:some, [], nil}]]},
        {MyModule, :my_delegated, 1} => %ModFunInfo{
          type: :defdelegate,
          params: [[{:some, [], nil}]]
        },
        {OtherModule, nil, nil} => %ModFunInfo{},
        {OtherModule, :my_fun_pub_other, 1} => %ModFunInfo{
          type: :def,
          params: [[{:some, [], nil}]]
        }
      },
      specs: %{
        {MyModule, :my_fun_priv, 2} => %SpecInfo{
          kind: :spec,
          specs: ["@spec my_fun_priv(atom, integer) :: boolean"]
        }
      }
    }

    assert [_ | _] = expand(~c"my_f", %{env | function: {:foo, 1}}, metadata)

    assert [
             %{
               name: "my_fun_priv",
               origin: "MyModule",
               args: "some, other",
               type: :function,
               spec: "@spec my_fun_priv(atom, integer) :: boolean"
             }
           ] = expand(~c"my_fun_pr", %{env | function: {:foo, 1}}, metadata)

    assert [
             %{name: "my_fun_pub", origin: "MyModule", type: :function}
           ] = expand(~c"my_fun_pu", %{env | function: {:foo, 1}}, metadata)

    assert [
             %{name: "my_macro_priv", origin: "MyModule", type: :macro}
           ] = expand(~c"my_macro_pr", %{env | function: {:foo, 1}}, metadata)

    assert [
             %{name: "my_macro_pub", origin: "MyModule", type: :macro}
           ] = expand(~c"my_macro_pu", %{env | function: {:foo, 1}}, metadata)

    assert [
             %{name: "my_guard_priv", origin: "MyModule", type: :macro}
           ] = expand(~c"my_guard_pr", %{env | function: {:foo, 1}}, metadata)

    assert [
             %{name: "my_guard_pub", origin: "MyModule", type: :macro}
           ] = expand(~c"my_guard_pu", %{env | function: {:foo, 1}}, metadata)

    assert [
             %{name: "my_delegated", origin: "MyModule", type: :function}
           ] = expand(~c"my_de", %{env | function: {:foo, 1}}, metadata)

    # locals are not available in module body
    assert [] == expand(~c"my_f", %{env | function: nil}, metadata)
  end

  test "complete remote funs from imported module" do
    env = %Env{
      module: MyModule,
      functions: [{OtherModule, [{:my_fun_other_pub, 1}]}]
    }

    metadata = %Metadata{
      mods_funs_to_positions: %{
        {OtherModule, nil, nil} => %ModFunInfo{type: :defmodule},
        {OtherModule, :my_fun_other_pub, 1} => %ModFunInfo{
          type: :def,
          params: [[{:some, [], nil}]]
        },
        {OtherModule, :my_fun_other_priv, 1} => %ModFunInfo{
          type: :defp,
          params: [[{:some, [], nil}]]
        }
      }
    }

    assert [
             %{name: "my_fun_other_pub", origin: "OtherModule", needed_import: nil}
           ] = expand(~c"my_f", env, metadata)
  end

  test "complete remote funs from imported module - needed import" do
    env = %Env{
      module: MyModule,
      functions: [{OtherModule, [{:my_fun_other_pub, 1}]}]
    }

    metadata = %Metadata{
      mods_funs_to_positions: %{
        {OtherModule, nil, nil} => %ModFunInfo{type: :defmodule},
        {OtherModule, :my_fun_other_pub, 1} => %ModFunInfo{
          type: :def,
          params: [[{:some, [], nil}]]
        },
        {OtherModule, :my_fun_other_pub, 2} => %ModFunInfo{
          type: :def,
          params: [[{:some, [], nil}]]
        },
        {OtherModule, :my_fun_other_priv, 1} => %ModFunInfo{
          type: :defp,
          params: [[{:some, [], nil}]]
        }
      }
    }

    assert [
             %{name: "my_fun_other_pub", origin: "OtherModule", needed_import: nil},
             %{
               name: "my_fun_other_pub",
               origin: "OtherModule",
               needed_import: {"OtherModule", {"my_fun_other_pub", 2}}
             }
           ] = expand(~c"my_f", env, metadata)
  end

  test "complete remote funs" do
    env = %Env{
      module: MyModule
    }

    metadata = %Metadata{
      mods_funs_to_positions: %{
        {Some.OtherModule, nil, nil} => %ModFunInfo{type: :defmodule},
        {Some.OtherModule, :my_fun_other_pub, 1} => %ModFunInfo{
          type: :def,
          params: [[{:some, [], nil}]]
        },
        {Some.OtherModule, :my_fun_other_priv, 1} => %ModFunInfo{
          type: :defp,
          params: [[{:some, [], nil}]]
        }
      }
    }

    assert [
             %{name: "my_fun_other_pub", origin: "Some.OtherModule"}
           ] = expand(~c"Some.OtherModule.my_f", env, metadata)
  end

  test "complete remote funs from aliased module" do
    env = %Env{
      module: MyModule,
      aliases: [{S, Some.OtherModule}]
    }

    metadata = %Metadata{
      mods_funs_to_positions: %{
        {Some.OtherModule, nil, nil} => %ModFunInfo{type: :defmodule},
        {Some.OtherModule, :my_fun_other_pub, 1} => %ModFunInfo{
          type: :def,
          params: [[{:some, [], nil}]]
        },
        {Some.OtherModule, :my_fun_other_priv, 1} => %ModFunInfo{
          type: :defp,
          params: [[{:some, [], nil}]]
        }
      }
    }

    assert [
             %{name: "my_fun_other_pub", origin: "Some.OtherModule"}
           ] = expand(~c"S.my_f", env, metadata)
  end

  test "complete remote funs from injected module" do
    env = %Env{
      module: MyModule,
      attributes: [
        %AttributeInfo{
          name: :get_module,
          type:
            {:call, {:atom, Application}, :get_env,
             [atom: :elixir_sense, atom: :an_attribute, atom: Some.OtherModule]}
        },
        %AttributeInfo{
          name: :compile_module,
          type:
            {:call, {:atom, Application}, :compile_env,
             [atom: :elixir_sense, atom: :an_attribute, atom: Some.OtherModule]}
        },
        %AttributeInfo{
          name: :fetch_module,
          type:
            {:call, {:atom, Application}, :fetch_env!,
             [atom: :elixir_sense, atom: :other_attribute]}
        },
        %AttributeInfo{
          name: :compile_bang_module,
          type:
            {:call, {:atom, Application}, :compile_env!,
             [atom: :elixir_sense, atom: :other_attribute]}
        }
      ]
    }

    metadata = %Metadata{
      mods_funs_to_positions: %{
        {Some.OtherModule, nil, nil} => %ModFunInfo{type: :defmodule},
        {Some.OtherModule, :my_fun_other_pub, 1} => %ModFunInfo{
          type: :def,
          params: [[{:some, [], nil}]]
        },
        {Some.OtherModule, :my_fun_other_priv, 1} => %ModFunInfo{
          type: :defp,
          params: [[{:some, [], nil}]]
        }
      }
    }

    assert [
             %{name: "my_fun_other_pub", origin: "Some.OtherModule"}
           ] = expand(~c"@get_module.my_f", env, metadata)

    assert [
             %{name: "my_fun_other_pub", origin: "Some.OtherModule"}
           ] = expand(~c"@compile_module.my_f", env, metadata)

    Application.put_env(:elixir_sense, :other_attribute, Some.OtherModule)

    assert [
             %{name: "my_fun_other_pub", origin: "Some.OtherModule"}
           ] = expand(~c"@fetch_module.my_f", env, metadata)

    assert [
             %{name: "my_fun_other_pub", origin: "Some.OtherModule"}
           ] = expand(~c"@compile_bang_module.my_f", env, metadata)
  after
    Application.delete_env(:elixir_sense, :other_attribute)
  end

  test "complete modules" do
    env = %Env{
      module: MyModule,
      aliases: [{MyAlias, Some.OtherModule.Nested}]
    }

    metadata = %Metadata{
      mods_funs_to_positions: %{
        {Some.OtherModule, nil, nil} => %ModFunInfo{type: :defmodule}
      }
    }

    assert [%{name: "Some", full_name: "Some", type: :module}] = expand(~c"Som", env, metadata)

    assert [%{name: "OtherModule", full_name: "Some.OtherModule", type: :module}] =
             expand(~c"Some.", env, metadata)

    assert [%{name: "MyAlias", full_name: "Some.OtherModule.Nested", type: :module}] =
             expand(~c"MyA", env, metadata)
  end

  test "alias rules" do
    env = %Env{
      module: MyModule,
      aliases: [{Keyword, MyKeyword}]
    }

    metadata = %Metadata{
      mods_funs_to_positions: %{
        {MyKeyword, nil, nil} => %ModFunInfo{type: :defmodule},
        {MyKeyword, :values1, 0} => %ModFunInfo{type: :def, params: [[]]}
      }
    }

    assert [
             %{
               name: "values1",
               type: :function,
               args: "",
               arity: 0,
               origin: "MyKeyword",
               spec: "",
               summary: ""
             }
           ] = expand(~c"Keyword.valu", env, metadata)

    assert [%{name: "values", type: :function, arity: 1, origin: "Keyword"}] =
             expand(~c"Elixir.Keyword.valu", env, metadata)
  end

  defmodule MyStruct do
    defstruct [:my_val, :some_map, :a_mod, :str, :unknown_str]
  end

  test "completion for struct names" do
    assert [%{name: "MyStruct"}] =
             expand(~c"%ElixirLS.Utils.CompletionEngineTest.MyStr")

    assert entries = expand(~c"%")
    assert entries |> Enum.any?(&(&1.name == "URI"))

    assert [%{name: "MyStruct"}] = expand(~c"%ElixirLS.Utils.CompletionEngineTest.")

    env = %Env{
      aliases: [{MyDate, Date}]
    }

    entries = expand(~c"%My", env, %Metadata{}, required_alias: true)
    assert Enum.any?(entries, &(&1.name == "MyDate" and &1.subtype == :struct))
  end

  if Version.match?(System.version(), ">= 1.14.0") do
    test "completion for struct names with __MODULE__" do
      assert [%{name: "__MODULE__"}] = expand(~c"%__MODU", %Env{module: Date.Range})
      assert [%{name: "Range"}] = expand(~c"%__MODULE__.Ra", %Env{module: Date})
    end
  end

  if Version.match?(System.version(), ">= 1.14.0") do
    test "completion for struct attributes" do
      assert [%{name: "@my_attr"}] =
               expand(~c"%@my", %Env{
                 attributes: [
                   %AttributeInfo{
                     name: :my_attr,
                     type: {:atom, Date}
                   }
                 ],
                 module: MyMod
               })

      assert [%{name: "Range"}] =
               expand(~c"%@my_attr.R", %Env{
                 attributes: [
                   %AttributeInfo{
                     name: :my_attr,
                     type: {:atom, Date}
                   }
                 ],
                 module: MyMod
               })
    end
  end

  test "completion for struct keys" do
    assert entries = expand(~c"%URI{") |> Enum.filter(& &1.type == :field)
    assert %{
      name: "path",
      type: :field,
      origin: "URI",
      subtype: :struct_field,
      call?: false,
      type_spec: "nil | binary()"
    } = entries |> Enum.find(& &1.name == "path")
    assert entries |> Enum.any?(& &1.name == "query")

    assert entries = expand(~c"%URI{path: \"foo\",") |> Enum.filter(& &1.type == :field)
    refute entries |> Enum.any?(& &1.name == "path")
    assert entries |> Enum.any?(& &1.name == "query")

    assert [%{name: "query"}] = expand(~c"%URI{path: \"foo\", que")
    assert [] == expand(~c"%URI{path: \"foo\", unkno")
    assert [] == expand(~c"%Unkown{path: \"foo\", unkno")

    metadata = %Metadata{
      types: %{
        {MyStruct, :t, 0} => %ElixirSense.Core.State.TypeInfo{
          name: :t,
          args: [[]],
          specs: ["@type t :: %MyStruct{some: integer}"],
          kind: :type
        }
      },
      structs: %{
        Elixir.MyStruct => %ElixirSense.Core.State.StructInfo{type: :defstruct, fields: [some: 1]}
      }
    }

    assert entries = expand(~c"%MyStruct{", %Env{}, metadata) |> Enum.filter(& &1.type == :field)
    assert %{
      name: "some",
      type: :field,
      origin: "MyStruct",
      subtype: :struct_field,
      call?: false,
      type_spec: nil
    } = entries |> Enum.find(& &1.name == "some")
  end

  test "completion for struct keys in update syntax" do
    assert entries = expand(~c"%URI{var | ") |> Enum.filter(& &1.type == :field)
    assert %{
      name: "path",
      type: :field,
      origin: "URI",
      subtype: :struct_field,
      call?: false,
      type_spec: "nil | binary()"
    } = entries |> Enum.find(& &1.name == "path")
    assert entries |> Enum.any?(& &1.name == "query")

    assert entries = expand(~c"%URI{var | path: \"foo\",") |> Enum.filter(& &1.type == :field)
    refute entries |> Enum.any?(& &1.name == "path")
    assert entries |> Enum.any?(& &1.name == "query")

    assert [%{name: "query"}] = expand(~c"%URI{var | path: \"foo\", que")
    assert [] == expand(~c"%URI{var | path: \"foo\", unkno")
    assert [] = expand(~c"%Unkown{var | path: \"foo\", unkno")

    metadata = %Metadata{
      types: %{
        {MyStruct, :t, 0} => %ElixirSense.Core.State.TypeInfo{
          name: :t,
          args: [[]],
          specs: ["@type t :: %MyStruct{some: integer}"],
          kind: :type
        }
      },
      structs: %{
        Elixir.MyStruct => %ElixirSense.Core.State.StructInfo{type: :defstruct, fields: [some: 1]}
      }
    }

    assert entries = expand(~c"%MyStruct{var | ", %Env{}, metadata) |> Enum.filter(& &1.type == :field)
    assert %{
      name: "some",
      type: :field,
      origin: "MyStruct",
      subtype: :struct_field,
      call?: false,
      type_spec: nil
    } = entries |> Enum.find(& &1.name == "some")
  end

  test "completion for map keys in update syntax" do
    env = %Env{
      vars: [
        %VarInfo{
          name: :map,
          version: 1,
          type:
            {:map,
             [
               some: {:atom, String},
               other: {:map, [asdf: 1], nil},
               another: {:struct, [], {:atom, MyStruct}, nil}
             ], nil}
        }
      ]
    }
    if Version.match?(System.version(), ">= 1.15.0") do
      assert entries = expand(~c"%{map | ", env) |> Enum.filter(& &1.type == :field)
      assert %{call?: false, name: "some", origin: nil, subtype: :map_field, type: :field, type_spec: nil} = entries |> Enum.find(& &1.name == "some")
      assert entries |> Enum.any?(& &1.name == "other")
    end

    assert entries = expand(~c"%{map | some: \"foo\",", env) |> Enum.filter(& &1.type == :field)
    refute entries |> Enum.any?(& &1.name == "some")
    assert entries |> Enum.any?(& &1.name == "other")

    assert [%{name: "other"}] = expand(~c"%{map | some: \"foo\", oth", env)
    assert [] = expand(~c"%{map | some: \"foo\", unkno", env)
    assert [] = expand(~c"%{unknown | some: \"foo\", unkno", env)
  end

  test "completion for struct var keys" do
    env = %Env{
      vars: [
        %VarInfo{
          name: :struct,
          version: 1,
          type:
            {:struct,
             [
               a_mod: {:atom, String},
               some_map: {:map, [asdf: 1], nil},
               str: {:struct, [], {:atom, MyStruct}, nil},
               unknown_str: {:struct, [abc: nil], nil, nil}
             ], {:atom, MyStruct}, nil}
        }
      ]
    }

    assert expand(~c"struct.my", env) ==
             [
               %{
                 name: "my_val",
                 subtype: :struct_field,
                 type: :field,
                 origin: "ElixirLS.Utils.CompletionEngineTest.MyStruct",
                 call?: true,
                 type_spec: nil
               }
             ]

    assert expand(~c"struct.some_m", env) ==
             [
               %{
                 name: "some_map",
                 subtype: :struct_field,
                 type: :field,
                 origin: "ElixirLS.Utils.CompletionEngineTest.MyStruct",
                 call?: true,
                 type_spec: nil
               }
             ]

    assert expand(~c"struct.some_map.", env) ==
             [
               %{
                 name: "asdf",
                 subtype: :map_key,
                 type: :field,
                 origin: nil,
                 call?: true,
                 type_spec: nil
               }
             ]

    assert expand(~c"struct.str.", env) ==
             [
               %{
                 name: "__struct__",
                 subtype: :struct_field,
                 type: :field,
                 origin: "ElixirLS.Utils.CompletionEngineTest.MyStruct",
                 call?: true,
                 type_spec: "ElixirLS.Utils.CompletionEngineTest.MyStruct"
               },
               %{
                 name: "a_mod",
                 subtype: :struct_field,
                 type: :field,
                 origin: "ElixirLS.Utils.CompletionEngineTest.MyStruct",
                 call?: true,
                 type_spec: nil
               },
               %{
                 name: "my_val",
                 subtype: :struct_field,
                 type: :field,
                 origin: "ElixirLS.Utils.CompletionEngineTest.MyStruct",
                 call?: true,
                 type_spec: nil
               },
               %{
                 name: "some_map",
                 subtype: :struct_field,
                 type: :field,
                 origin: "ElixirLS.Utils.CompletionEngineTest.MyStruct",
                 call?: true,
                 type_spec: nil
               },
               %{
                 name: "str",
                 subtype: :struct_field,
                 type: :field,
                 origin: "ElixirLS.Utils.CompletionEngineTest.MyStruct",
                 call?: true,
                 type_spec: nil
               },
               %{
                 name: "unknown_str",
                 subtype: :struct_field,
                 type: :field,
                 origin: "ElixirLS.Utils.CompletionEngineTest.MyStruct",
                 call?: true,
                 type_spec: nil
               }
             ]

    assert expand(~c"struct.str", env) ==
             [
               %{
                 name: "str",
                 subtype: :struct_field,
                 type: :field,
                 origin: "ElixirLS.Utils.CompletionEngineTest.MyStruct",
                 call?: true,
                 type_spec: nil
               }
             ]

    assert expand(~c"struct.unknown_str.", env) ==
             [
               %{
                 call?: true,
                 name: "__struct__",
                 origin: nil,
                 subtype: :struct_field,
                 type: :field,
                 type_spec: "atom()"
               },
               %{
                 call?: true,
                 name: "abc",
                 origin: nil,
                 subtype: :struct_field,
                 type: :field,
                 type_spec: nil
               }
             ]
  end

  test "completion for bitstring modifiers" do
    assert entries = expand('<<foo::') |> Enum.filter(& &1[:type] == :bitstring_option)
    assert Enum.any?(entries, & &1.name == "integer")
    assert Enum.any?(entries, & &1.name == "size" and &1.arity == 1)

    assert [%{name: "integer", type: :bitstring_option}] = expand('<<foo::int')

    assert entries = expand('<<foo::integer-') |> Enum.filter(& &1[:type] == :bitstring_option)
    refute Enum.any?(entries, & &1.name == "integer")
    assert Enum.any?(entries, & &1.name == "little")
    assert Enum.any?(entries, & &1.name == "size" and &1.arity == 1)

    assert entries = expand('<<foo::integer-little-') |> Enum.filter(& &1[:type] == :bitstring_option)
    refute Enum.any?(entries, & &1.name == "integer")
    refute Enum.any?(entries, & &1.name == "little")
    assert Enum.any?(entries, & &1.name == "size" and &1.arity == 1)
  end

  test "completion for aliases in special forms" do
    assert entries = expand(~c"alias ")
    assert Enum.any?(entries, & &1.name == "Atom")
    refute Enum.any?(entries, & &1.name == "is_atom")

    assert entries = expand(~c"alias Date.")
    assert Enum.any?(entries, & &1.name == "Range")
  end

  test "ignore invalid Elixir module literals" do
    defmodule :"ElixirSense.Providers.Suggestion.CompleteTest.Unicodé", do: nil
    assert expand(~c"ElixirLS.Utils.CompletionEngineTest.Unicod") == []
  after
    :code.purge(:"ElixirLS.Utils.CompletionEngineTest.Unicodé")
    :code.delete(:"ElixirLS.Utils.CompletionEngineTest.Unicodé")
  end

  test "complete built in functions on non local calls" do
    assert [] = expand(~c"module_")
    assert [] = expand(~c"__in")

    assert [] = expand(~c"Elixir.mo")
    assert [] = expand(~c"Elixir.__in")

    assert [
             %{
               name: "module_info",
               type: :function,
               arity: 0,
               spec:
                 "@spec module_info :: [{:module | :attributes | :compile | :exports | :md5 | :native, term}]"
             },
             %{
               name: "module_info",
               type: :function,
               arity: 1,
               spec:
                 "@spec module_info(:module) :: atom\n@spec module_info(:attributes | :compile) :: [{atom, term}]\n@spec module_info(:md5) :: binary\n@spec module_info(:exports | :functions | :nifs) :: [{atom, non_neg_integer}]\n@spec module_info(:native) :: boolean"
             }
           ] = expand(~c"String.mo")

    assert [
             %{
               name: "__info__",
               type: :function,
               spec:
                 "@spec __info__(:attributes) :: keyword()\n@spec __info__(:compile) :: [term()]\n@spec __info__(:functions) :: [{atom, non_neg_integer}]\n@spec __info__(:macros) :: [{atom, non_neg_integer}]\n@spec __info__(:md5) :: binary()\n@spec __info__(:module) :: module()"
             }
           ] = expand(~c"String.__in")

    assert [
             %{
               name: "module_info",
               type: :function,
               arity: 0,
               spec:
                 "@spec module_info :: [{:module | :attributes | :compile | :exports | :md5 | :native, term}]"
             },
             %{
               name: "module_info",
               type: :function,
               arity: 1,
               spec:
                 "@spec module_info(:module) :: atom\n@spec module_info(:attributes | :compile) :: [{atom, term}]\n@spec module_info(:md5) :: binary\n@spec module_info(:exports | :functions | :nifs) :: [{atom, non_neg_integer}]\n@spec module_info(:native) :: boolean"
             }
           ] = expand(~c":ets.module_")

    assert [] = expand(~c":ets.__in")

    env = %Env{
      module: MyModule,
      aliases: [{MyAlias, Some.OtherModule.Nested}]
    }

    metadata = %Metadata{
      mods_funs_to_positions: %{
        {MyModule, nil, nil} => %ModFunInfo{type: :defmodule},
        {MyModule, :module_info, 0} => %ModFunInfo{type: :def, params: [[]]},
        {MyModule, :module_info, 1} => %ModFunInfo{type: :def, params: [[{:atom, [], nil}]]},
        {MyModule, :__info__, 1} => %ModFunInfo{type: :def, params: [[{:atom, [], nil}]]}
      }
    }

    assert [] = expand(~c"module_", env, metadata)
    assert [] = expand(~c"__in", env, metadata)

    assert [
             %{
               name: "module_info",
               type: :function,
               arity: 0,
               spec:
                 "@spec module_info :: [{:module | :attributes | :compile | :exports | :md5 | :native, term}]"
             },
             %{
               name: "module_info",
               type: :function,
               arity: 1,
               spec:
                 "@spec module_info(:module) :: atom\n@spec module_info(:attributes | :compile) :: [{atom, term}]\n@spec module_info(:md5) :: binary\n@spec module_info(:exports | :functions | :nifs) :: [{atom, non_neg_integer}]\n@spec module_info(:native) :: boolean"
             }
           ] = expand(~c"MyModule.mo", env, metadata)

    assert [
             %{
               name: "__info__",
               type: :function,
               spec:
                 "@spec __info__(:attributes) :: keyword()\n@spec __info__(:compile) :: [term()]\n@spec __info__(:functions) :: [{atom, non_neg_integer}]\n@spec __info__(:macros) :: [{atom, non_neg_integer}]\n@spec __info__(:md5) :: binary()\n@spec __info__(:module) :: module()"
             }
           ] = expand(~c"MyModule.__in", env, metadata)
  end

  test "complete build in behaviour functions" do
    assert [] = expand(~c"Elixir.beh")

    assert [
             %{
               name: "behaviour_info",
               type: :function,
               arity: 1,
               spec:
                 "@spec behaviour_info(:callbacks | :optional_callbacks) :: [{atom, non_neg_integer}]"
             }
           ] = expand(~c":gen_server.beh")

    assert [
             %{
               name: "behaviour_info",
               type: :function,
               arity: 1,
               spec:
                 "@spec behaviour_info(:callbacks | :optional_callbacks) :: [{atom, non_neg_integer}]"
             }
           ] = expand(~c"GenServer.beh")
  end

  test "complete build in protocol functions" do
    assert [] = expand(~c"Elixir.__pr")

    assert [
             %{
               name: "__protocol__",
               type: :function,
               arity: 1,
               spec:
                 "@spec __protocol__(:module) :: module\n@spec __protocol__(:functions) :: [{atom, non_neg_integer}]\n@spec __protocol__(:consolidated?) :: boolean\n@spec __protocol__(:impls) :: :not_consolidated | {:consolidated, [module]}"
             }
           ] = expand(~c"Enumerable.__pro")

    assert [_, _] = expand(~c"Enumerable.imp")

    assert [
             %{
               name: "impl_for!",
               type: :function,
               arity: 1,
               spec: "@spec impl_for!(term) :: atom"
             }
           ] = expand(~c"Enumerable.impl_for!")
  end

  test "complete build in protocol implementation functions" do
    assert [] = expand(~c"Elixir.__im")

    assert [
             %{
               name: "__impl__",
               type: :function,
               arity: 1,
               spec: "@spec __impl__(:for | :target | :protocol) :: module"
             }
           ] = expand(~c"Enumerable.List.__im")
  end

  test "complete build in struct functions" do
    assert [] = expand(~c"Elixir.__str")

    assert [
             %{
               name: "__struct__",
               type: :function,
               arity: 0,
               spec:
                 "@spec __struct__() :: %{required(:__struct__) => module, optional(any) => any}"
             },
             %{
               name: "__struct__",
               type: :function,
               arity: 1,
               spec:
                 "@spec __struct__(keyword) :: %{required(:__struct__) => module, optional(any) => any}"
             }
           ] = expand(~c"ElixirLS.Utils.Example.ModuleWithStruct.__str")
  end

  test "complete build in exception functions" do
    assert [] = expand(~c"Elixir.mes")

    assert [
             %{
               name: "message",
               type: :function,
               arity: 1,
               spec: "@callback message(t()) :: String.t()"
             }
           ] = expand(~c"ArgumentError.mes")

    assert [] = expand(~c"Elixir.exce")

    assert [
             %{
               name: "exception",
               type: :function,
               arity: 1,
               spec: "@callback exception(term()) :: t()"
             }
           ] = expand(~c"ArgumentError.exce")

    assert [] = expand(~c"Elixir.bla")
  end

  if System.otp_release() |> String.to_integer() >= 23 do
    test "complete build in :erlang functions" do
      assert [
               %{arity: 2, name: "open_port", origin: ":erlang"},
               %{
                 arity: 2,
                 name: "or",
                 spec: "@spec boolean() or boolean() :: boolean()",
                 type: :function,
                 args: "boolean, boolean",
                 origin: ":erlang",
                 summary: ""
               },
               %{
                 args: "term, term",
                 arity: 2,
                 name: "orelse",
                 origin: ":erlang",
                 spec: "",
                 summary: "",
                 type: :function
               }
             ] = expand(~c":erlang.or")

      assert [
               %{
                 arity: 2,
                 name: "and",
                 spec: "@spec boolean() and boolean() :: boolean()",
                 type: :function,
                 args: "boolean, boolean",
                 origin: ":erlang",
                 summary: ""
               },
               %{
                 args: "term, term",
                 arity: 2,
                 name: "andalso",
                 origin: ":erlang",
                 spec: "",
                 summary: "",
                 type: :function
               },
               %{arity: 2, name: "append", origin: ":erlang"},
               %{arity: 2, name: "append_element", origin: ":erlang"}
             ] = expand(~c":erlang.and")
    end
  end

  test "provide doc and specs for erlang functions" do
    assert [
             %{
               arity: 1,
               name: "whereis",
               origin: ":erlang",
               spec: "@spec whereis(regName) :: pid() | port() | :undefined when regName: atom()",
               type: :function
             }
           ] = expand(~c":erlang.where")

    assert [
             %{
               arity: 1,
               name: "cancel_timer",
               spec: "@spec cancel_timer(timerRef) :: result" <> _,
               type: :function,
               args: "timerRef",
               origin: ":erlang",
               summary: summary1,
               metadata: meta1
             },
             %{
               arity: 2,
               name: "cancel_timer",
               spec: "@spec cancel_timer(timerRef, options) :: result | :ok" <> _,
               type: :function,
               args: "timerRef, options",
               origin: ":erlang",
               summary: summary2
             }
           ] = expand(~c":erlang.cancel_time")

    if System.otp_release() |> String.to_integer() >= 23 do
      assert "Cancels a timer that has been created by" <> _ = summary2

      if System.otp_release() |> String.to_integer() >= 27 do
        assert "" == summary1
        assert %{group: :time, equiv: "erlang:cancel_timer(TimerRef, [])", app: :erts} == meta1
      else
        assert "Cancels a timer\\." <> _ = summary1
      end
    end
  end

  test "provide doc and specs for erlang functions with args from typespec" do
    if String.to_integer(System.otp_release()) >= 26 do
      assert [
               %{
                 name: "handle_call",
                 args_list: ["call", "from", "state"]
               },
               %{
                 name: "handle_cast",
                 args_list: ["tuple", "state"]
               },
               %{
                 name: "handle_info",
                 args_list: ["term", "state"]
               }
             ] = expand(~c":pg.handle_")
    else
      if String.to_integer(System.otp_release()) >= 23 do
        assert [_, _, _] = expand(~c":pg.handle_")
      else
        assert [] = expand(~c":pg.handle_")
      end
    end
  end

  test "complete after ! operator" do
    assert [%{name: "is_binary"}] = expand(~c"!is_bina")
  end

  test "correctly find subtype and doc for modules that have submodule" do
    assert [
             %{
               name: "File",
               full_name: "File",
               type: :module,
               metadata: %{},
               subtype: nil,
               summary: "This module contains functions to manipulate files."
             }
           ] = expand(~c"Fi") |> Enum.filter(&(&1.name == "File"))
  end

  test "complete only struct modules after %" do
    assert list = expand(~c"%")
    refute Enum.any?(list, &(&1.type != :module))
    assert Enum.any?(list, &(&1.name == "ArithmeticError"))
    assert Enum.any?(list, &(&1.name == "URI"))
    refute Enum.any?(list, &(&1.name == "File"))
    refute Enum.any?(list, &(&1.subtype not in [:struct, :exception]))

    assert [_ | _] = expand(~c"%Fi")
    assert list = expand(~c"%File.")
    assert Enum.any?(list, &(&1.name == "CopyError"))
    refute Enum.any?(list, &(&1.type != :module))
    refute Enum.any?(list, &(&1.subtype not in [:struct, :exception]))
  end

  test "complete modules and local funs after &" do
    assert list = expand(~c"&")
    assert Enum.any?(list, &(&1.type == :module))
    assert Enum.any?(list, &(&1.type == :function))
    refute Enum.any?(list, &(&1.type not in [:function, :module, :macro]))
  end

  test "complete Kernel.SpecialForms macros with fixed argument list" do
    assert [%{args_list: ["term"]}] = expand(~c"Kernel.SpecialForms.fn")
  end

  test "macros from not required modules should add needed_require" do
    assert [
             %{
               name: "info",
               arity: 1,
               type: :macro,
               origin: "Logger",
               needed_require: "Logger",
               visibility: :public
             },
             _
           ] = expand(~c"Logger.inf")

    assert [
             %{
               name: "info",
               arity: 1,
               type: :macro,
               origin: "Logger",
               needed_require: nil,
               visibility: :public
             },
             _
           ] = expand(~c"Logger.inf", %Env{requires: [Logger]})
  end

  test "macros from not required metadata modules should add needed_require" do
    macro_info = %ElixirSense.Core.State.ModFunInfo{
      type: :defmacro,
      params: [[:_]]
    }

    metadata = %Metadata{
      mods_funs_to_positions: %{
        {MyModule, nil, nil} => %ElixirSense.Core.State.ModFunInfo{},
        {MyModule, :info, 1} => macro_info
      }
    }

    assert [
             %{
               name: "info",
               arity: 1,
               type: :macro,
               origin: "MyModule",
               needed_require: "MyModule",
               visibility: :public
             }
           ] = expand(~c"MyModule.inf", %Env{requires: []}, metadata)

    assert [
             %{
               name: "info",
               arity: 1,
               type: :macro,
               origin: "MyModule",
               needed_require: nil,
               visibility: :public
             }
           ] = expand(~c"MyModule.inf", %Env{requires: [MyModule]}, metadata)
  end

  test "macros from Kernel.SpecialForms should not add needed_require" do
    assert [
             %{
               name: "unquote",
               arity: 1,
               type: :macro,
               origin: "Kernel.SpecialForms",
               needed_require: nil,
               visibility: :public
             },
             _
           ] = expand(~c"unquote", %Env{requires: []})
  end

  test "macros from the same module should not add needed_require" do
    macro_info = %ElixirSense.Core.State.ModFunInfo{
      type: :defmacro,
      params: [[:_]]
    }

    metadata = %Metadata{
      mods_funs_to_positions: %{
        {MyModule, nil, nil} => %ElixirSense.Core.State.ModFunInfo{},
        {MyModule, :info, 1} => macro_info
      }
    }

    assert [
             %{
               name: "info",
               arity: 1,
               type: :macro,
               origin: "MyModule",
               needed_require: nil,
               visibility: :public
             }
           ] =
             expand(~c"inf", %Env{requires: [], module: MyModule, function: {:foo, 1}}, metadata)
  end

  if Version.match?(System.version(), ">= 1.14.0") do
    test "Application.compile_env classified as macro" do
      assert [
               %{
                 name: "compile_env",
                 arity: 2,
                 type: :macro,
                 origin: "Application",
                 needed_require: "Application"
               },
               %{
                 name: "compile_env",
                 arity: 3,
                 type: :macro,
                 origin: "Application",
                 needed_require: "Application"
               },
               %{
                 name: "compile_env",
                 arity: 4,
                 type: :function,
                 origin: "Application",
                 needed_require: nil
               },
               %{
                 name: "compile_env!",
                 arity: 2,
                 type: :macro,
                 origin: "Application",
                 needed_require: "Application"
               },
               %{
                 name: "compile_env!",
                 arity: 3,
                 type: :function,
                 origin: "Application",
                 needed_require: nil
               }
             ] = expand(~c"Application.compile_e")
    end
  end
end
