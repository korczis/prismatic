defmodule Prismatic.Document.Stats do
  @moduledoc """
  Collects statistics during document processing
  """

  defstruct [
    :total_files,
    :processed_files,
    :failed_files,
    :start_time,
    :enricher_stats,
    :size_stats,
    :extension_stats
  ]

  def new do
    %__MODULE__{
      total_files: 0,
      processed_files: 0,
      failed_files: 0,
      start_time: System.monotonic_time(:millisecond),
      enricher_stats: %{},
      size_stats: %{total: 0, min: nil, max: 0},
      extension_stats: %{}
    }
  end

  def update_processed(stats) do
    %{stats | processed_files: stats.processed_files + 1}
  end

  def update_failed(stats) do
    %{stats | failed_files: stats.failed_files + 1}
  end

  def update_size(stats, size) do
    size_stats = %{
      total: stats.size_stats.total + size,
      min: if(stats.size_stats.min, do: min(stats.size_stats.min, size), else: size),
      max: max(stats.size_stats.max, size)
    }

    %{stats | size_stats: size_stats}
  end

  def update_extension(stats, ext) do
    extension_stats = Map.update(stats.extension_stats, ext, 1, &(&1 + 1))
    %{stats | extension_stats: extension_stats}
  end

  def duration(stats) do
    System.monotonic_time(:millisecond) - stats.start_time
  end

  def summary(stats) do
    duration_ms = duration(stats)

    %{
      duration_ms: duration_ms,
      files_per_second:
        if(duration_ms > 0, do: stats.processed_files * 1000 / duration_ms, else: 0),
      total_processed: stats.processed_files,
      total_failed: stats.failed_files,
      average_file_size:
        if(stats.processed_files > 0, do: stats.size_stats.total / stats.processed_files, else: 0),
      extensions: stats.extension_stats,
      success_rate:
        if(stats.processed_files + stats.failed_files > 0,
          do: stats.processed_files / (stats.processed_files + stats.failed_files),
          else: 0
        )
    }
  end
end
