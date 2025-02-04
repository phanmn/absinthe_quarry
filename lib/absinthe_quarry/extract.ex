defmodule AbsintheQuarry.Extract do
  @moduledoc false

  def run(%{definition: field}) do
    run(field)
  end

  def run(field) do
    {[], field}
    |> maybe_add_offset()
    |> maybe_add_limit()
    |> maybe_add_sort()
    |> maybe_add_filter()
    |> maybe_add_loads()
    |> then(fn {quarry_params, _} -> quarry_params end)
  end

  defp maybe_add_loads({quarry_params, %{selections: fields} = field}) do
    case extract_loads(fields) do
      [] -> {quarry_params, field}
      load -> {[{:load, load} | quarry_params], field}
    end
  end

  defp maybe_add_filter({quarry_params, %{argument_data: %{filter: filter}} = field}),
    do: {[{:filter, normalize_filter(filter)} | quarry_params], field}

  defp maybe_add_filter(token), do: token

  defp maybe_add_sort({quarry_params, %{argument_data: %{sort: sort}} = field}) do
    {[{:sort, split_sort_fields(sort)} | quarry_params], field}
  end

  defp maybe_add_sort(token), do: token

  defp maybe_add_limit({quarry_params, %{argument_data: %{limit: limit}} = field}),
    do: {[{:limit, limit} | quarry_params], field}

  defp maybe_add_limit(token), do: token

  defp maybe_add_offset({quarry_params, %{argument_data: %{offset: offset}} = field}),
    do: {[{:offset, offset} | quarry_params], field}

  defp maybe_add_offset(token), do: token

  defp extract_loads(fields) do
    fields
    |> Enum.filter(&should_load?/1)
    |> Enum.map(&{extract_assoc_name(&1), extract_child(&1)})
  end

  defp extract_assoc_name(%{schema_node: node}) do
    case Absinthe.Type.meta(node, :quarry) do
      conf when is_list(conf) -> Keyword.get(conf, :assoc, node.identifier)
      _ -> node.identifier
    end
  end

  defp extract_child(%{argument_data: args, selections: selections}) when map_size(args) == 0 do
    extract_loads(selections)
  end

  defp extract_child(field), do: run(field)

  defp normalize_filter(args) do
    args
    |> Enum.map(fn
      {field, child} when is_map(child) and is_struct(child) == false ->
        {field, normalize_filter(child)}

      {field, value} ->
        case String.split(Atom.to_string(field), "__") do
          [column, operation] -> {String.to_atom(column), {String.to_atom(operation), value}}
          _ -> {field, value}
        end
    end)
    |> Map.new()
  end

  defp should_load?(%{schema_node: schema_node}) do
    Absinthe.Type.meta(schema_node, :quarry) || false
  end

  defp split_sort_fields(sort) when is_atom(sort) do
    [split_sort_field(sort)]
  end

  defp split_sort_fields(sort) when is_list(sort), do: Enum.map(sort, &split_sort_field(&1))

  defp split_sort_field(sort) do
    sort |> Atom.to_string() |> String.split("__") |> Enum.map(&String.to_atom/1)
  end
end
