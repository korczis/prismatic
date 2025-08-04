
defmodule Prismatic.Document.Enrichers.MarkdownFrontmatter do
  @moduledoc """
  Extracts YAML or TOML frontmatter blocks from Markdown files.
  """

  @behaviour Prismatic.Document.Enricher

  def enrich(%Prismatic.Document{path: path, metadata: %{extension: ".md"}} = doc, _opts) do
    content = File.read!(path)

    case parse_frontmatter(content) do
      {:ok, parsed} ->
        updated = Map.put(doc.enrichments, :frontmatter, parsed)
        {:ok, %{doc | enrichments: updated}}

      :error ->
        {:ok, doc}
    end
  end

  def enrich(doc, _opts), do: {:ok, doc}

  defp parse_frontmatter("---
" <> rest), do: extract_yaml(rest)
  defp parse_frontmatter("+++
" <> rest), do: extract_toml(rest)
  defp parse_frontmatter(_), do: :error

  defp extract_yaml(text) do
    [yaml | _] = String.split(text, "
---", parts: 2)
    {:ok, YamlElixir.read_from_string!(yaml)}
  rescue
    _ -> :error
  end

  defp extract_toml(text) do
    [toml | _] = String.split(text, "
+++", parts: 2)
    {:ok, Toml.decode!(toml)}
  rescue
    _ -> :error
  end
end
