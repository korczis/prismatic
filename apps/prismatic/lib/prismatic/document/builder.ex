defmodule Prismatic.Document.Builder do
  @moduledoc """
  Fluent builder API for document processing pipelines
  """

  defstruct [:path, :opts, :enrichers, :filters, :processors]

  def new(path, opts \\ []) do
    %__MODULE__{
      path: path,
      opts: opts,
      enrichers: [],
      filters: [],
      processors: []
    }
  end

  def with_enrichers(builder, enrichers) when is_list(enrichers) do
    %{builder | enrichers: builder.enrichers ++ enrichers}
  end

  def with_filter(builder, filter_fn) when is_function(filter_fn, 1) do
    %{builder | filters: builder.filters ++ [filter_fn]}
  end

  def ignore_hidden(builder) do
    with_filter(builder, &(!&1.metadata.hidden?))
  end

  def only_extensions(builder, extensions) when is_list(extensions) do
    with_filter(builder, fn doc ->
      doc.metadata.extension in extensions
    end)
  end

  def with_processor(builder, processor) when is_function(processor, 2) do
    %{builder | processors: builder.processors ++ [processor]}
  end

  def build(builder) do
    Prismatic.Document.stream(builder.path, builder.opts)
    |> apply_filters(builder.filters)
    |> Prismatic.Document.attach(builder.enrichers, builder.opts)
    |> apply_processors(builder.processors, builder.opts)
  end

  defp apply_filters(stream, filters) do
    Enum.reduce(filters, stream, fn filter, acc ->
      Stream.filter(acc, filter)
    end)
  end

  defp apply_processors(stream, processors, opts) do
    Enum.reduce(processors, stream, fn processor, acc ->
      Prismatic.Document.process(acc, processor, opts)
    end)
  end
end
