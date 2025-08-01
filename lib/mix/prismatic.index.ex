defmodule Mix.Tasks.Prismatic.Index do
  @moduledoc """
  Index files using Prismatic pipeline
  ## Examples
      mix prismatic.index --path content/ --enrichers sha256,mime_type
      mix prismatic.index --path docs/ --output json --batch-size 100
  """
  use Mix.Task
  @shortdoc "Index files using Prismatic"

  def run(args) do
    {opts, [path | _], _} =
      OptionParser.parse(args,
        strict: [
          enrichers: :string,
          output: :string,
          batch_size: :integer,
          debug: :boolean
        ]
      )

    enrichers = parse_enrichers(opts[:enrichers])
    batch_size = opts[:batch_size] || 10

    pipeline =
      Prismatic.Document.Builder.new(path)
      |> Prismatic.Document.Builder.with_enrichers(enrichers)
      |> Prismatic.Document.Builder.ignore_hidden()
      |> Prismatic.Document.Builder.build()

    # if opts[:debug] do
    #   pipeline = Prismatic.Document.Pipeline.debug(pipeline, "indexing")
    # end

    pipeline
    |> Stream.chunk_every(batch_size)
    |> Stream.each(&output_batch(&1, opts[:output] || "inspect"))
    |> Stream.run()
  end

  defp parse_enrichers(nil), do: []

  defp parse_enrichers(str) do
    str
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.map(&enricher_module/1)
  end

  defp enricher_module("sha256"), do: Prismatic.Document.Enrichers.SHA256
  defp enricher_module("mime_type"), do: Prismatic.Document.Enrichers.MIMEType
  defp enricher_module("frontmatter"), do: Prismatic.Document.Enrichers.MarkdownFrontmatter

  defp enricher_module(name),
    do: Module.concat(Prismatic.Document.Enrichers, Macro.camelize(name))

  defp output_batch(docs, "json") do
    docs
    |> Enum.map(&convert_calendar_datetimes/1)
    |> Jason.encode!(pretty: true)
    |> IO.puts()
  end

  # Add these new helper functions:
  defp convert_calendar_datetimes(%{metadata: metadata} = doc) when is_map(metadata) do
    %{doc | metadata: convert_calendar_datetimes(metadata)}
  end

  defp convert_calendar_datetimes(%{ctime: ctime, mtime: mtime} = metadata)
       when is_map(metadata) do
    %{metadata | ctime: convert_datetime_tuple(ctime), mtime: convert_datetime_tuple(mtime)}
  end

  defp convert_calendar_datetimes(data) when is_map(data) do
    Enum.into(data, %{}, fn {k, v} -> {k, convert_calendar_datetimes(v)} end)
  end

  defp convert_calendar_datetimes(data) when is_list(data) do
    Enum.map(data, &convert_calendar_datetimes/1)
  end

  defp convert_calendar_datetimes(data), do: data

  defp convert_datetime_tuple({{year, month, day}, {hour, minute, second}}) do
    case DateTime.new(Date.new!(year, month, day), Time.new!(hour, minute, second)) do
      {:ok, datetime} -> datetime
      {:error, _} -> nil
    end
  end

  defp convert_datetime_tuple(other), do: other
end
