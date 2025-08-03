defmodule Prismatic.TODO.Scanner do
  @moduledoc """
  Advanced TODO comment scanning and discovery for the Prismatic TODO management system.

  This module provides comprehensive scanning capabilities to discover, parse, and
  categorize TODO comments across codebases. It supports multiple comment formats,
  metadata extraction, and intelligent categorization of TODO items.

  ## Features

  - **Multi-Format Scanning**: Support for various TODO comment formats and styles
  - **Metadata Extraction**: Automatic parsing of TODO metadata and context
  - **Intelligent Categorization**: Automated categorization based on content analysis
  - **Incremental Scanning**: Efficient scanning of only changed files
  - **Context Analysis**: Analysis of surrounding code for better understanding
  - **Custom Pattern Support**: Configurable patterns for domain-specific TODO formats

  ## Usage

      # Scan entire codebase
      {:ok, scan_result} = Scanner.scan_todos(["lib", "apps"])

      # Incremental scan of changed files
      {:ok, scan_result} = Scanner.scan_todos_incremental(["lib"], last_scan_time)

      # Scan with custom patterns
      {:ok, scan_result} = Scanner.scan_todos(["lib"], custom_patterns: [~r/FIXME:/])

      # Parse individual TODO comment
      {:ok, todo_item} = Scanner.parse_todo_comment(comment_text, context)

  ## TODO Comment Formats

  The scanner recognizes various TODO comment formats:

      # Standard formats
      # TODO: Basic task description
      # FIXME: Something that needs fixing
      # HACK: Temporary workaround
      # BUG: Known bug that needs addressing

      # Enhanced formats with metadata
      # TODO: [FEATURE:HIGH] Implement user authentication
      # Context: Required for MVP release
      # Dependencies: [UserModule, AuthController]
      # Estimate: 4h
      # Assignee: developer@company.com
      # Related: #123, PR#456
      # Created: 2025-01-03
      # Due: 2025-01-10

  ## Configuration

      config :prismatic, Prismatic.TODO.Scanner,
        scan_patterns: [
          ~r/(?:TODO|FIXME|HACK|BUG|NOTE|XXX):\s*(.+)/i,
          ~r/\/\*\s*TODO:\s*(.*?)\s*\*\//s
        ],
        file_patterns: ["**/*.{ex,exs,js,ts,py,rb,java,c,cpp,h}"],
        exclude_patterns: [~r/_build/, ~r/deps/, ~r/\.git/],
        context_lines: 3,
        metadata_patterns: %{
          category: ~r/\[(\w+)(?::(\w+))?\]/,
          assignee: ~r/Assignee:\s*([^\s]+)/i,
          estimate: ~r/Estimate:\s*([^\n]+)/i,
          dependencies: ~r/Dependencies:\s*\[([^\]]+)\]/i,
          related: ~r/Related:\s*([^\n]+)/i,
          due_date: ~r/Due:\s*(\d{4}-\d{2}-\d{2})/i
        }
  """

  require Logger

  @type scan_options :: %{
    incremental: boolean(),
    file_patterns: [String.t()],
    exclude_patterns: [Regex.t()],
    custom_patterns: [Regex.t()],
    context_lines: non_neg_integer(),
    include_metadata: boolean()
  }

  @type scan_result :: %{
    total_todos: non_neg_integer(),
    new_todos: non_neg_integer(),
    updated_todos: non_neg_integer(),
    completed_todos: non_neg_integer(),
    files_scanned: non_neg_integer(),
    scan_duration_ms: non_neg_integer(),
    categories: %{atom() => non_neg_integer()},
    priorities: %{atom() => non_neg_integer()},
    todos: [todo_item()]
  }

  @type todo_item :: %{
    id: String.t(),
    type: :todo | :fixme | :hack | :bug | :note | :xxx,
    category: :bug | :feature | :refactor | :docs | :test | :security | :performance | :tech_debt,
    priority: :critical | :high | :medium | :low,
    status: :open | :in_progress | :review | :completed,
    title: String.t(),
    description: String.t(),
    file_path: String.t(),
    line_number: non_neg_integer(),
    column_number: non_neg_integer(),
    context: %{
      before_lines: [String.t()],
      after_lines: [String.t()],
      function_name: String.t() | nil,
      module_name: String.t() | nil
    },
    metadata: %{
      assignee: String.t() | nil,
      estimate: String.t() | nil,
      dependencies: [String.t()],
      related_items: [String.t()],
      due_date: Date.t() | nil,
      created_at: DateTime.t(),
      updated_at: DateTime.t()
    }
  }

  @default_scan_patterns [
    ~r/(?:TODO|FIXME|HACK|BUG|NOTE|XXX):\s*(.+)/i,
    ~r/\/\*\s*(TODO|FIXME|HACK|BUG|NOTE|XXX):\s*(.*?)\s*\*\//s
  ]

  @default_file_patterns ["**/*.{ex,exs,js,ts,py,rb,java,c,cpp,h,php,go,rs,swift}"]

  @default_exclude_patterns [~r/_build/, ~r/deps/, ~r/\.git/, ~r/node_modules/]

  @doc """
  Scan directories for TODO comments and return comprehensive results.

  ## Parameters

  - `source_dirs` - List of directories to scan
  - `options` - Scanning options and configuration

  ## Returns

  Complete scan results with discovered TODO items and metadata.

  ## Examples

      iex> Scanner.scan_todos(["lib", "apps"])
      {:ok, %{
        total_todos: 42,
        new_todos: 5,
        files_scanned: 127,
        todos: [%{id: "TODO_001", title: "...", ...}]
      }}
  """
  @spec scan_todos([String.t()], scan_options()) :: {:ok, scan_result()} | {:error, term()}
  def scan_todos(source_dirs, options \\ %{}) do
    Logger.info("Starting TODO scan in directories: #{inspect(source_dirs)}")

    options = merge_default_options(options)
    start_time = System.monotonic_time(:millisecond)

    with {:ok, files_to_scan} <- build_file_list(source_dirs, options),
         {:ok, scan_results} <- scan_files_for_todos(files_to_scan, options),
         {:ok, processed_todos} <- process_discovered_todos(scan_results, options) do

      end_time = System.monotonic_time(:millisecond)
      scan_duration = end_time - start_time

      result = %{
        total_todos: length(processed_todos),
        new_todos: count_new_todos(processed_todos),
        updated_todos: count_updated_todos(processed_todos),
        completed_todos: count_completed_todos(processed_todos),
        files_scanned: length(files_to_scan),
        scan_duration_ms: scan_duration,
        categories: group_by_category(processed_todos),
        priorities: group_by_priority(processed_todos),
        todos: processed_todos
      }

      Logger.info("TODO scan completed: #{result.total_todos} todos found in #{result.files_scanned} files")
      {:ok, result}
    else
      {:error, reason} ->
        Logger.error("TODO scan failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Perform incremental scan of TODO comments since last scan time.

  ## Parameters

  - `source_dirs` - List of directories to scan
  - `last_scan_time` - Timestamp of last scan for incremental processing
  - `options` - Scanning options

  ## Returns

  Incremental scan results with only changed TODO items.

  ## Examples

      iex> Scanner.scan_todos_incremental(["lib"], ~U[2025-01-03 10:00:00Z])
      {:ok, %{
        total_todos: 3,
        new_todos: 2,
        updated_todos: 1,
        files_scanned: 15
      }}
  """
  @spec scan_todos_incremental([String.t()], DateTime.t(), scan_options()) :: {:ok, scan_result()} | {:error, term()}
  def scan_todos_incremental(source_dirs, last_scan_time, options \\ %{}) do
    Logger.info("Starting incremental TODO scan since #{last_scan_time}")

    options = Map.put(options, :incremental, true)

    with {:ok, files_to_scan} <- build_file_list(source_dirs, options),
         {:ok, changed_files} <- filter_changed_files(files_to_scan, last_scan_time),
         {:ok, _scan_results} <- scan_files_for_todos(changed_files, options) do

      # For incremental scans, we'd compare with previous state
      # For now, return the basic scan results
      scan_todos(changed_files, options)
    else
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Parse a single TODO comment and extract metadata.

  ## Parameters

  - `comment_text` - The TODO comment text to parse
  - `context` - Context information (file, line, surrounding code)
  - `options` - Parsing options

  ## Returns

  Parsed TODO item with extracted metadata.

  ## Examples

      iex> Scanner.parse_todo_comment("TODO: [FEATURE:HIGH] Add user auth", context)
      {:ok, %{
        type: :todo,
        category: :feature,
        priority: :high,
        title: "Add user auth",
        metadata: %{...}
      }}
  """
  @spec parse_todo_comment(String.t(), map(), map()) :: {:ok, todo_item()} | {:error, term()}
  def parse_todo_comment(comment_text, context, options \\ %{}) do
    try do
      todo_item = comment_text
      |> extract_basic_todo_info()
      |> enhance_with_metadata(comment_text, options)
      |> add_context_information(context)
      |> add_generated_metadata()

      {:ok, todo_item}
    rescue
      error ->
        {:error, "Failed to parse TODO comment: #{Exception.message(error)}"}
    end
  end

  @doc """
  Extract context information around TODO comments for better understanding.

  ## Parameters

  - `file_path` - Path to the file containing the TODO
  - `line_number` - Line number of the TODO comment
  - `context_lines` - Number of context lines to extract before and after

  ## Returns

  Context information including surrounding code and function/module names.

  ## Examples

      iex> Scanner.extract_todo_context("lib/my_module.ex", 42, 3)
      {:ok, %{
        before_lines: ["def some_function do", "  # Setup code", "  value = calculate()"],
        after_lines: ["  process_value(value)", "end"],
        function_name: "some_function",
        module_name: "MyModule"
      }}
  """
  @spec extract_todo_context(String.t(), non_neg_integer(), non_neg_integer()) :: {:ok, map()} | {:error, term()}
  def extract_todo_context(file_path, line_number, context_lines \\ 3) do
    case File.read(file_path) do
      {:ok, content} ->
        lines = String.split(content, "\n")
        total_lines = length(lines)

        before_start = max(0, line_number - context_lines - 1)
        before_end = max(0, line_number - 2)
        after_start = min(line_number, total_lines - 1)
        after_end = min(line_number + context_lines - 1, total_lines - 1)

        before_lines = if before_start <= before_end do
          Enum.slice(lines, before_start, before_end - before_start + 1)
        else
          []
        end

        after_lines = if after_start <= after_end do
          Enum.slice(lines, after_start, after_end - after_start + 1)
        else
          []
        end

        context = %{
          before_lines: before_lines,
          after_lines: after_lines,
          function_name: extract_function_name(lines, line_number),
          module_name: extract_module_name(content)
        }

        {:ok, context}

      {:error, reason} ->
        {:error, "Could not read file #{file_path}: #{reason}"}
    end
  end

  @doc """
  Categorize TODO items based on content analysis and patterns.

  ## Parameters

  - `todos` - List of TODO items to categorize
  - `options` - Categorization options

  ## Returns

  TODO items with updated categories based on content analysis.

  ## Examples

      iex> Scanner.categorize_todos(todos)
      {:ok, [
        %{category: :bug, title: "Fix memory leak in worker process"},
        %{category: :feature, title: "Add OAuth integration"}
      ]}
  """
  @spec categorize_todos([todo_item()], map()) :: {:ok, [todo_item()]} | {:error, term()}
  def categorize_todos(todos, options \\ %{}) do
    categorized_todos = todos
    |> Enum.map(&categorize_single_todo(&1, options))

    {:ok, categorized_todos}
  end

  # Private helper functions

  defp merge_default_options(options) do
    defaults = %{
      incremental: false,
      file_patterns: @default_file_patterns,
      exclude_patterns: default_exclude_patterns(),
      custom_patterns: [],
      context_lines: 3,
      include_metadata: true,
      scan_patterns: default_scan_patterns()
    }

    Map.merge(defaults, options)
  end

  defp default_exclude_patterns do
    [~r/_build/, ~r/deps/, ~r/\.git/, ~r/node_modules/]
  end

  defp default_scan_patterns do
    [
      ~r/(?:TODO|FIXME|HACK|BUG|NOTE|XXX):\s*(.+)/i,
      ~r/\/\*\s*(TODO|FIXME|HACK|BUG|NOTE|XXX):\s*(.*?)\s*\*\//s
    ]
  end

  defp build_file_list(source_dirs, options) do
    file_patterns = options.file_patterns
    exclude_patterns = options.exclude_patterns

    files = source_dirs
    |> Enum.flat_map(fn dir ->
      file_patterns
      |> Enum.flat_map(&Path.wildcard(Path.join(dir, &1)))
    end)
    |> Enum.uniq()
    |> Enum.reject(fn file ->
      Enum.any?(exclude_patterns, &Regex.match?(&1, file))
    end)
    |> Enum.filter(&File.regular?/1)

    {:ok, files}
  end

  defp filter_changed_files(files, last_scan_time) do
    changed_files = files
    |> Enum.filter(fn file ->
      case File.stat(file) do
        {:ok, %{mtime: mtime}} ->
          file_time = mtime |> NaiveDateTime.from_erl!() |> DateTime.from_naive!("Etc/UTC")
          DateTime.compare(file_time, last_scan_time) == :gt

        {:error, _} -> false
      end
    end)

    {:ok, changed_files}
  end

  defp scan_files_for_todos(files, options) do
    scan_patterns = options.scan_patterns ++ options.custom_patterns

    scan_results = files
    |> Enum.flat_map(fn file ->
      scan_single_file(file, scan_patterns, options)
    end)

    {:ok, scan_results}
  end

  defp scan_single_file(file_path, scan_patterns, options) do
    case File.read(file_path) do
      {:ok, content} ->
        lines = String.split(content, "\n")

        lines
        |> Enum.with_index(1)
        |> Enum.flat_map(fn {line, line_number} ->
          scan_patterns
          |> Enum.flat_map(fn pattern ->
            case Regex.run(pattern, line, capture: :all) do
              nil -> []
              matches ->
                [create_todo_from_match(matches, file_path, line_number, line, content, options)]
            end
          end)
        end)

      {:error, reason} ->
        Logger.warning("Could not read file #{file_path}: #{reason}")
        []
    end
  end

  defp create_todo_from_match(matches, file_path, line_number, line, content, options) do
    [full_match | captured_groups] = matches

    # Extract the TODO type and content
    {todo_type, todo_content} = parse_match_groups(captured_groups, full_match)

    # Extract context if enabled
    context = if options.include_metadata do
      case extract_todo_context(file_path, line_number, options.context_lines) do
        {:ok, ctx} -> ctx
        {:error, _} -> %{before_lines: [], after_lines: [], function_name: nil, module_name: nil}
      end
    else
      %{before_lines: [], after_lines: [], function_name: nil, module_name: nil}
    end

    # Create basic TODO item
    %{
      raw_match: full_match,
      type: todo_type,
      content: todo_content,
      file_path: file_path,
      line_number: line_number,
      column_number: find_column_number(line, full_match),
      context: context,
      full_line: line
    }
  end

  defp parse_match_groups([], full_match) do
    # If no captured groups, try to extract from full match
    case Regex.run(~r/(TODO|FIXME|HACK|BUG|NOTE|XXX):\s*(.+)/i, full_match) do
      [_, type, content] -> {String.downcase(type) |> String.to_atom(), String.trim(content)}
      _ -> {:todo, String.trim(full_match)}
    end
  end

  defp parse_match_groups([content], _full_match) do
    # Single captured group - assume it's the content
    {:todo, String.trim(content)}
  end

  defp parse_match_groups([type, content], _full_match) do
    # Two captured groups - type and content
    todo_type = type |> String.downcase() |> String.to_atom()
    {todo_type, String.trim(content)}
  end

  defp find_column_number(line, match) do
    case :binary.match(line, match) do
      {pos, _length} -> pos + 1
      :nomatch -> 1
    end
  end

  defp process_discovered_todos(scan_results, options) do
    processed_todos = scan_results
    |> Enum.map(&process_single_todo(&1, options))
    |> Enum.reject(&is_nil/1)

    {:ok, processed_todos}
  end

  defp process_single_todo(raw_todo, options) do
    try do
      raw_todo
      |> convert_to_todo_item()
      |> enhance_with_metadata(raw_todo.content, options)
      |> categorize_single_todo(options)
      |> prioritize_single_todo(options)
    rescue
      error ->
        Logger.warning("Failed to process TODO: #{Exception.message(error)}")
        nil
    end
  end

  defp convert_to_todo_item(raw_todo) do
    %{
      id: generate_todo_id(raw_todo),
      type: raw_todo.type,
      category: :unknown,
      priority: :medium,
      status: :open,
      title: extract_title_from_content(raw_todo.content),
      description: raw_todo.content,
      file_path: raw_todo.file_path,
      line_number: raw_todo.line_number,
      column_number: raw_todo.column_number,
      context: raw_todo.context,
      metadata: %{
        assignee: nil,
        estimate: nil,
        dependencies: [],
        related_items: [],
        due_date: nil,
        created_at: DateTime.utc_now(),
        updated_at: DateTime.utc_now()
      }
    }
  end

  defp generate_todo_id(raw_todo) do
    # Generate unique ID based on file path, line number, and content hash
    content_hash = :crypto.hash(:md5, raw_todo.content) |> Base.encode16() |> String.slice(0, 8)
    "TODO_#{Path.basename(raw_todo.file_path, Path.extname(raw_todo.file_path))}_#{raw_todo.line_number}_#{content_hash}"
  end

  defp extract_title_from_content(content) do
    # Extract title from TODO content (first sentence or up to first comma/period)
    content
    |> String.trim()
    |> String.split(~r/[.,:;]/)
    |> List.first()
    |> String.trim()
    |> String.slice(0, 100)  # Limit title length
  end

  defp extract_basic_todo_info(comment_text) do
    # Extract basic information from TODO comment
    case Regex.run(~r/(TODO|FIXME|HACK|BUG|NOTE|XXX):\s*(.+)/i, comment_text) do
      [_, type, content] ->
        %{
          type: String.downcase(type) |> String.to_atom(),
          content: String.trim(content)
        }

      _ ->
        %{
          type: :todo,
          content: String.trim(comment_text)
        }
    end
  end

  defp enhance_with_metadata(todo_item, comment_text, options) do
    if options[:include_metadata] do
      metadata_patterns = get_metadata_patterns()

      enhanced_metadata = todo_item.metadata
      |> extract_assignee(comment_text, metadata_patterns)
      |> extract_estimate(comment_text, metadata_patterns)
      |> extract_dependencies(comment_text, metadata_patterns)
      |> extract_related_items(comment_text, metadata_patterns)
      |> extract_due_date(comment_text, metadata_patterns)
      |> extract_category_priority(comment_text, metadata_patterns)

      Map.put(todo_item, :metadata, enhanced_metadata)
    else
      todo_item
    end
  end

  defp get_metadata_patterns do
    %{
      category: ~r/\[(\w+)(?::(\w+))?\]/,
      assignee: ~r/Assignee:\s*([^\s\n]+)/i,
      estimate: ~r/Estimate:\s*([^\n]+)/i,
      dependencies: ~r/Dependencies:\s*\[([^\]]+)\]/i,
      related: ~r/Related:\s*([^\n]+)/i,
      due_date: ~r/Due:\s*(\d{4}-\d{2}-\d{2})/i
    }
  end

  defp extract_assignee(metadata, comment_text, patterns) do
    case Regex.run(patterns.assignee, comment_text) do
      [_, assignee] -> Map.put(metadata, :assignee, String.trim(assignee))
      _ -> metadata
    end
  end

  defp extract_estimate(metadata, comment_text, patterns) do
    case Regex.run(patterns.estimate, comment_text) do
      [_, estimate] -> Map.put(metadata, :estimate, String.trim(estimate))
      _ -> metadata
    end
  end

  defp extract_dependencies(metadata, comment_text, patterns) do
    case Regex.run(patterns.dependencies, comment_text) do
      [_, deps_str] ->
        dependencies = deps_str
        |> String.split(",")
        |> Enum.map(&String.trim/1)
        |> Enum.reject(&(&1 == ""))

        Map.put(metadata, :dependencies, dependencies)

      _ -> metadata
    end
  end

  defp extract_related_items(metadata, comment_text, patterns) do
    case Regex.run(patterns.related, comment_text) do
      [_, related_str] ->
        related_items = related_str
        |> String.split(",")
        |> Enum.map(&String.trim/1)
        |> Enum.reject(&(&1 == ""))

        Map.put(metadata, :related_items, related_items)

      _ -> metadata
    end
  end

  defp extract_due_date(metadata, comment_text, patterns) do
    case Regex.run(patterns.due_date, comment_text) do
      [_, date_str] ->
        case Date.from_iso8601(date_str) do
          {:ok, date} -> Map.put(metadata, :due_date, date)
          {:error, _} -> metadata
        end

      _ -> metadata
    end
  end

  defp extract_category_priority(metadata, comment_text, patterns) do
    case Regex.run(patterns.category, comment_text) do
      [_, category] ->
        Map.put(metadata, :extracted_category, String.downcase(category) |> String.to_atom())

      [_, category, priority] ->
        metadata
        |> Map.put(:extracted_category, String.downcase(category) |> String.to_atom())
        |> Map.put(:extracted_priority, String.downcase(priority) |> String.to_atom())

      _ -> metadata
    end
  end

  defp add_context_information(todo_item, context) do
    Map.put(todo_item, :context, context)
  end

  defp add_generated_metadata(todo_item) do
    now = DateTime.utc_now()

    metadata = todo_item.metadata
    |> Map.put_new(:created_at, now)
    |> Map.put(:updated_at, now)

    Map.put(todo_item, :metadata, metadata)
  end

  defp categorize_single_todo(todo_item, _options) do
    # Use extracted category if available, otherwise categorize by content
    category = case todo_item.metadata[:extracted_category] do
      nil -> categorize_by_content(todo_item.description)
      extracted_cat -> extracted_cat
    end

    Map.put(todo_item, :category, category)
  end

  defp categorize_by_content(content) do
    content_lower = String.downcase(content)

    cond do
      String.contains?(content_lower, ["bug", "fix", "error", "issue", "broken"]) -> :bug
      String.contains?(content_lower, ["test", "testing", "spec", "coverage"]) -> :test
      String.contains?(content_lower, ["security", "auth", "permission", "vulnerable"]) -> :security
      String.contains?(content_lower, ["performance", "slow", "optimize", "speed"]) -> :performance
      String.contains?(content_lower, ["refactor", "cleanup", "reorganize", "simplify"]) -> :refactor
      String.contains?(content_lower, ["doc", "comment", "explain", "readme"]) -> :docs
      String.contains?(content_lower, ["feature", "add", "implement", "new", "enhance"]) -> :feature
      String.contains?(content_lower, ["debt", "hack", "temporary", "workaround"]) -> :tech_debt
      true -> :feature  # Default category
    end
  end

  defp prioritize_single_todo(todo_item, _options) do
    # Use extracted priority if available, otherwise prioritize by content
    priority = case todo_item.metadata[:extracted_priority] do
      nil -> prioritize_by_content_and_type(todo_item)
      extracted_pri -> extracted_pri
    end

    Map.put(todo_item, :priority, priority)
  end

  defp prioritize_by_content_and_type(todo_item) do
    content_lower = String.downcase(todo_item.description)

    cond do
      # Critical priority indicators
      todo_item.type == :bug and String.contains?(content_lower, ["critical", "urgent", "blocking", "production"]) -> :critical
      String.contains?(content_lower, ["asap", "urgent", "critical", "blocker", "security"]) -> :critical

      # High priority indicators
      todo_item.type in [:bug, :fixme] -> :high
      String.contains?(content_lower, ["important", "high", "soon", "deadline"]) -> :high
      todo_item.category == :security -> :high

      # Low priority indicators
      todo_item.type in [:note, :xxx] -> :low
      String.contains?(content_lower, ["nice to have", "someday", "maybe", "eventually"]) -> :low
      todo_item.category == :docs -> :low

      # Default to medium priority
      true -> :medium
    end
  end

  defp extract_function_name(lines, line_number) do
    # Look backwards from the TODO line to find the function definition
    lines
    |> Enum.take(line_number - 1)
    |> Enum.reverse()
    |> Enum.find_value(fn line ->
      case Regex.run(~r/def\s+([a-zA-Z_][a-zA-Z0-9_]*)/, line) do
        [_, function_name] -> function_name
        _ -> nil
      end
    end)
  end

  defp extract_module_name(content) do
    case Regex.run(~r/defmodule\s+([A-Za-z0-9_.]+)/, content) do
      [_, module_name] -> module_name
      _ -> nil
    end
  end

  defp count_new_todos(todos) do
    # In a real implementation, this would compare with previous scan results
    # For now, consider all todos as potentially new
    length(todos)
  end

  defp count_updated_todos(todos) do
    # In a real implementation, this would track changes to existing todos
    0
  end

  defp count_completed_todos(todos) do
    Enum.count(todos, & &1.status == :completed)
  end

  defp group_by_category(todos) do
    todos
    |> Enum.group_by(& &1.category)
    |> Enum.map(fn {category, todo_list} -> {category, length(todo_list)} end)
    |> Enum.into(%{})
  end

  defp group_by_priority(todos) do
    todos
    |> Enum.group_by(& &1.priority)
    |> Enum.map(fn {priority, todo_list} -> {priority, length(todo_list)} end)
    |> Enum.into(%{})
  end
end
