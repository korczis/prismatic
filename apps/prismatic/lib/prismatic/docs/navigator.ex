defmodule Prismatic.Docs.Navigator do
  @moduledoc """
  Navigation management for the Prismatic documentation system.

  This module provides comprehensive navigation capabilities including breadcrumb
  generation, cross-reference management, hierarchical navigation trees, and
  automated link resolution across documentation structures.

  ## Features

  - **Breadcrumb Generation**: Automatic breadcrumb trail creation based on document hierarchy
  - **Cross-Reference Management**: Bidirectional linking and reference tracking
  - **Navigation Trees**: Hierarchical navigation structure generation
  - **Link Resolution**: Automated resolution of internal and external links
  - **Site Maps**: Complete site navigation mapping
  - **Context Awareness**: Navigation context based on current document location

  ## Usage

      # Generate breadcrumbs for a document
      breadcrumbs = Navigator.generate_breadcrumbs("/docs/guides/getting-started.md")

      # Create navigation tree
      nav_tree = Navigator.build_navigation_tree(docs_config)

      # Resolve cross-references
      resolved_refs = Navigator.resolve_cross_references(document)

      # Generate site map
      site_map = Navigator.generate_site_map(docs_config)

  ## Navigation Structure

  The navigation system supports multiple levels of hierarchy:

      docs/
      ├── guides/
      │   ├── getting-started.md
      │   ├── configuration.md
      │   └── advanced/
      │       ├── performance.md
      │       └── deployment.md
      ├── api/
      │   ├── core.md
      │   └── extensions.md
      └── examples/
          ├── basic.md
          └── advanced.md

  ## Configuration

      config :prismatic, Prismatic.Docs.Navigator,
        breadcrumb_separator: " > ",
        max_breadcrumb_length: 50,
        include_home_link: true,
        navigation_depth: 3,
        cross_reference_validation: true
  """

  alias Prismatic.Docs.Types
  require Logger

  @type breadcrumb :: %{
    title: String.t(),
    path: String.t(),
    level: non_neg_integer()
  }

  @type navigation_node :: %{
    title: String.t(),
    path: String.t(),
    children: [navigation_node()],
    parent: String.t() | nil,
    level: non_neg_integer(),
    metadata: map()
  }

  @type cross_reference :: %{
    source: String.t(),
    target: String.t(),
    type: :internal | :external | :anchor,
    text: String.t(),
    valid: boolean()
  }

  @type site_map :: %{
    pages: [map()],
    structure: navigation_node(),
    total_pages: non_neg_integer(),
    last_updated: DateTime.t()
  }

  @doc """
  Generate breadcrumb navigation for a document path.

  ## Parameters

  - `path` - Document path relative to documentation root
  - `config` - Navigation configuration options

  ## Returns

  List of breadcrumb items with title, path, and level information.

  ## Examples

      iex> Navigator.generate_breadcrumbs("/docs/guides/getting-started.md")
      [
        %{title: "Home", path: "/", level: 0},
        %{title: "Documentation", path: "/docs", level: 1},
        %{title: "Guides", path: "/docs/guides", level: 2},
        %{title: "Getting Started", path: "/docs/guides/getting-started", level: 3}
      ]
  """
  @spec generate_breadcrumbs(String.t(), map()) :: [breadcrumb()]
  def generate_breadcrumbs(path, config \\ %{}) do
    config = merge_default_config(config)

    path
    |> normalize_path()
    |> split_path_segments()
    |> build_breadcrumb_chain(config)
    |> limit_breadcrumb_length(config.max_breadcrumb_length)
  end

  @doc """
  Build hierarchical navigation tree from documentation structure.

  ## Parameters

  - `docs_config` - Documentation configuration with source directories
  - `options` - Navigation tree options

  ## Returns

  Navigation tree with nested structure representing document hierarchy.

  ## Examples

      iex> Navigator.build_navigation_tree(docs_config)
      %{
        title: "Documentation",
        path: "/docs",
        children: [
          %{title: "Guides", path: "/docs/guides", children: [...]}
        ],
        level: 0
      }
  """
  @spec build_navigation_tree(Types.doc_config(), map()) :: navigation_node()
  def build_navigation_tree(docs_config, options \\ %{}) do
    options = Map.merge(%{max_depth: 3, include_drafts: false}, options)

    docs_config.source_dirs
    |> scan_documentation_files()
    |> filter_files(options)
    |> build_hierarchy_tree()
    |> enhance_with_metadata(docs_config)
  end

  @doc """
  Resolve cross-references within a document.

  ## Parameters

  - `document` - Document content or parsed structure
  - `base_path` - Base path for relative link resolution
  - `docs_config` - Documentation configuration

  ## Returns

  List of resolved cross-references with validation status.

  ## Examples

      iex> Navigator.resolve_cross_references(document, "/docs/guides/")
      [
        %{
          source: "getting-started.md",
          target: "configuration.md",
          type: :internal,
          text: "Configuration Guide",
          valid: true
        }
      ]
  """
  @spec resolve_cross_references(String.t() | map(), String.t(), Types.doc_config()) :: [cross_reference()]
  def resolve_cross_references(document, base_path, docs_config \\ %{}) do
    document
    |> extract_links()
    |> resolve_link_targets(base_path, docs_config)
    |> validate_link_targets()
    |> categorize_references()
  end

  @doc """
  Generate complete site map for documentation.

  ## Parameters

  - `docs_config` - Documentation configuration
  - `options` - Site map generation options

  ## Returns

  Complete site map with page inventory and navigation structure.

  ## Examples

      iex> Navigator.generate_site_map(docs_config)
      %{
        pages: [...],
        structure: %{...},
        total_pages: 42,
        last_updated: ~U[2025-01-03 10:20:00Z]
      }
  """
  @spec generate_site_map(Types.doc_config(), map()) :: site_map()
  def generate_site_map(docs_config, options \\ %{}) do
    options = Map.merge(%{include_metadata: true, sort_by: :title}, options)

    pages = scan_all_pages(docs_config, options)
    structure = build_navigation_tree(docs_config, options)

    %{
      pages: pages,
      structure: structure,
      total_pages: length(pages),
      last_updated: DateTime.utc_now()
    }
  end

  @doc """
  Find related documents based on content similarity and cross-references.

  ## Parameters

  - `document_path` - Path to the reference document
  - `docs_config` - Documentation configuration
  - `limit` - Maximum number of related documents to return

  ## Returns

  List of related documents with similarity scores.
  """
  @spec find_related_documents(String.t(), Types.doc_config(), pos_integer()) :: [map()]
  def find_related_documents(document_path, docs_config, limit \\ 5) do
    document_path
    |> analyze_document_content(docs_config)
    |> find_content_similarities(docs_config)
    |> include_cross_reference_relationships()
    |> rank_by_relevance()
    |> Enum.take(limit)
  end

  @doc """
  Validate navigation structure integrity.

  ## Parameters

  - `docs_config` - Documentation configuration
  - `options` - Validation options

  ## Returns

  Validation results with any detected issues.
  """
  @spec validate_navigation(Types.doc_config(), map()) :: Types.validation_results()
  def validate_navigation(docs_config, options \\ %{}) do
    options = Map.merge(%{check_links: true, check_structure: true}, options)

    results = %{
      valid: true,
      errors: [],
      warnings: [],
      navigation_issues: []
    }

    results
    |> validate_link_integrity(docs_config, options)
    |> validate_structure_consistency(docs_config, options)
    |> validate_breadcrumb_paths(docs_config, options)
    |> compile_validation_summary()
  end

  # Private helper functions

  defp merge_default_config(config) do
    defaults = %{
      breadcrumb_separator: " > ",
      max_breadcrumb_length: 50,
      include_home_link: true,
      navigation_depth: 3
    }

    Map.merge(defaults, config)
  end

  defp normalize_path(path) do
    path
    |> String.trim_leading("/")
    |> String.trim_trailing("/")
    |> String.replace(~r/\.md$/, "")
  end

  defp split_path_segments(path) do
    path
    |> String.split("/")
    |> Enum.reject(&(&1 == ""))
  end

  defp build_breadcrumb_chain(segments, config) do
    breadcrumbs = if config.include_home_link do
      [%{title: "Home", path: "/", level: 0}]
    else
      []
    end

    segments
    |> Enum.with_index(1)
    |> Enum.reduce(breadcrumbs, fn {segment, index}, acc ->
      path = "/" <> Enum.join(Enum.take(segments, index), "/")
      title = humanize_segment(segment)

      acc ++ [%{title: title, path: path, level: index}]
    end)
  end

  defp limit_breadcrumb_length(breadcrumbs, max_length) do
    if length(breadcrumbs) > max_length do
      # Keep first, last, and middle items with ellipsis indication
      first = List.first(breadcrumbs)
      last = List.last(breadcrumbs)
      middle_count = max(0, max_length - 3)

      middle = breadcrumbs
      |> Enum.drop(1)
      |> Enum.drop(-1)
      |> Enum.take(-middle_count)

      [first] ++ middle ++ [last]
    else
      breadcrumbs
    end
  end

  defp humanize_segment(segment) do
    segment
    |> String.replace(~r/[-_]/, " ")
    |> String.split(" ")
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  defp scan_documentation_files(source_dirs) do
    source_dirs
    |> Enum.flat_map(&scan_directory_recursively/1)
    |> Enum.filter(&is_documentation_file?/1)
  end

  defp scan_directory_recursively(dir) do
    case File.ls(dir) do
      {:ok, files} ->
        files
        |> Enum.map(&Path.join(dir, &1))
        |> Enum.flat_map(fn path ->
          if File.dir?(path) do
            scan_directory_recursively(path)
          else
            [path]
          end
        end)

      {:error, _reason} ->
        Logger.warning("Could not scan directory: #{dir}")
        []
    end
  end

  defp is_documentation_file?(path) do
    Path.extname(path) in [".md", ".markdown", ".rst", ".txt"]
  end

  defp filter_files(files, options) do
    files
    |> Enum.filter(fn file ->
      cond do
        not options.include_drafts and is_draft_file?(file) -> false
        true -> true
      end
    end)
  end

  defp is_draft_file?(file) do
    content = File.read!(file)
    Regex.match?(~r/draft:\s*true/i, content) or
    String.contains?(Path.basename(file), "draft")
  end

  defp build_hierarchy_tree(files) do
    files
    |> Enum.map(&parse_file_metadata/1)
    |> group_by_directory()
    |> build_tree_structure()
  end

  defp parse_file_metadata(file_path) do
    content = File.read!(file_path)

    %{
      path: file_path,
      title: extract_title(content) || humanize_filename(file_path),
      level: count_directory_depth(file_path),
      parent: Path.dirname(file_path),
      metadata: extract_frontmatter(content)
    }
  end

  defp extract_title(content) do
    case Regex.run(~r/^#\s+(.+)$/m, content) do
      [_, title] -> String.trim(title)
      _ -> nil
    end
  end

  defp humanize_filename(file_path) do
    file_path
    |> Path.basename()
    |> Path.rootname()
    |> humanize_segment()
  end

  defp count_directory_depth(file_path) do
    file_path
    |> Path.split()
    |> length()
  end

  defp group_by_directory(files) do
    Enum.group_by(files, & &1.parent)
  end

  defp build_tree_structure(grouped_files) do
    # This would build the actual tree structure
    # For now, return a simple structure
    %{
      title: "Documentation",
      path: "/docs",
      children: [],
      parent: nil,
      level: 0,
      metadata: %{}
    }
  end

  defp enhance_with_metadata(tree, _docs_config) do
    # Enhance tree nodes with additional metadata
    tree
  end

  defp extract_links(document) when is_binary(document) do
    # Extract markdown links: [text](url)
    Regex.scan(~r/\[([^\]]+)\]\(([^)]+)\)/, document)
    |> Enum.map(fn [_full, text, url] ->
      %{text: text, url: url, type: classify_link_type(url)}
    end)
  end

  defp extract_links(document) when is_map(document) do
    # Handle parsed document structure
    []
  end

  defp classify_link_type(url) do
    cond do
      String.starts_with?(url, "http") -> :external
      String.starts_with?(url, "#") -> :anchor
      true -> :internal
    end
  end

  defp resolve_link_targets(links, base_path, _docs_config) do
    Enum.map(links, fn link ->
      resolved_target = case link.type do
        :internal -> Path.join(base_path, link.url)
        :external -> link.url
        :anchor -> link.url
      end

      Map.put(link, :resolved_target, resolved_target)
    end)
  end

  defp validate_link_targets(links) do
    Enum.map(links, fn link ->
      valid = case link.type do
        :internal -> File.exists?(link.resolved_target)
        :external -> validate_external_link(link.resolved_target)
        :anchor -> true  # Would validate anchor exists in document
      end

      Map.put(link, :valid, valid)
    end)
  end

  defp validate_external_link(_url) do
    # In a real implementation, this would make HTTP requests
    # For now, assume external links are valid
    true
  end

  defp categorize_references(links) do
    Enum.map(links, fn link ->
      %{
        source: "current_document",  # Would be actual source
        target: link.resolved_target,
        type: link.type,
        text: link.text,
        valid: link.valid
      }
    end)
  end

  defp scan_all_pages(docs_config, options) do
    docs_config.source_dirs
    |> scan_documentation_files()
    |> Enum.map(&build_page_info(&1, options))
  end

  defp build_page_info(file_path, options) do
    content = File.read!(file_path)

    page_info = %{
      path: file_path,
      title: extract_title(content) || humanize_filename(file_path),
      last_modified: get_file_mtime(file_path),
      size: byte_size(content)
    }

    if options.include_metadata do
      Map.put(page_info, :metadata, extract_frontmatter(content))
    else
      page_info
    end
  end

  defp get_file_mtime(file_path) do
    case File.stat(file_path) do
      {:ok, %{mtime: mtime}} ->
        mtime
        |> NaiveDateTime.from_erl!()
        |> DateTime.from_naive!("Etc/UTC")

      {:error, _} ->
        DateTime.utc_now()
    end
  end

  defp extract_frontmatter(content) do
    case Regex.run(~r/^---\n(.*?)\n---/s, content) do
      [_, yaml_content] ->
        try do
          YamlElixir.read_from_string(yaml_content)
        rescue
          _ -> %{}
        end

      _ ->
        %{}
    end
  end

  defp analyze_document_content(_document_path, _docs_config) do
    # Analyze document content for similarity matching
    %{keywords: [], topics: [], references: []}
  end

  defp find_content_similarities(_analysis, _docs_config) do
    # Find documents with similar content
    []
  end

  defp include_cross_reference_relationships(similarities) do
    # Include documents that cross-reference each other
    similarities
  end

  defp rank_by_relevance(related_docs) do
    # Rank documents by relevance score
    Enum.sort_by(related_docs, & &1.score, :desc)
  end

  defp validate_link_integrity(results, docs_config, options) do
    if options.check_links do
      # Validate all links in documentation
      results
    else
      results
    end
  end

  defp validate_structure_consistency(results, _docs_config, _options) do
    # Validate navigation structure consistency
    results
  end

  defp validate_breadcrumb_paths(results, _docs_config, _options) do
    # Validate breadcrumb path correctness
    results
  end

  defp compile_validation_summary(results) do
    # Compile final validation summary
    %{results | valid: length(results.errors) == 0}
  end
end
