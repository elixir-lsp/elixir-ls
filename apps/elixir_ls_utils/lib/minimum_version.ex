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
    if Version.match?(System.version(), ">= 1.12.3") do
      otp_release = String.to_integer(System.otp_release())

      if Version.match?(System.version(), "< 1.13.0") and otp_release == 24 do
        # see https://github.com/elixir-lang/elixir/pull/11158#issuecomment-981583298
        {:error,
         "Elixir 1.12 is not supported on OTP 24. (Currently running v#{System.version()} on OTP #{otp_release})"}
      else
        :ok
      end
    else
      {:error,
       "Elixir versions below 1.12.3 are not supported. (Currently running v#{System.version()})"}
    end
  end
end
