# codegen: do not edit
defmodule GenLSP.Structures.WorkspaceDiagnosticParams do
  @moduledoc """
  Parameters of the workspace diagnostic request.

  @since 3.17.0
  """

  import SchematicV, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * identifier: The additional identifier provided during registration.
  * previous_result_ids: The currently known diagnostic reports with their
    previous result ids.
  * work_done_token: An optional token that a server can use to report work done progress.
  * partial_result_token: An optional token that a server can use to report partial results (e.g. streaming) to
    the client.
  """

  typedstruct do
    field(:identifier, String.t())
    field(:previous_result_ids, list(GenLSP.Structures.PreviousResultId.t()), enforce: true)
    field(:work_done_token, GenLSP.TypeAlias.ProgressToken.t())
    field(:partial_result_token, GenLSP.TypeAlias.ProgressToken.t())
  end

  @doc false
  @spec schematic() :: SchematicV.t()
  def schematic() do
    schema(__MODULE__, %{
      optional({"identifier", :identifier}) => str(),
      {"previousResultIds", :previous_result_ids} =>
        list(GenLSP.Structures.PreviousResultId.schematic()),
      optional({"workDoneToken", :work_done_token}) => GenLSP.TypeAlias.ProgressToken.schematic(),
      optional({"partialResultToken", :partial_result_token}) =>
        GenLSP.TypeAlias.ProgressToken.schematic()
    })
  end
end
