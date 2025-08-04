defmodule Prismatic.Document.Enrichers.SHA256 do
  @moduledoc """
  Adds SHA256 hash of file contents to document metadata.
  """

  @behaviour Prismatic.Document.Enricher

  def enrich(%Prismatic.Document{path: path, metadata: metadata} = doc, _opts) do
    hash =
      File.read!(path)
      |> :crypto.hash(:sha256)
      |> Base.encode16(case: :lower)

    updated = %{metadata | sha256: hash}
    {:ok, %{doc | metadata: updated}}
  end
end

