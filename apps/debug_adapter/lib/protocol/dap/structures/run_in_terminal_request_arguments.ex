# codegen: do not edit
defmodule GenDAP.Structures.RunInTerminalRequestArguments do
  @moduledoc """
  Arguments for `runInTerminal` request.
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields
  
  * args: List of arguments. The first argument is the command to run.
  * args_can_be_interpreted_by_shell: This property should only be set if the corresponding capability `supportsArgsCanBeInterpretedByShell` is true. If the client uses an intermediary shell to launch the application, then the client must not attempt to escape characters with special meanings for the shell. The user is fully responsible for escaping as needed and that arguments using special characters may not be portable across shells.
  * cwd: Working directory for the command. For non-empty, valid paths this typically results in execution of a change directory command.
  * env: Environment key-value pairs that are added to or removed from the default environment.
  * kind: What kind of terminal to launch. Defaults to `integrated` if not specified.
  * title: Title of the terminal.
  """
  @derive JasonV.Encoder
  typedstruct do
    @typedoc "A type defining DAP structure RunInTerminalRequestArguments"
    field :args, list(String.t()), enforce: true
    field :args_can_be_interpreted_by_shell, boolean()
    field :cwd, String.t(), enforce: true
    field :env, %{optional(String.t()) => String.t() | nil}
    field :kind, String.t()
    field :title, String.t()
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      {"args", :args} => list(str()),
      optional({"argsCanBeInterpretedByShell", :args_can_be_interpreted_by_shell}) => bool(),
      {"cwd", :cwd} => str(),
      optional({"env", :env}) => map(keys: str(), values: oneof([str(), nil])),
      optional({"kind", :kind}) => oneof(["integrated", "external"]),
      optional({"title", :title}) => str(),
    })
  end
end
