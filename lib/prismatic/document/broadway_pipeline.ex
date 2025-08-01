# Enhanced Broadway pipeline
defmodule Prismatic.Document.BroadwayPipeline do
  @moduledoc """
  Pre-configured Broadway pipeline for document processing
  """

  use Broadway

  alias Broadway.Message

  def start_link(opts) do
    Broadway.start_link(__MODULE__,
      name: __MODULE__,
      producer: [
        module: {Prismatic.Document.BroadwayProducer, opts[:producer] || []},
        concurrency: opts[:producer_concurrency] || 1
      ],
      processors: [
        default: [
          concurrency: opts[:processor_concurrency] || System.schedulers_online(),
          min_demand: opts[:min_demand] || 5,
          max_demand: opts[:max_demand] || 10
        ]
      ],
      batchers: [
        default: [
          batch_size: opts[:batch_size] || 100,
          batch_timeout: opts[:batch_timeout] || 5_000,
          concurrency: opts[:batcher_concurrency] || 1
        ]
      ]
    )
  end

  @impl true
  def handle_message(:default, %Message{data: document} = message, context) do
    try do
      # Apply configured enrichers
      enrichers = get_enrichers(context)
      enriched_doc = apply_enrichers(document, enrichers)

      # Add processing metadata
      processed_doc = %{
        enriched_doc
        | enrichments:
            Map.put(enriched_doc.enrichments, :broadway_processed_at, DateTime.utc_now())
      }

      Message.put_data(message, processed_doc)
    rescue
      error ->
        Message.failed(message, inspect(error))
    end
  end

  @impl true
  def handle_batch(:default, messages, _batch_info, context) do
    uploader = get_uploader(context)
    documents = Enum.map(messages, & &1.data)

    case uploader.upload_batch(documents) do
      :ok ->
        messages

      {:error, reason} ->
        Enum.map(messages, &Message.failed(&1, reason))
    end
  end

  @impl true
  def handle_failed(messages, _context) do
    Enum.each(messages, fn %Message{data: doc} = message ->
      require Logger
      Logger.error("Failed to process document: #{doc.path}, reason: #{inspect(message.status)}")
    end)

    messages
  end

  defp get_enrichers(context) do
    context[:enrichers] || []
  end

  defp get_uploader(context) do
    context[:uploader] || Prismatic.Document.MockUploader
  end

  defp apply_enrichers(document, enrichers) do
    Enum.reduce(enrichers, document, fn enricher, acc ->
      case enricher.enrich(acc, []) do
        {:ok, updated} -> updated
        {:error, reason} -> raise "Enricher #{enricher} failed: #{reason}"
      end
    end)
  end
end
