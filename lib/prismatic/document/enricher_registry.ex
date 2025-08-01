defmodule Prismatic.Document.EnricherRegistry do
  @moduledoc """
  Registry for managing available enrichers with metadata
  """

  use GenServer

  def start_link(_opts \\ []) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def register(name, module, metadata \\ %{}) do
    GenServer.call(__MODULE__, {:register, name, module, metadata})
  end

  def list_enrichers do
    GenServer.call(__MODULE__, :list)
  end

  def get_enricher(name) do
    GenServer.call(__MODULE__, {:get, name})
  end

  def enrichers_for_extension(ext) do
    GenServer.call(__MODULE__, {:for_extension, ext})
  end

  def init(_) do
    # Register built-in enrichers
    enrichers = %{
      "sha256" =>
        {Prismatic.Document.Enrichers.SHA256,
         %{
           category: :security,
           performance: :slow,
           extensions: :all,
           description: "Computes SHA256 hash of file content"
         }},
      "mime_type" =>
        {Prismatic.Document.Enrichers.MIMEType,
         %{
           category: :metadata,
           performance: :fast,
           extensions: :all,
           description: "Detects MIME type using file command"
         }},
      "frontmatter" =>
        {Prismatic.Document.Enrichers.MarkdownFrontmatter,
         %{
           category: :content,
           performance: :medium,
           extensions: [".md", ".markdown"],
           description: "Extracts YAML/TOML frontmatter from Markdown files"
         }}
    }

    {:ok, enrichers}
  end

  def handle_call({:register, name, module, metadata}, _from, state) do
    {:reply, :ok, Map.put(state, name, {module, metadata})}
  end

  def handle_call(:list, _from, state) do
    enrichers =
      Enum.map(state, fn {name, {module, meta}} ->
        %{name: name, module: module, metadata: meta}
      end)

    {:reply, enrichers, state}
  end

  def handle_call({:get, name}, _from, state) do
    {:reply, Map.get(state, name), state}
  end

  def handle_call({:for_extension, ext}, _from, state) do
    matching =
      state
      |> Enum.filter(fn {_name, {_module, meta}} ->
        meta.extensions == :all or ext in meta.extensions
      end)
      |> Enum.map(fn {name, {module, _meta}} -> {name, module} end)

    {:reply, matching, state}
  end
end
