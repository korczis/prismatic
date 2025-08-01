defmodule Prismatic.Document do
  alias __MODULE__
  alias Prismatic.Document.Metadata
  alias Prismatic.FS.Reader

  @type t :: %__MODULE__{
          path: String.t(),
          metadata: Metadata.t(),
          content: any(),
          enrichments: map(),
          opts: keyword()
        }

  @derive Jason.Encoder
  defstruct [:path, :metadata, :content, enrichments: %{}, opts: []]

  @doc """
  Creates a stream of documents from a directory path.

  ## Examples

      Prismatic.Document.stream("content/")
      |> Prismatic.Document.process(fn doc, opts ->
           IO.inspect(doc.path)
           {:ok, {doc, opts}}
         end)
      |> Stream.run()
  """
  @spec stream(String.t(), keyword()) :: Enumerable.t()
  def stream(path, opts \\ []) do
    path
    |> Reader.stream_dir()
    |> Stream.map(&new(&1, opts))
  end

  @spec new(String.t(), keyword()) :: t()
  def new(path, opts \\ []) do
    %Document{
      path: path,
      opts: opts,
      metadata: extract_metadata(path),
      content: nil
    }
  end

  defp extract_metadata(path) do
    {:ok, stat} = File.stat(path)
    filename = Path.basename(path)
    extension = Path.extname(path)
    dirname = Path.dirname(path)

    %Metadata{
      filename: filename,
      extension: extension,
      dirname: dirname,
      path: path,
      hidden?: String.starts_with?(filename, "."),
      size: stat.size,
      ctime: stat.ctime,
      mtime: stat.mtime,
      uid: stat.uid,
      gid: stat.gid,
      nlink: stat.links,
      mode: stat.mode
    }
  end

  @spec attach(Enumerable.t(), [module()], keyword()) :: Enumerable.t()
  def attach(stream, enrichers, opts \\ []) do
    Enum.reduce(enrichers, stream, fn enricher, acc ->
      Stream.map(acc, fn doc ->
        case enricher.enrich(doc, opts) do
          {:ok, updated} -> updated
          {:error, reason} -> raise "Enricher #{inspect(enricher)} failed: #{inspect(reason)}"
        end
      end)
    end)
  end

  @doc """
  Applies a transformation function to each document in the stream.
  The function must return `{:ok, {doc, opts}}` or `{:error, reason}`.

  ## Example

      Prismatic.Document.stream("content/")
      |> Prismatic.Document.process(fn doc, opts ->
           IO.inspect(doc.path)
           {:ok, {doc, opts}}
         end)
      |> Stream.run()
  """
  @spec process(
          Enumerable.t(),
          (t(), keyword() -> {:ok, {t(), keyword()}} | {:error, any()}),
          keyword()
        ) :: Enumerable.t()
  def process(stream, fun, opts \\ []) do
    Stream.map(stream, fn doc ->
      case fun.(doc, opts) do
        {:ok, {new_doc, new_opts}} -> %{new_doc | opts: new_opts}
        {:error, reason} -> raise "Processing failed: #{inspect(reason)}"
      end
    end)
  end
end
