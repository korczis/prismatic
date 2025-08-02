defmodule Prismatic.Document.Pipeline do
  @moduledoc """
  Enhanced pipeline with better debugging and error handling
  """

  # Add pipeline debugging
  def debug(stream, label \\ "debug") do
    Stream.map(stream, fn doc ->
      IO.puts("=== #{label} ===")
      IO.inspect(doc.path)
      IO.inspect(Map.keys(doc.enrichments))
      IO.puts("================")
      doc
    end)
  end

  # Add pipeline metrics
  def with_metrics(stream) do
    start_time = System.monotonic_time(:millisecond)
    count = Agent.start_link(fn -> 0 end)

    stream
    |> Stream.map(fn doc ->
      Agent.update(count, &(&1 + 1))
      doc
    end)
    |> Stream.transform(
      fn -> nil end,
      fn doc, acc ->
        {[doc], acc}
      end,
      fn _acc ->
        end_time = System.monotonic_time(:millisecond)
        total_count = Agent.get(count, & &1)
        duration = end_time - start_time

        IO.puts("Processed #{total_count} documents in #{duration}ms")
        Agent.stop(count)
      end
    )
  end

  # Better error recovery
  def with_error_recovery(stream, opts \\ []) do
    continue_on_error = Keyword.get(opts, :continue_on_error, true)
    log_errors = Keyword.get(opts, :log_errors, true)

    Stream.map(stream, fn doc ->
      try do
        doc
      rescue
        error ->
          if log_errors do
            require Logger
            Logger.error("Error processing #{doc.path}: #{inspect(error)}")
          end

          if continue_on_error do
            %{doc | enrichments: Map.put(doc.enrichments, :error, inspect(error))}
          else
            reraise error, __STACKTRACE__
          end
      end
    end)
  end
end
