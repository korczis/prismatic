defmodule Prismatic.Document.BroadwayProducer do
  @moduledoc """
  Proper Broadway producer that emits enriched documents.
  """
  use GenStage
  @behaviour Broadway.Producer

  alias Prismatic.FS.Reader
  alias Prismatic.Document

  def start_link(opts) do
    GenStage.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    {:producer, %{opts: opts, queue: build_stream(opts) |> Enum.to_list()}}
  end

  @impl true
  def handle_demand(demand, state = %{queue: queue}) do
    {events, rest} = Enum.split(queue, demand)

    messages =
      events
      |> Enum.map(fn data ->
        %Broadway.Message{
          data: data,
          acknowledger: {__MODULE__, :ack_id, :ack_data}
        }
      end)

    {:noreply, messages, %{state | queue: rest}}
  end

  defp build_stream(opts) do
    path = Keyword.fetch!(opts, :path)
    enrichers = Keyword.get(opts, :enrich, [])

    path
    |> Reader.stream_dir()
    |> Stream.map(&Document.new/1)
    |> Document.attach(enrichers)
  end

  # Broadway.Producer callback for graceful shutdown
  @impl Broadway.Producer
  def prepare_for_draining(_state) do
    # Return any remaining messages that should be processed before shutdown
    []
  end

  # Broadway.Producer callback for initialization
  @impl Broadway.Producer
  def prepare_for_start(_module, _opts) do
    # Return any setup configuration needed
    {[], []}
  end

  # Acknowledger functions - these are called by Broadway's acknowledgment system
  def ack(_ack_ref, successful, failed) do
    # Log successful and failed message processing if needed
    if length(failed) > 0 do
      # You might want to log failures here
      :ok
    end

    if length(successful) > 0 do
      # You might want to log successes here
      :ok
    end

    :ok
  end
end
