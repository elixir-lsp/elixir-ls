defmodule ModuleWithPrivateTypes do
  @opaque opaque_t :: atom
  @typep typep_t :: atom
  @type type_t :: atom

  @spec just_to_use_typep(typep_t) :: typep_t
  def just_to_use_typep(t) do
    t
  end
end
