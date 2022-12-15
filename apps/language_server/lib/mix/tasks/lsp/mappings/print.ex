defmodule Mix.Tasks.Lsp.Mappings.Print do
  alias IO.ANSI
  alias Mix.Tasks.Lsp.Mappings.Mapping
  alias Mix.Tasks.Lsp.Mappings

  defmodule Node do
    defstruct path: nil, value: nil, children: %{}

    def new(path \\ nil) do
      %__MODULE__{path: path}
    end

    def children_size(%__MODULE__{} = node) do
      map_size(node.children)
    end

    def name(%__MODULE__{} = node) do
      case node.path do
        list when is_list(list) -> List.last(list)
        nil -> "<<root>>"
      end
    end

    def has_value?(%__MODULE__{} = node) do
      node.value != nil
    end

    def add(%__MODULE__{} = node, path, value) do
      do_add(node, path, [], value)
    end

    defp do_add(%__MODULE__{} = node, [], current_path, value) do
      %__MODULE__{node | value: value, path: Enum.reverse(current_path)}
    end

    defp do_add(%__MODULE__{} = node, [next | rest], current_path, value) do
      current_path = [next | current_path]

      children =
        Map.update(
          node.children,
          next,
          current_path |> Enum.reverse() |> new() |> do_add(rest, current_path, value),
          fn %Node{} = existing ->
            do_add(existing, rest, current_path, value)
          end
        )

      %__MODULE__{node | children: children}
    end
  end

  @shortdoc "Prints out the current mappings"
  @moduledoc """
  Prints out the current mappings
  This task reads `type_mappings.json` and generates a nested tree of the current mappings, much
  like `mix deps.tree` does.
  Use this task while determining where mappings live, as it's much easier to see the module structure
  graphically as opposed to remembering all the mappings in the json file.
  """
  use Mix.Task
  @prefix "ElixirLS.LanguageServer.Experimental.Protocol"
  @prefix_length String.length(@prefix)
  @down "└"
  @right "─"
  @tee "├"

  def run(_) do
    with {:ok, mappings} <- Mappings.new() do
      print(mappings)
    end
  end

  def print(%Mappings{} = mappings) do
    legend()

    mappings
    |> build_tree()
    |> print_tree()
  end

  defp legend do
    """
    Current Module mappings follow.
    Modules that will result in a mapping file are #{mapped_module_color()}WrittenLikeThis#{ANSI.reset()}
    while modules that just hold other modules are #{namespace_color()}WrittenLikeThis#{ANSI.reset()}
    """
    |> IO.puts()
  end

  defp mapped_module_color do
    [ANSI.bright(), ANSI.white()]
  end

  defp namespace_color do
    [ANSI.cyan(), ANSI.italic()]
  end

  defp print_tree(%Node{path: nil} = root) do
    print_children(root, -1)
  end

  defp print_tree(%Node{} = node, level \\ 0, last? \\ false) do
    child_count_message =
      case Node.children_size(node) do
        0 ->
          ""

        child_count ->
          ["(", pluralize(child_count, "child", "children"), ")"]
      end

    sep =
      cond do
        level == 0 ->
          ""

        last? ->
          @down

        true ->
          @tee
      end

    name_color =
      if Node.has_value?(node) do
        mapped_module_color()
      else
        namespace_color()
      end

    child_color = ANSI.yellow()

    indent = String.duplicate(" ", 2 * level)

    IO.puts([
      indent,
      sep,
      @right,
      " ",
      name_color,
      Node.name(node),
      ANSI.reset(),
      " ",
      child_color,
      child_count_message,
      ANSI.reset()
    ])

    print_children(node, level)
  end

  defp print_children(%Node{children: children} = node, level) when map_size(children) > 0 do
    child_count = Node.children_size(node)

    children
    |> Map.values()
    |> Enum.sort_by(&Node.name(&1))
    |> Enum.with_index()
    |> Enum.each(fn {%Node{} = child, index} ->
      print_tree(child, level + 1, last?(child_count, index))
    end)
  end

  defp print_children(_, _) do
  end

  defp pluralize(1, singular, _plural), do: "1 #{singular}"
  defp pluralize(num, _, plural), do: "#{num} #{plural}"

  defp build_tree(%Mappings{} = mappings) do
    Enum.reduce(mappings.mappings, Node.new(), fn %Mapping{} = mapping, %Node{} = root ->
      path =
        mapping.destination
        |> drop_prefix()
        |> split_module()

      Node.add(root, path, List.last(path))
    end)
  end

  defp last?(item_count, index) do
    index == item_count - 1
  end

  defp drop_prefix(s) do
    String.slice(s, (@prefix_length + 1)..-1)
  end

  defp split_module(s) do
    String.split(s, ".")
  end
end
