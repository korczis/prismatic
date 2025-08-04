
defmodule Prismatic.FS.Reader do
  @moduledoc """
  Recursively traverses a directory and lazily emits file paths.
  Supports relative paths (`.`, `..`) and globs like `**/*`.
  """

  @spec stream_dir(String.t()) :: Enumerable.t()
  def stream_dir(input_path) do
    path = Path.expand(input_path)

    Path.wildcard(Path.join([path, "**", "*"]))
    |> Stream.filter(&File.regular?/1)
  end
end
