# Enhanced enricher with conditional logic
defmodule Prismatic.Document.Enrichers.Conditional do
  @moduledoc """
  Wrapper for conditional enrichment based on document properties
  """

  def when_extension(enricher, extensions) when is_list(extensions) do
    fn doc, opts ->
      if doc.metadata.extension in extensions do
        enricher.enrich(doc, opts)
      else
        {:ok, doc}
      end
    end
  end

  def when_mime_type(enricher, mime_pattern) do
    fn doc, opts ->
      if doc.metadata.mime_type && String.match?(doc.metadata.mime_type, mime_pattern) do
        enricher.enrich(doc, opts)
      else
        {:ok, doc}
      end
    end
  end

  def when_size_under(enricher, max_bytes) do
    fn doc, opts ->
      if doc.metadata.size <= max_bytes do
        enricher.enrich(doc, opts)
      else
        {:ok, doc}
      end
    end
  end
end
