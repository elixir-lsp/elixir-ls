defmodule ElixirLS.LanguageServer.MarkdownUtils do
  alias ElixirLS.LanguageServer.DocLinks

  # Find the lowest heading level in the fragment
  defp lowest_heading_level(fragment) do
    case Regex.scan(~r/(?<!\\)(?<!\w)(#+)(?=\s)/u, fragment) do
      [] ->
        nil

      matches ->
        matches
        |> Enum.map(fn [_, heading] -> String.length(heading) end)
        |> Enum.min()
    end
  end

  # Adjust heading levels of an embedded markdown fragment
  def adjust_headings(fragment, base_level) do
    min_level = lowest_heading_level(fragment)

    if min_level do
      level_difference = base_level + 1 - min_level

      Regex.replace(~r/(?<!\\)(?<!\w)(#+)(?=\s)/u, fragment, fn _, capture ->
        adjusted_level = String.length(capture) + level_difference
        String.duplicate("#", adjusted_level)
      end)
    else
      fragment
    end
  end

  def join_with_horizontal_rule(list) do
    Enum.map_join(list, "\n\n---\n\n", fn lines ->
      lines
      |> String.replace_leading("\r\n", "")
      |> String.replace_leading("\n", "")
      |> String.replace_trailing("\r\n", "")
      |> String.replace_trailing("\n", "")
    end) <> "\n"
  end

  def get_metadata_md(metadata) do
    text =
      metadata
      |> Enum.sort()
      |> Enum.map(&get_metadata_entry_md/1)
      |> Enum.reject(&is_nil/1)
      |> Enum.join("\n\n")

    case text do
      "" -> ""
      not_empty -> not_empty <> "\n\n"
    end
  end

  # erlang name
  defp get_metadata_entry_md({:name, _text}), do: nil

  # erlang signature
  defp get_metadata_entry_md({:signature, _text}), do: nil

  # erlang edit_url
  defp get_metadata_entry_md({:edit_url, _text}), do: nil

  # erlang :otp_doc_vsn
  defp get_metadata_entry_md({:otp_doc_vsn, _text}), do: nil

  # erlang :source
  defp get_metadata_entry_md({:source, _text}), do: nil

  # erlang :types
  defp get_metadata_entry_md({:types, _text}), do: nil

  # erlang :group
  defp get_metadata_entry_md({:group, _group}), do: nil

  # erlang :equiv
  # OTP < 27
  defp get_metadata_entry_md({:equiv, {:function, name, arity}}) do
    "**Equivalent to** #{name}/#{arity}"
  end

  # OTP >= 27
  defp get_metadata_entry_md({:equiv, text}) when is_binary(text) do
    "**Equivalent to** #{text}"
  end

  defp get_metadata_entry_md({:deprecated, text}) when is_binary(text) do
    "**Deprecated** #{text}"
  end

  defp get_metadata_entry_md({:since, text}) when is_binary(text) do
    "**Since** #{text}"
  end

  defp get_metadata_entry_md({:guard, true}) do
    "**Guard**"
  end

  defp get_metadata_entry_md({:hidden, true}) do
    "**Hidden**"
  end

  defp get_metadata_entry_md({:builtin, true}) do
    "**Built-in**"
  end

  defp get_metadata_entry_md({:implementing, module}) when is_atom(module) do
    "**Implementing behaviour** #{inspect(module)}"
  end

  defp get_metadata_entry_md({:implementing_module_app, app}) when is_atom(app) do
    "**Behaviour defined in application** #{to_string(app)}"
  end

  defp get_metadata_entry_md({:app, app}) when is_atom(app) do
    "**Application** #{to_string(app)}"
  end

  defp get_metadata_entry_md({:optional, true}) do
    "**Optional**"
  end

  defp get_metadata_entry_md({:optional, false}), do: nil

  defp get_metadata_entry_md({:overridable, true}) do
    "**Overridable**"
  end

  defp get_metadata_entry_md({:overridable, false}), do: nil

  defp get_metadata_entry_md({:opaque, true}) do
    "**Opaque**"
  end

  defp get_metadata_entry_md({:defaults, _}), do: nil

  defp get_metadata_entry_md({:delegate_to, {m, f, a}})
       when is_atom(m) and is_atom(f) and is_integer(a) do
    "**Delegates to** #{inspect(m)}.#{f}/#{a}"
  end

  defp get_metadata_entry_md({:behaviours, []}), do: nil

  defp get_metadata_entry_md({:behaviours, list})
       when is_list(list) do
    "**Implements** #{Enum.map_join(list, ", ", &inspect/1)}"
  end

  defp get_metadata_entry_md({:source_annos, _}), do: nil

  defp get_metadata_entry_md({:source_path, _}), do: nil

  defp get_metadata_entry_md({:spark_opts, _}), do: nil

  defp get_metadata_entry_md({key, value}) do
    "**#{key}** #{inspect(value)}"
  end

  @doc """
  This function implements most of the elixir (and some erlang) related functionality
  of ExDoc autolinker https://hexdocs.pm/ex_doc/readme.html#auto-linking
  """
  def transform_ex_doc_links(string, current_module \\ nil) do
    string
    |> String.split(~r/(`.*?`)|(\[.*?\]\(.*?\))/u, include_captures: true)
    |> Enum.map(fn segment ->
      cond do
        segment =~ ~r/^`.*?`$/u ->
          try do
            trimmed = String.trim(segment, "`")

            transformed_link =
              trimmed
              |> transform_ex_doc_link(current_module)

            if transformed_link == nil do
              raise "unable to autolink"
            end

            trimmed_no_prefix =
              trimmed
              |> String.replace(~r/^[mtce]\:/, "")
              |> split
              |> elem(0)

            ["[`", trimmed_no_prefix, "`](", transformed_link, ")"]
          rescue
            _ ->
              segment
          end

        segment =~ ~r/^\[..*?\]\(.*\)$/u ->
          try do
            [[_, custom_text, stripped]] = Regex.scan(~r/^\[(.*?)\]\((.*)\)$/u, segment)
            trimmed = String.trim(stripped, "`")

            transformed_link =
              if trimmed =~ ~r/^https?:\/\// or
                   (trimmed =~ ~r/\.(md|livemd|txt|html)(#.*)?$/ and
                      not String.starts_with?(trimmed, "e:")) do
                transform_ex_doc_link("e:" <> trimmed, current_module)
              else
                transform_ex_doc_link(trimmed, current_module)
              end

            if transformed_link == nil do
              raise "unable to autolink"
            end

            ["[", custom_text, "](", transformed_link, ")"]
          rescue
            _ ->
              segment
          end

        true ->
          segment
      end
    end)
    |> IO.iodata_to_binary()
  end

  def transform_ex_doc_link(string, current_module \\ nil)

  def transform_ex_doc_link("m:" <> rest, _current_module) do
    {module_str, anchor} = split(rest)

    module = module_string_to_atom(module_str)
    module_link(module, anchor)
  end

  @builtin_type_url Map.new(ElixirSense.Core.BuiltinTypes.all(), fn {key, value} ->
                      anchor =
                        if value |> Map.has_key?(:spec) do
                          "built-in-types"
                        else
                          "basic-types"
                        end

                      url =
                        DocLinks.hex_docs_extra_link(
                          {:elixir, System.version()},
                          "typespecs.html"
                        ) <>
                          "#" <> anchor

                      key =
                        if key =~ ~r/\/d+$/ do
                          key
                        else
                          key <> "/0"
                        end

                      {key, url}
                    end)

  @erlang_ex_doc? System.otp_release() |> String.to_integer() >= 27

  def transform_ex_doc_link("t:" <> rest, current_module) do
    case @builtin_type_url[rest] do
      nil ->
        case get_module_fun_arity(rest) do
          {module, type, arity} ->
            if match?(":" <> _, rest) do
              if @erlang_ex_doc? do
                # TODO not sure hos the docs will handle versions app/vsn does not work as of June 2024
                {app, _vsn} = DocLinks.get_app(module)
                "https://www.erlang.org/doc/apps/#{app}/#{module}.html#t:#{type}/#{arity}"
              else
                "https://www.erlang.org/doc/man/#{module}.html#type-#{type}"
              end
            else
              DocLinks.hex_docs_type_link(module || current_module, type, arity)
            end
        end

      url ->
        url
    end
  end

  def transform_ex_doc_link("c:" <> rest, current_module) do
    case get_module_fun_arity(rest) do
      {module, callback, arity} ->
        if match?(":" <> _, rest) do
          if @erlang_ex_doc? do
            # TODO not sure hos the docs will handle versions app/vsn does not work as of June 2024
            {app, _vsn} = DocLinks.get_app(module)
            "https://www.erlang.org/doc/apps/#{app}/#{module}.html#c:#{callback}/#{arity}"
          else
            "https://www.erlang.org/doc/man/#{module}.html#Module:#{callback}-#{arity}"
          end
        else
          DocLinks.hex_docs_callback_link(module || current_module, callback, arity)
        end
    end
  end

  def transform_ex_doc_link("e:http://" <> rest, _current_module), do: "http://" <> rest
  def transform_ex_doc_link("e:https://" <> rest, _current_module), do: "https://" <> rest

  otp_apps_dir =
    :code.get_object_code(:erlang) |> elem(2) |> Path.join("../../..") |> Path.expand()

  @all_otp_apps otp_apps_dir
                |> File.ls!()
                |> Enum.map(&(&1 |> String.split("-") |> hd() |> String.to_atom()))

  if @erlang_ex_doc? do
    def transform_ex_doc_link("e:system:" <> rest, _current_module) do
      {page, anchor} = split(rest)

      page =
        page
        |> String.replace(~r/\.(md|livemd|cheatmd|txt)$/, ".html")
        |> String.replace(" ", "-")
        |> String.downcase()

      "https://www.erlang.org/doc/system/#{page}" <>
        if anchor do
          "#" <> anchor
        else
          ""
        end
    end
  end

  def transform_ex_doc_link("e:" <> rest, current_module) do
    {page, anchor} = split(rest)

    {app, page} =
      case split(page, ":") do
        {page, nil} -> {nil, page}
        other -> other
      end

    page =
      page
      |> String.replace(~r/\.(md|livemd|cheatmd|txt)$/, ".html")
      |> String.replace(" ", "-")
      |> String.downcase()

    app_vsn =
      if app do
        vsn =
          Application.loaded_applications()
          |> Enum.find_value(fn {a, _, vsn} ->
            if to_string(a) == app do
              vsn
            end
          end)

        if vsn do
          {app, vsn}
        else
          app
        end
      else
        case DocLinks.get_app(current_module) do
          {app, vsn} ->
            {app, vsn}

          _ ->
            nil
        end
      end

    if app_vsn do
      {app, _vsn} = app_vsn

      if app in @all_otp_apps and @erlang_ex_doc? do
        # TODO not sure hos the docs will handle versions app/vsn does not work as of June 2024
        "https://www.erlang.org/doc/apps/#{app}/#{page}"
      else
        DocLinks.hex_docs_extra_link(app_vsn, page)
      end <>
        if anchor do
          "#" <> anchor
        else
          ""
        end
    end
  end

  def transform_ex_doc_link(string, current_module) do
    {prefix, anchor} = split(string)

    case get_module_fun_arity(prefix) do
      {:"", nil, nil} ->
        module_link(current_module, anchor)

      {module, nil, nil} ->
        if Code.ensure_loaded?(module) do
          module_link(module, anchor)
        end

      {module, function, arity} ->
        if match?(":" <> _, prefix) and module != Kernel.SpecialForms do
          if @erlang_ex_doc? do
            # TODO not sure hos the docs will handle versions app/vsn does not work as of June 2024
            {app, _vsn} = DocLinks.get_app(module)
            "https://www.erlang.org/doc/apps/#{app}/#{module}.html##{function}/#{arity}"
          else
            "https://www.erlang.org/doc/man/#{module}.html##{function}-#{arity}"
          end
        else
          DocLinks.hex_docs_function_link(module || current_module, function, arity)
        end
    end
  end

  @kernel_special_forms_exports Kernel.SpecialForms.__info__(:macros)
  @kernel_exports Kernel.__info__(:macros) ++ Kernel.__info__(:functions)

  defp get_module_fun_arity("..///3"), do: {Kernel, :..//, 3}
  defp get_module_fun_arity("../2"), do: {Kernel, :.., 2}
  defp get_module_fun_arity("../0"), do: {Kernel, :.., 0}
  defp get_module_fun_arity("./2"), do: {Kernel.SpecialForms, :., 2}
  defp get_module_fun_arity("::/2"), do: {Kernel.SpecialForms, :"::", 2}

  defp get_module_fun_arity(string) do
    string = string |> String.trim_leading(":") |> String.replace(":", ".")

    {module, fun_arity} =
      case String.split(string, ".") do
        [fun_arity] ->
          {nil, fun_arity}

        list ->
          [fun_arity | module_reversed] = Enum.reverse(list)
          module_str = module_reversed |> Enum.reverse() |> Enum.join(".")
          module = module_string_to_atom(module_str)
          {module, fun_arity}
      end

    case String.split(fun_arity, "/", parts: 2) do
      [fun, arity] ->
        fun = String.to_atom(fun)
        arity = String.to_integer(arity)

        module =
          cond do
            module != nil ->
              module

            {fun, arity} in @kernel_exports ->
              Kernel

            {fun, arity} in @kernel_special_forms_exports ->
              Kernel.SpecialForms

            true ->
              # NOTE we should be able to resolve all imported locals but we limit to current module and
              # Kernel, Kernel.SpecialForms for simplicity
              nil
          end

        {module, fun, arity}

      _ ->
        module = module_string_to_atom(string)
        {module, nil, nil}
    end
  end

  defp module_string_to_atom(module_str) do
    module = Module.concat([module_str])

    if inspect(module) == module_str do
      module
    else
      String.to_atom(module_str)
    end
  end

  defp split(rest, separator \\ "#") do
    case String.split(rest, separator, parts: 2) do
      [module, anchor] ->
        {module, anchor}

      [module] ->
        {module, nil}
    end
  end

  defp module_link(module, anchor) do
    DocLinks.hex_docs_module_link(module) <>
      if anchor do
        "#" <> anchor
      else
        ""
      end
  end
end
