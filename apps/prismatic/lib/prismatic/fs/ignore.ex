
defmodule Prismatic.FS.Ignore do
  @moduledoc """
  Utilities for skipping hidden or excluded files.
  """

  @spec hidden?(String.t()) :: boolean()
  def hidden?(path) do
    Path.basename(path)
    |> String.starts_with?(".")
  end
end
