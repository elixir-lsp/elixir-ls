defmodule ElixirLS.Utils.MinimumVersion do
  def check_otp_version do
    otp_release = String.to_integer(System.otp_release())

    if otp_release < 22 do
      {:error,
       "Erlang OTP releases below 22 are not supported (Currently running OTP #{otp_release})"}
    else
      :ok
    end
  end

  def check_elixir_version do
    if Version.match?(System.version(), ">= 1.13.0") do
      :ok
    else
      {:error,
       "Elixir versions below 1.13.0 are not supported. (Currently running v#{System.version()})"}
    end
  end
end
