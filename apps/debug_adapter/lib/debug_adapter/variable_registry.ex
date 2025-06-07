defmodule ElixirLS.DebugAdapter.VariableRegistry do
  @moduledoc """
  Process-local registry for managing variable and frame references.

  This module provides a way to manage DAP object IDs without needing
  to call back to the main GenServer, enabling better async workflows.
  """

  alias ElixirLS.DebugAdapter.{IdManager, Variables}

  defstruct var_ids_to_vars: %{},
            vars_to_var_ids: %{},
            frame_ids_to_frames: %{},
            frames_to_frame_ids: %{}

  @type t :: %__MODULE__{
          var_ids_to_vars: %{integer() => any()},
          vars_to_var_ids: %{any() => integer()},
          frame_ids_to_frames: %{integer() => any()},
          frames_to_frame_ids: %{any() => integer()}
        }

  @doc """
  Ensures a variable has an ID, creating one if necessary.
  Returns {registry, var_id}.
  """
  def ensure_var_id(registry = %__MODULE__{}, var) do
    case registry.vars_to_var_ids do
      %{^var => var_id} ->
        {registry, var_id}

      _ ->
        id = IdManager.next_id()

        registry = %{
          registry
          | var_ids_to_vars: Map.put(registry.var_ids_to_vars, id, var),
            vars_to_var_ids: Map.put(registry.vars_to_var_ids, var, id)
        }

        {registry, id}
    end
  end

  @doc """
  Ensures a frame has an ID, creating one if necessary.
  Returns {registry, frame_id}.
  """
  def ensure_frame_id(registry = %__MODULE__{}, frame) do
    case registry.frames_to_frame_ids do
      %{^frame => frame_id} ->
        {registry, frame_id}

      _ ->
        id = IdManager.next_id()

        registry = %{
          registry
          | frame_ids_to_frames: Map.put(registry.frame_ids_to_frames, id, frame),
            frames_to_frame_ids: Map.put(registry.frames_to_frame_ids, frame, id)
        }

        {registry, id}
    end
  end

  @doc """
  Gets a variable reference for a value, returning 0 if no children.
  This is the async-friendly version that doesn't require GenServer calls.
  """
  def get_variable_reference(registry = %__MODULE__{}, value) do
    child_type = Variables.child_type(value)

    case child_type do
      nil -> {registry, 0}
      _ -> ensure_var_id(registry, value)
    end
  end

  @doc """
  Finds a variable by its ID.
  Returns {:ok, var} or :error.
  """
  def find_var(registry = %__MODULE__{}, var_id) do
    Map.fetch(registry.var_ids_to_vars, var_id)
  end

  @doc """
  Finds a frame by its ID.
  Returns {:ok, frame} or :error.
  """
  def find_frame(registry = %__MODULE__{}, frame_id) do
    Map.fetch(registry.frame_ids_to_frames, frame_id)
  end

  @doc """
  Merges another registry into this one.
  Useful when combining results from async operations.
  """
  def merge(registry1 = %__MODULE__{}, registry2 = %__MODULE__{}) do
    %__MODULE__{
      var_ids_to_vars: Map.merge(registry1.var_ids_to_vars, registry2.var_ids_to_vars),
      vars_to_var_ids: Map.merge(registry1.vars_to_var_ids, registry2.vars_to_var_ids),
      frame_ids_to_frames:
        Map.merge(registry1.frame_ids_to_frames, registry2.frame_ids_to_frames),
      frames_to_frame_ids: Map.merge(registry1.frames_to_frame_ids, registry2.frames_to_frame_ids)
    }
  end
end
