
defmodule Prismatic.Document.Schema do
  @moduledoc """
  Schema validator for metadata completeness or constraints.
  """
  alias Prismatic.Document.Metadata

  @required [:sha256, :mime_type, :size, :ctime, :path]

  @spec validate(Metadata.t()) :: :ok | {:error, [atom()]}
  def validate(metadata) do
    missing =
      @required
      |> Enum.reject(fn field -> Map.get(metadata, field) not in [nil, ""] end)

    case missing do
      [] -> :ok
      list -> {:error, list}
    end
  end
end
