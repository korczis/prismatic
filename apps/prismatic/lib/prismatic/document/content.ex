
defmodule Prismatic.Document.Content do
  @moduledoc """
  Optional parsed content or structured extraction from a file.
  """

  @type t :: %__MODULE__{
          text: String.t() | nil,
          title: String.t() | nil,
          summary: String.t() | nil,
          language: String.t() | nil,
          preview: String.t() | nil
        }

  defstruct [:text, :title, :summary, :language, :preview]
end
