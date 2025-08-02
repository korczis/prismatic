defmodule Prismatic.Document.Metadata do
  @moduledoc """
  Metadata extracted from the filesystem or enrichers about a file/document.
  """
  @type t :: %__MODULE__{
          filename: String.t(),
          extension: String.t() | nil,
          dirname: String.t(),
          path: String.t(),
          hidden?: boolean(),
          size: non_neg_integer(),
          ctime: DateTime.t(),
          mtime: DateTime.t(),
          uid: integer(),
          gid: integer(),
          nlink: integer(),
          mode: integer(),
          sha256: String.t() | nil,
          md5: String.t() | nil,
          mime_type: String.t() | nil,
          charset: String.t() | nil,
          tags: [String.t()] | nil,
          source: String.t() | nil,
          indexed_at: DateTime.t() | nil
        }
  @derive Jason.Encoder
  defstruct [
    :filename,
    :extension,
    :dirname,
    :path,
    :hidden?,
    :size,
    :ctime,
    :mtime,
    :uid,
    :gid,
    :nlink,
    :mode,
    :sha256,
    :md5,
    :mime_type,
    :charset,
    :tags,
    :source,
    :indexed_at
  ]

  # Helper function to convert :calendar.datetime() to DateTime
  def from_file_stat(%File.Stat{} = stat, path) do
    %__MODULE__{
      filename: Path.basename(path),
      extension: Path.extname(path),
      dirname: Path.dirname(path),
      path: path,
      hidden?: String.starts_with?(Path.basename(path), "."),
      size: stat.size,
      ctime: calendar_datetime_to_datetime(stat.ctime),
      mtime: calendar_datetime_to_datetime(stat.mtime),
      uid: stat.uid,
      gid: stat.gid,
      nlink: stat.links,
      mode: stat.mode
    }
  end

  defp calendar_datetime_to_datetime({{year, month, day}, {hour, minute, second}}) do
    {:ok, datetime} = DateTime.new(Date.new!(year, month, day), Time.new!(hour, minute, second))
    datetime
  end
end
