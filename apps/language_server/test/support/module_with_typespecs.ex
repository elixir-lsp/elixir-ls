defmodule ElixirSenseExample.ModuleWithTypespecs do
  defmodule Remote do
    @typedoc "Remote type"
    @type remote_t :: atom

    @typedoc "Remote type with params"
    @type remote_t(a, b) :: {a, b}

    @typedoc "Remote list type"
    @type remote_list_t :: [remote_t]
    @opaque some_opaque_options_t :: {:atom_opt_1, integer} | {:atom_opt_2, integer}
    @type remote_option_t :: {:remote_option_1, remote_t} | {:remote_option_2, remote_list_t}
  end

  defmodule OtherRemote do
    @type other :: Remote.remote_option_t()
  end

  defmodule Local do
    alias Remote, as: R

    @typep private_t :: atom

    @typedoc "Local opaque type"
    @opaque opaque_t :: atom

    @typedoc "Local type"
    @type local_t :: atom

    @typedoc "Local type with params"
    @type local_t(a, b) :: {a, b}

    @typedoc "Local union type"
    @type union_t :: atom | integer

    @typedoc "Local list type"
    @type list_t :: [:trace | :log]

    @typedoc "Local type with large spec"
    @type large_t :: pid | port | (registered_name :: atom) | {registered_name :: atom, node}

    @typedoc "Remote type from aliased module"
    @type remote_aliased_t :: R.remote_t() | R.remote_list_t()

    @type tuple_opt_t :: {:opt_name, :opt_value}

    @typedoc "Local keyword-value type"
    @type option_t ::
            {:local_o, local_t}
            | {:local_with_params_o, local_t(atom, integer)}
            | {:union_o, union_t}
            | {:inline_union_o, :a | :b}
            | {:list_o, list_t}
            | {:inline_list_o, [:trace | :log]}
            | {:basic_o, pid}
            | {:basic_with_params_o, nonempty_list(atom)}
            | {:builtin_o, keyword}
            | {:builtin_with_params_o, keyword(term)}
            | {:remote_o, Remote.remote_t()}
            | {:remote_with_params_o, Remote.remote_t(atom, integer)}
            | {:remote_aliased_o, remote_aliased_t}
            | {:remote_aliased_inline_o, R.remote_t()}
            | {:private_o, private_t}
            | {:opaque_o, opaque_t}
            | {:non_existent_o, Remote.non_existent()}
            | {:large_o, large_t}

    @typedoc "Extra option"
    @type extra_option_t :: {:option_1, atom} | {:option_2, integer}

    @typedoc "Options"
    @type options_t :: [option_t]

    @typedoc "Option | Extra option"
    @type option_or_extra_option_t ::
            {:option_1, boolean} | {:option_2, timeout} | Remote.remote_option_t()

    @type extra_option_1_t :: extra_option_t

    @type atom_opt_t :: :atom_opt

    @opaque some_opaque_options_t :: {:atom_opt_1, integer} | {:atom_opt_2, integer}

    @spec func_with_options(options_t) :: any
    def func_with_options(options) do
      options
    end

    @spec func_with_union_of_options([option_t | extra_option_t]) :: any
    def func_with_union_of_options(options) do
      options
    end

    @spec func_with_union_of_options_as_type([option_or_extra_option_t]) :: any
    def func_with_union_of_options_as_type(options) do
      options
    end

    @spec func_with_union_of_options_inline([{:option_1, atom} | {:option_2, integer} | option_t]) ::
            any
    def func_with_union_of_options_inline(options) do
      options
    end

    @spec func_with_named_options(options :: options_t) :: any
    def func_with_named_options(options) do
      options
    end

    @spec func_with_options_as_inline_list([{:local_o, local_t} | {:builtin_o, keyword}]) :: any
    def func_with_options_as_inline_list(options) do
      options
    end

    @spec func_with_option_var_defined_in_when([opt]) :: any when opt: option_t
    def func_with_option_var_defined_in_when(options) do
      options
    end

    @spec func_with_options_var_defined_in_when(opts) :: any when opts: [option_t]
    def func_with_options_var_defined_in_when(options) do
      options
    end

    @spec func_with_one_option([{:option_1, integer}]) :: any
    def func_with_one_option(options) do
      options
    end

    @spec fun_without_options([integer]) :: integer
    def fun_without_options(a), do: length(a)

    @spec fun_with_atom_option([:option_name]) :: any
    def fun_with_atom_option(a), do: a

    @spec fun_with_atom_option_in_when(opts) :: any when opts: [:option_name]
    def fun_with_atom_option_in_when(a), do: a

    @spec fun_with_recursive_remote_type_option([OtherRemote.other()]) :: any
    def fun_with_recursive_remote_type_option(a), do: a

    @spec fun_with_recursive_user_type_option([extra_option_1_t]) :: any
    def fun_with_recursive_user_type_option(a), do: a

    @spec fun_with_tuple_option_in_when(opt) :: any when opt: [tuple_opt_t]
    def fun_with_tuple_option_in_when(a), do: a

    @spec fun_with_tuple_option([tuple_opt_t]) :: any
    def fun_with_tuple_option(a), do: a

    @spec fun_with_atom_user_type_option_in_when(opt) :: any when opt: [atom_opt_t]
    def fun_with_atom_user_type_option_in_when(a), do: a

    @spec fun_with_atom_user_type_option([atom_opt_t]) :: any
    def fun_with_atom_user_type_option(a), do: a

    @spec fun_with_list_of_lists([opt]) :: any when opt: [tuple_opt_t]
    def fun_with_list_of_lists(a), do: a

    @spec fun_with_recursive_type(opt) :: any when opt: [term :: opt]
    def fun_with_recursive_type(a), do: a

    @spec fun_with_multiple_specs(nil) :: any
    @spec fun_with_multiple_specs([tuple_opt_t]) :: any
    def fun_with_multiple_specs(a), do: a

    @spec fun_with_multiple_specs_when(nil) :: any
    @spec fun_with_multiple_specs_when([opts]) :: any when opts: tuple_opt_t
    def fun_with_multiple_specs_when(a), do: a

    @spec fun_with_local_opaque([some_opaque_options_t]) :: any
    def fun_with_local_opaque(a), do: a

    @spec fun_with_remote_opaque([Remote.some_opaque_options_t()]) :: any
    def fun_with_remote_opaque(a), do: a

    @spec func_with_edoc_options([{:edoc_t, :docsh_edoc_xmerl.xml_element_content()}]) :: any
    def func_with_edoc_options(options) do
      options
    end

    @spec func_with_erlang_type_options([{:erlang_t, :erlang.time_unit()}]) :: any
    def func_with_erlang_type_options(options) do
      options
    end

    @spec macro_with_options(options_t) :: Macro.t()
    defmacro macro_with_options(options) do
      IO.inspect(options)
      {:asd, [], nil}
    end
  end
end
