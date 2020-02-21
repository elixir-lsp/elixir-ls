defmodule Eels.LSClient do
  @moduledoc """
  Language server client. This receives commands from the language server and executes
  them. There is a big trust relationship between this VM and the LS VM so we allow
  the server to do a lot; our main function is to separate namespaces and BEAM versions,
  not to act as a trust boundary.
  """
  use GenServer
end
