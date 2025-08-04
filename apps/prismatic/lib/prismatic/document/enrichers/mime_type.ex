defmodule Prismatic.Document.Enrichers.MIMEType do
  @moduledoc """
  Enricher that determines the MIME type using `file --mime-type`.
  """

  @behaviour Prismatic.Document.Enricher

  def enrich(%Prismatic.Document{path: path, metadata: metadata} = doc, _opts) do
    {type, 0} = System.cmd("file", ["--mime-type", "-b", path])
    updated = %{metadata | mime_type: String.trim(type)}
    {:ok, %{doc | metadata: updated}}
  end
end

