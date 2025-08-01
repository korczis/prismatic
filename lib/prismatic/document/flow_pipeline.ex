defmodule Prismatic.Document.FlowPipeline do
  @moduledoc """
  Flow-based processing for high-throughput document pipelines
  """

  alias Prismatic.Document

  def process_with_flow(path, opts \\ []) do
    concurrency = Keyword.get(opts, :concurrency, System.schedulers_online())
    enrichers = Keyword.get(opts, :enrichers, [])
    batch_size = Keyword.get(opts, :batch_size, 100)

    Document.stream(path, opts)
    |> Flow.from_enumerable(max_demand: batch_size)
    |> Flow.partition(stages: concurrency)
    |> Flow.map(fn doc ->
      apply_enrichers_with_stats(doc, enrichers)
    end)
    |> Flow.partition(window: Flow.Window.global() |> Flow.Window.trigger_every(batch_size))
    |> Flow.reduce(fn -> [] end, fn doc, acc -> [doc | acc] end)
    |> Flow.emit(:state)
    |> Flow.map(&Enum.reverse/1)
  end

  defp apply_enrichers_with_stats(document, enrichers) do
    start_time = System.monotonic_time(:microsecond)

    result =
      Enum.reduce(enrichers, document, fn enricher, acc ->
        enricher_start = System.monotonic_time(:microsecond)

        case enricher.enrich(acc, []) do
          {:ok, updated} ->
            enricher_time = System.monotonic_time(:microsecond) - enricher_start
            timing_key = "#{enricher}_timing_us"

            %{updated | enrichments: Map.put(updated.enrichments, timing_key, enricher_time)}

          {:error, reason} ->
            raise "Enricher #{enricher} failed: #{reason}"
        end
      end)

    total_time = System.monotonic_time(:microsecond) - start_time

    %{result | enrichments: Map.put(result.enrichments, :total_processing_time_us, total_time)}
  end
end
