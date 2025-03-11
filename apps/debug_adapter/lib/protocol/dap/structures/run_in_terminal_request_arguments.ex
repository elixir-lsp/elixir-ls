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
  * env: Environment key-value pairs that are added to or removed from the default environment.
  * title: Title of the terminal.
  * cwd: Working directory for the command. For non-empty, valid paths this typically results in execution of a change directory command.
  * kind: What kind of terminal to launch. Defaults to `integrated` if not specified.
  * args_can_be_interpreted_by_shell: This property should only be set if the corresponding capability `supportsArgsCanBeInterpretedByShell` is true. If the client uses an intermediary shell to launch the application, then the client must not attempt to escape characters with special meanings for the shell. The user is fully responsible for escaping as needed and that arguments using special characters may not be portable across shells.
  """
  @derive JasonV.Encoder
  typedstruct do
    field :args, list(String.t()), enforce: true
    field :env, %{String.t() => String.t() | nil}
    field :title, String.t()
    field :cwd, String.t(), enforce: true
    field :kind, String.t()
    field :args_can_be_interpreted_by_shell, boolean()
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      {"args", :args} => list(str()),
      optional({"env", :env}) => map(keys: str(), values: oneof([str(), nil])),
      optional({"title", :title}) => str(),
      {"cwd", :cwd} => str(),
      optional({"kind", :kind}) => oneof(["integrated", "external"]),
      optional({"argsCanBeInterpretedByShell", :args_can_be_interpreted_by_shell}) => bool(),
    })
  end
end
