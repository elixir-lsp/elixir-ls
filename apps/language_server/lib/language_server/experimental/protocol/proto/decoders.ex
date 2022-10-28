defmodule ElixirLS.LanguageServer.Experimental.Protocol.Proto.Decoders do
  alias ElixirLS.LanguageServer.Experimental.Protocol.Proto.CompileMetadata

  defmacro for_notifications(_) do
    notification_modules = CompileMetadata.notification_modules()
    notification_matchers = Enum.map(notification_modules, &build_notification_matcher_macro/1)
    notification_decoders = Enum.map(notification_modules, &build_notifications_decoder/1)
    access_map = build_acces_map(notification_modules)

    quote do
      alias ElixirLS.LanguageServer.Experimental.Protocol.Proto.Convert

      defmacro notification(method) do
        quote do
          %{"method" => unquote(method), "jsonrpc" => "2.0"}
        end
      end

      defmacro notification(method, params) do
        quote do
          %{"method" => unquote(method), "params" => unquote(params), "jsonrpc" => "2.0"}
        end
      end

      unquote(build_typespec(:notification, notification_modules))

      unquote_splicing(notification_matchers)

      @spec decode(String.t(), map()) :: {:ok, notification} | {:error, any}
      unquote_splicing(notification_decoders)

      def decode(method, _) do
        {:error, {:unknown_notification, method}}
      end

      def __meta__(:events) do
        unquote(notification_modules)
      end

      def __meta__(:notifications) do
        unquote(notification_modules)
      end

      def __meta__(:access) do
        %{unquote_splicing(access_map)}
      end

      def to_elixir(%{lsp: _} = request_or_notification) do
        Convert.to_elixir(request_or_notification)
      end
    end
  end

  defmacro for_requests(_) do
    request_modules = CompileMetadata.request_modules()
    request_matchers = Enum.map(request_modules, &build_request_matcher_macro/1)
    request_decoders = Enum.map(request_modules, &build_request_decoder/1)
    access_map = build_acces_map(request_modules)

    quote do
      alias ElixirLS.LanguageServer.Experimental.Protocol.Proto.Convert

      def __meta__(:requests) do
        unquote(request_modules)
      end

      def __meta__(:access) do
        %{unquote_splicing(access_map)}
      end

      defmacro request(id, method) do
        quote do
          %{"method" => unquote(method), "id" => unquote(id), "jsonrpc" => "2.0"}
        end
      end

      defmacro request(id, method, params) do
        quote do
          %{"method" => unquote(method), "id" => unquote(id), "params" => unquote(params)}
        end
      end

      unquote(build_typespec(:request, request_modules))

      unquote_splicing(request_matchers)

      @spec decode(String.t(), map()) :: {:ok, request} | {:error, any}
      unquote_splicing(request_decoders)

      def decode(method, _) do
        {:error, {:unknown_request, method}}
      end

      def to_elixir(%{lsp: _} = request_or_notification) do
        Convert.to_elixir(request_or_notification)
      end
    end
  end

  defp build_acces_map(modules) do
    Enum.map(modules, fn module ->
      quote(do: {unquote(module.method()), unquote(module.__meta__(:access))})
    end)
  end

  defp build_notification_matcher_macro(notification_module) do
    macro_name = module_to_macro_name(notification_module)
    method_name = notification_module.__meta__(:method_name)

    quote do
      defmacro unquote(macro_name)() do
        method_name = unquote(method_name)

        quote do
          %{"method" => unquote(method_name), "jsonrpc" => "2.0"}
        end
      end
    end
  end

  defp build_notifications_decoder(notification_module) do
    method_name = notification_module.__meta__(:method_name)

    quote do
      def decode(unquote(method_name), request) do
        unquote(notification_module).parse(request)
      end
    end
  end

  defp build_request_matcher_macro(notification_module) do
    macro_name = module_to_macro_name(notification_module)
    method_name = notification_module.__meta__(:method_name)

    quote do
      defmacro unquote(macro_name)(id) do
        method_name = unquote(method_name)

        quote do
          %{"method" => unquote(method_name), "id" => unquote(id), "jsonrpc" => "2.0"}
        end
      end
    end
  end

  defp build_request_decoder(request_module) do
    method_name = request_module.__meta__(:method_name)

    quote do
      def decode(unquote(method_name), request) do
        unquote(request_module).parse(request)
      end
    end
  end

  def build_typespec(type_name, modules) do
    spec_name = {type_name, [], nil}

    spec =
      Enum.reduce(modules, nil, fn
        module, nil ->
          quote do
            unquote(module).t()
          end

        module, spec ->
          quote do
            unquote(module).t() | unquote(spec)
          end
      end)

    quote do
      @type unquote(spec_name) :: unquote(spec)
    end
  end

  defp module_to_macro_name(module) do
    module
    |> Module.split()
    |> List.last()
    |> Macro.underscore()
    |> String.to_atom()
  end
end
