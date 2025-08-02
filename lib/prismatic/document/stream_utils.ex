defmodule Prismatic.Document.StreamUtils do
  @moduledoc """
  Utilities for working with document streams
  """

  # Progress reporting
  def with_progress(stream, report_every \\ 100) do
    stream
    |> Stream.with_index()
    |> Stream.map(fn {doc, index} ->
      if rem(index, report_every) == 0 do
        IO.puts("Processed #{index} documents...")
      end

      doc
    end)
  end

  # Rate limiting
  def rate_limit(stream, per_second) do
    interval_us = trunc(1_000_000 / per_second)

    stream
    |> Stream.map(fn doc ->
      :timer.sleep(div(interval_us, 1000))
      doc
    end)
  end

  # Memory-safe chunking
  def safe_chunk(stream, chunk_size, processor) do
    stream
    |> Stream.chunk_every(chunk_size)
    |> Stream.map(fn chunk ->
      results = processor.(chunk)
      # Force garbage collection after processing chunk
      :erlang.garbage_collect()
      results
    end)
    |> Stream.flat_map(& &1)
  end

  # Conditional processing
  def process_if(stream, condition, processor) do
    Stream.map(stream, fn doc ->
      if condition.(doc) do
        processor.(doc)
      else
        doc
      end
    end)
  end

  # Error collection
  def collect_errors(stream) do
    {good, bad} =
      stream
      |> Enum.reduce({[], []}, fn
        %{enrichments: %{error: _}} = doc, {good, bad} ->
          {good, [doc | bad]}

        doc, {good, bad} ->
          {[doc | good], bad}
      end)

    %{successful: Enum.reverse(good), failed: Enum.reverse(bad)}
  end
end
