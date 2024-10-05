defmodule ElixirLS.Utils.MinimumVersion do
  def check_otp_version do
    otp_release = String.to_integer(System.otp_release())

    if otp_release < 22 do
      {:error,
       "Erlang OTP releases below 22 are not supported (Currently running OTP #{otp_release})"}
    else
      if otp_release == 26 and is_windows() do
        {:error,
         "Erlang OTP 26.0 and 26.1 have critical bugs on Windows. Please make sure OTP 26.2 or greater is installed"}
      else
        :ok
      end
    end
  end

  def check_elixir_version do
    if Version.match?(System.version(), ">= 1.13.0") do
      if Regex.match?(~r/-/, System.version()) do
        {:error,
         "Only official elixir releases are supported. (Currently running v#{System.version()})"}
      else
        :ok
      end
    else
      {:error,
       "Elixir versions below 1.13.0 are not supported. (Currently running v#{System.version()})"}
    end
  end

  def is_windows() do
    case :os.type() do
      {:win32, _} -> true
      _ -> false
    end
  end
end
