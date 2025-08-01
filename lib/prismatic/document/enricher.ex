
defmodule Prismatic.Document.Enricher do
  @moduledoc """
  Behaviour for modules that enrich a document with additional metadata or content.
  """

  @callback enrich(Prismatic.Document.t(), keyword()) ::
              {:ok, Prismatic.Document.t()} | {:error, term()}
end
