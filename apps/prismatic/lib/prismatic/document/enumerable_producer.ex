defmodule Prismatic.Document.EnumerableProducer do
  def stream!(opts) do
    path = Keyword.fetch!(opts, :path)
    enrichers = Keyword.get(opts, :enrich, [])

    path
    |> Prismatic.FS.Reader.stream_dir()
    |> Stream.map(&Prismatic.Document.new/1)
    |> Prismatic.Document.attach(enrichers)
    |> Stream.map(
      &%Broadway.Message{
        data: &1,
        acknowledger: {__MODULE__, :ack_id, nil}
      }
    )
  end

  def ack(:ack_id, _ok, _failed), do: :ok
end
