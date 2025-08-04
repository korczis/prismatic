defmodule Prismatic.Document.Config do
  @moduledoc """
  Configuration management for document processing pipelines
  """

  defstruct [
    :path,
    :enrichers,
    :filters,
    :batch_size,
    :concurrency,
    :output_format,
    :error_handling,
    :performance_tracking
  ]

  def from_file(config_path) do
    config_path
    |> File.read!()
    |> Jason.decode!()
    |> from_map()
  end

  def from_map(map) do
    %__MODULE__{
      path: map["path"],
      enrichers: parse_enrichers(map["enrichers"] || []),
      filters: parse_filters(map["filters"] || []),
      batch_size: map["batch_size"] || 100,
      concurrency: map["concurrency"] || System.schedulers_online(),
      output_format: map["output_format"] || "json",
      error_handling: map["error_handling"] || "continue",
      performance_tracking: map["performance_tracking"] || false
    }
  end

  defp parse_enrichers(enricher_configs) do
    Enum.map(enricher_configs, fn
      %{"name" => name, "options" => opts} ->
        {enricher_module(name), opts}

      name when is_binary(name) ->
        {enricher_module(name), []}
    end)
  end

  defp parse_filters(filter_configs) do
    Enum.map(filter_configs, fn
      %{"type" => "extension", "values" => exts} ->
        fn doc -> doc.metadata.extension in exts end

      %{"type" => "size_under", "value" => max_size} ->
        fn doc -> doc.metadata.size <= max_size end

      %{"type" => "no_hidden"} ->
        fn doc -> !doc.metadata.hidden? end
    end)
  end

  defp enricher_module(name) do
    Module.concat(Prismatic.Document.Enrichers, Macro.camelize(name))
  end
end
