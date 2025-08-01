defmodule Prismatic.Document.Parallel do
  @moduledoc """
  Utilities for parallel and batched document processing
  """

  def process_parallel(stream, enrichers, opts \\ []) do
    concurrency = Keyword.get(opts, :concurrency, System.schedulers_online())
    timeout = Keyword.get(opts, :timeout, 30_000)

    stream
    |> Task.async_stream(
      fn doc ->
        Enum.reduce(enrichers, {:ok, doc}, fn
          enricher, {:ok, acc_doc} ->
            enricher.enrich(acc_doc, opts)

          _enricher, {:error, _} = error ->
            error
        end)
      end,
      max_concurrency: concurrency,
      timeout: timeout,
      on_timeout: :kill_task
    )
    |> Stream.map(fn
      {:ok, {:ok, doc}} -> doc
      {:ok, {:error, reason}} -> raise "Enrichment failed: #{inspect(reason)}"
      {:exit, :timeout} -> raise "Enrichment timeout"
    end)
  end

  def batch_process(stream, batch_size, processor) do
    stream
    |> Stream.chunk_every(batch_size)
    |> Stream.map(processor)
    |> Stream.flat_map(& &1)
  end
end
