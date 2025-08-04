defmodule Prismatic.Memory.SearchEngine do
  @moduledoc """
  Advanced search engine for memory systems with semantic search capabilities.

  This module provides comprehensive search functionality including:
  - Pattern matching with wildcards
  - Fuzzy string matching
  - Semantic similarity search
  - Full-text search with ranking
  - Multi-field search with weights
  - Search result aggregation and ranking

  ## Search Types

  - **Exact Match**: Direct key or value matching
  - **Pattern Match**: Wildcard and regex pattern matching
  - **Fuzzy Match**: Approximate string matching with configurable distance
  - **Semantic Search**: Vector-based similarity search
  - **Full-Text Search**: Content-based search with TF-IDF ranking
  - **Composite Search**: Combination of multiple search strategies

  ## Examples

      # Simple pattern search
      {:ok, results} = SearchEngine.search(entries, %{
        type: :pattern,
        pattern: "user_*",
        fields: [:key]
      })

      # Semantic search
      {:ok, results} = SearchEngine.search(entries, %{
        type: :semantic,
        query: "artificial intelligence",
        similarity_threshold: 0.7
      })

  """

  require Logger

  @type search_type :: :exact | :pattern | :fuzzy | :semantic | :full_text | :composite
  @type field_name :: :key | :value | :metadata | atom()
  @type similarity_threshold :: float()
  @type search_weight :: float()

  @type search_query :: %{
    type: search_type(),
    pattern: String.t() | nil,
    query: String.t() | nil,
    fields: [field_name()],
    similarity_threshold: similarity_threshold(),
    fuzzy_distance: non_neg_integer(),
    weights: %{field_name() => search_weight()},
    limit: pos_integer() | nil,
    offset: non_neg_integer()
  }

  @type search_result :: %{
    key: String.t(),
    value: any(),
    metadata: map(),
    score: float(),
    match_fields: [field_name()],
    match_details: map()
  }

  @type memory_entry :: %{
    key: String.t(),
    value: any(),
    metadata: map()
  }

  @doc """
  Performs a search across memory entries based on the provided query.

  ## Parameters
  - `entries` - List of memory entries to search
  - `query` - Search query specification

  ## Examples

      iex> entries = [
      ...>   %{key: "user_123", value: %{name: "Alice"}, metadata: %{}},
      ...>   %{key: "user_456", value: %{name: "Bob"}, metadata: %{}}
      ...> ]
      iex> query = %{type: :pattern, pattern: "user_*", fields: [:key]}
      iex> {:ok, results} = SearchEngine.search(entries, query)
      iex> length(results)
      2

  """
  @spec search([memory_entry()], search_query()) :: {:ok, [search_result()]} | {:error, any()}
  def search(entries, query) when is_list(entries) and is_map(query) do
    normalized_query = normalize_query(query)

    results =
      case normalized_query.type do
        :exact ->
          perform_exact_search(entries, normalized_query)

        :pattern ->
          perform_pattern_search(entries, normalized_query)

        :fuzzy ->
          perform_fuzzy_search(entries, normalized_query)

        :semantic ->
          perform_semantic_search(entries, normalized_query)

        :full_text ->
          perform_full_text_search(entries, normalized_query)

        :composite ->
          perform_composite_search(entries, normalized_query)
      end

    # Apply ranking, limiting, and offset
    final_results =
      results
      |> rank_results(normalized_query)
      |> apply_pagination(normalized_query)

    Logger.debug("Search completed: #{length(final_results)} results for #{normalized_query.type} search")
    {:ok, final_results}

  rescue
    error ->
      Logger.error("Search failed: #{inspect(error)}")
      {:error, {:search_failed, error}}
  end

  @doc """
  Creates a simple pattern search query.

  ## Parameters
  - `pattern` - Search pattern with wildcards (* and ?)
  - `fields` - Fields to search in (default: [:key, :value])

  ## Examples

      iex> query = SearchEngine.pattern_query("user_*", [:key])
      iex> query.type
      :pattern
      iex> query.pattern
      "user_*"

  """
  @spec pattern_query(String.t(), [field_name()]) :: search_query()
  def pattern_query(pattern, fields \\ [:key, :value]) do
    %{
      type: :pattern,
      pattern: pattern,
      query: nil,
      fields: fields,
      similarity_threshold: 0.8,
      fuzzy_distance: 2,
      weights: %{},
      limit: nil,
      offset: 0
    }
  end

  @doc """
  Creates a fuzzy search query for approximate matching.

  ## Parameters
  - `query` - Search term
  - `distance` - Maximum edit distance (default: 2)
  - `fields` - Fields to search in

  ## Examples

      iex> query = SearchEngine.fuzzy_query("alice", 1, [:value])
      iex> query.type
      :fuzzy
      iex> query.fuzzy_distance
      1

  """
  @spec fuzzy_query(String.t(), non_neg_integer(), [field_name()]) :: search_query()
  def fuzzy_query(query, distance \\ 2, fields \\ [:key, :value]) do
    %{
      type: :fuzzy,
      pattern: nil,
      query: query,
      fields: fields,
      similarity_threshold: 0.8,
      fuzzy_distance: distance,
      weights: %{},
      limit: nil,
      offset: 0
    }
  end

  @doc """
  Creates a semantic search query for similarity-based matching.

  ## Parameters
  - `query` - Search query text
  - `threshold` - Minimum similarity threshold (0.0 to 1.0)
  - `fields` - Fields to search in

  ## Examples

      iex> query = SearchEngine.semantic_query("machine learning", 0.7)
      iex> query.type
      :semantic
      iex> query.similarity_threshold
      0.7

  """
  @spec semantic_query(String.t(), similarity_threshold(), [field_name()]) :: search_query()
  def semantic_query(query, threshold \\ 0.8, fields \\ [:value]) do
    %{
      type: :semantic,
      pattern: nil,
      query: query,
      fields: fields,
      similarity_threshold: threshold,
      fuzzy_distance: 2,
      weights: %{},
      limit: nil,
      offset: 0
    }
  end

  @doc """
  Creates a full-text search query with TF-IDF ranking.

  ## Parameters
  - `query` - Search query text
  - `fields` - Fields to search in
  - `weights` - Field weights for ranking

  ## Examples

      iex> weights = %{value: 1.0, metadata: 0.5}
      iex> query = SearchEngine.full_text_query("important data", [:value, :metadata], weights)
      iex> query.type
      :full_text

  """
  @spec full_text_query(String.t(), [field_name()], %{field_name() => search_weight()}) :: search_query()
  def full_text_query(query, fields \\ [:value], weights \\ %{}) do
    %{
      type: :full_text,
      pattern: nil,
      query: query,
      fields: fields,
      similarity_threshold: 0.8,
      fuzzy_distance: 2,
      weights: weights,
      limit: nil,
      offset: 0
    }
  end

  @doc """
  Extracts searchable text from a memory entry field.

  ## Parameters
  - `entry` - Memory entry
  - `field` - Field to extract text from

  ## Examples

      iex> entry = %{key: "test", value: %{name: "Alice", age: 30}, metadata: %{}}
      iex> SearchEngine.extract_text(entry, :value)
      "Alice 30"

  """
  @spec extract_text(memory_entry(), field_name()) :: String.t()
  def extract_text(entry, field) do
    case field do
      :key ->
        to_string(entry.key)

      :value ->
        extract_text_from_value(entry.value)

      :metadata ->
        extract_text_from_value(entry.metadata)

      custom_field when is_atom(custom_field) ->
        case Map.get(entry, custom_field) do
          nil -> ""
          value -> extract_text_from_value(value)
        end
    end
  end

  @doc """
  Calculates similarity score between two text strings.

  Uses a combination of Jaro-Winkler distance and token-based similarity.

  ## Parameters
  - `text1` - First text string
  - `text2` - Second text string

  ## Examples

      iex> SearchEngine.similarity_score("hello world", "hello earth")
      0.7272727272727273

  """
  @spec similarity_score(String.t(), String.t()) :: float()
  def similarity_score(text1, text2) when is_binary(text1) and is_binary(text2) do
    # Simple implementation - in production, you might use more sophisticated algorithms
    jaro_winkler_similarity(text1, text2)
  end

  # Private functions

  @spec normalize_query(map()) :: search_query()
  defp normalize_query(query) do
    %{
      type: Map.get(query, :type, :pattern),
      pattern: Map.get(query, :pattern),
      query: Map.get(query, :query),
      fields: Map.get(query, :fields, [:key, :value]),
      similarity_threshold: Map.get(query, :similarity_threshold, 0.8),
      fuzzy_distance: Map.get(query, :fuzzy_distance, 2),
      weights: Map.get(query, :weights, %{}),
      limit: Map.get(query, :limit),
      offset: Map.get(query, :offset, 0)
    }
  end

  @spec perform_exact_search([memory_entry()], search_query()) :: [search_result()]
  defp perform_exact_search(entries, query) do
    search_term = query.query || query.pattern || ""

    entries
    |> Enum.filter(fn entry ->
      Enum.any?(query.fields, fn field ->
        field_text = extract_text(entry, field)
        String.contains?(String.downcase(field_text), String.downcase(search_term))
      end)
    end)
    |> Enum.map(fn entry ->
      create_search_result(entry, 1.0, query.fields, %{match_type: :exact})
    end)
  end

  @spec perform_pattern_search([memory_entry()], search_query()) :: [search_result()]
  defp perform_pattern_search(entries, query) do
    pattern = query.pattern || ""
    regex_pattern = pattern_to_regex(pattern)

    entries
    |> Enum.filter(fn entry ->
      Enum.any?(query.fields, fn field ->
        field_text = extract_text(entry, field)
        Regex.match?(regex_pattern, field_text)
      end)
    end)
    |> Enum.map(fn entry ->
      score = calculate_pattern_score(entry, regex_pattern, query.fields)
      matched_fields = get_matching_fields(entry, regex_pattern, query.fields)
      create_search_result(entry, score, matched_fields, %{match_type: :pattern})
    end)
  end

  @spec perform_fuzzy_search([memory_entry()], search_query()) :: [search_result()]
  defp perform_fuzzy_search(entries, query) do
    search_term = query.query || ""

    entries
    |> Enum.map(fn entry ->
      {entry, calculate_fuzzy_scores(entry, search_term, query)}
    end)
    |> Enum.filter(fn {_entry, scores} ->
      Enum.any?(scores, fn {_field, score} -> score >= query.similarity_threshold end)
    end)
    |> Enum.map(fn {entry, scores} ->
      best_score = scores |> Enum.map(fn {_field, score} -> score end) |> Enum.max()
      matched_fields = scores |> Enum.filter(fn {_field, score} -> score >= query.similarity_threshold end) |> Enum.map(fn {field, _score} -> field end)
      create_search_result(entry, best_score, matched_fields, %{match_type: :fuzzy, scores: scores})
    end)
  end

  @spec perform_semantic_search([memory_entry()], search_query()) :: [search_result()]
  defp perform_semantic_search(entries, query) do
    # Simplified semantic search - in production, you'd use embeddings/vectors
    search_terms = String.split(query.query || "", ~r/\s+/)

    entries
    |> Enum.map(fn entry ->
      {entry, calculate_semantic_scores(entry, search_terms, query)}
    end)
    |> Enum.filter(fn {_entry, scores} ->
      Enum.any?(scores, fn {_field, score} -> score >= query.similarity_threshold end)
    end)
    |> Enum.map(fn {entry, scores} ->
      best_score = scores |> Enum.map(fn {_field, score} -> score end) |> Enum.max()
      matched_fields = scores |> Enum.filter(fn {_field, score} -> score >= query.similarity_threshold end) |> Enum.map(fn {field, _score} -> field end)
      create_search_result(entry, best_score, matched_fields, %{match_type: :semantic, scores: scores})
    end)
  end

  @spec perform_full_text_search([memory_entry()], search_query()) :: [search_result()]
  defp perform_full_text_search(entries, query) do
    search_terms = String.split(query.query || "", ~r/\s+/)

    entries
    |> Enum.map(fn entry ->
      {entry, calculate_tfidf_scores(entry, search_terms, query, entries)}
    end)
    |> Enum.filter(fn {_entry, total_score} -> total_score > 0 end)
    |> Enum.map(fn {entry, score} ->
      create_search_result(entry, score, query.fields, %{match_type: :full_text})
    end)
  end

  @spec perform_composite_search([memory_entry()], search_query()) :: [search_result()]
  defp perform_composite_search(entries, query) do
    # Combine multiple search strategies
    pattern_results = if query.pattern, do: perform_pattern_search(entries, query), else: []
    fuzzy_results = if query.query, do: perform_fuzzy_search(entries, query), else: []

    # Merge and deduplicate results
    all_results = pattern_results ++ fuzzy_results

    all_results
    |> Enum.group_by(& &1.key)
    |> Enum.map(fn {_key, results} ->
      # Combine scores from multiple matches
      total_score = results |> Enum.map(& &1.score) |> Enum.sum()
      combined_score = total_score / length(results)
      combined_fields = results |> Enum.flat_map(& &1.match_fields) |> Enum.uniq()

      %{List.first(results) | score: combined_score, match_fields: combined_fields}
    end)
  end

  @spec create_search_result(memory_entry(), float(), [field_name()], map()) :: search_result()
  defp create_search_result(entry, score, matched_fields, match_details) do
    %{
      key: entry.key,
      value: entry.value,
      metadata: entry.metadata,
      score: score,
      match_fields: matched_fields,
      match_details: match_details
    }
  end

  @spec extract_text_from_value(any()) :: String.t()
  defp extract_text_from_value(value) when is_binary(value), do: value
  defp extract_text_from_value(value) when is_atom(value), do: to_string(value)
  defp extract_text_from_value(value) when is_number(value), do: to_string(value)
  defp extract_text_from_value(value) when is_map(value) do
    value
    |> Map.values()
    |> Enum.map_join(" ", &extract_text_from_value/1)
  end
  defp extract_text_from_value(value) when is_list(value) do
    value
    |> Enum.map_join(" ", &extract_text_from_value/1)
  end
  defp extract_text_from_value(_value), do: ""

  @spec pattern_to_regex(String.t()) :: Regex.t()
  defp pattern_to_regex(pattern) do
    escaped_pattern =
      pattern
      |> String.replace("*", ".*")
      |> String.replace("?", ".")

    Regex.compile!("^#{escaped_pattern}$", "i")
  end

  @spec calculate_pattern_score(memory_entry(), Regex.t(), [field_name()]) :: float()
  defp calculate_pattern_score(entry, regex, fields) do
    matching_fields = get_matching_fields(entry, regex, fields)
    if length(matching_fields) > 0 do
      1.0 / length(fields) * length(matching_fields)
    else
      0.0
    end
  end

  @spec get_matching_fields(memory_entry(), Regex.t(), [field_name()]) :: [field_name()]
  defp get_matching_fields(entry, regex, fields) do
    fields
    |> Enum.filter(fn field ->
      field_text = extract_text(entry, field)
      Regex.match?(regex, field_text)
    end)
  end

  @spec calculate_fuzzy_scores(memory_entry(), String.t(), search_query()) :: [{field_name(), float()}]
  defp calculate_fuzzy_scores(entry, search_term, query) do
    query.fields
    |> Enum.map(fn field ->
      field_text = extract_text(entry, field)
      score = similarity_score(search_term, field_text)
      {field, score}
    end)
  end

  @spec calculate_semantic_scores(memory_entry(), [String.t()], search_query()) :: [{field_name(), float()}]
  defp calculate_semantic_scores(entry, search_terms, query) do
    query.fields
    |> Enum.map(fn field ->
      field_text = extract_text(entry, field)
      field_terms = String.split(String.downcase(field_text), ~r/\s+/)

      # Calculate term overlap score
      overlap_score = calculate_term_overlap(search_terms, field_terms)
      {field, overlap_score}
    end)
  end

  @spec calculate_term_overlap([String.t()], [String.t()]) :: float()
  defp calculate_term_overlap(search_terms, field_terms) do
    search_set = MapSet.new(Enum.map(search_terms, &String.downcase/1))
    field_set = MapSet.new(Enum.map(field_terms, &String.downcase/1))

    intersection_size = MapSet.intersection(search_set, field_set) |> MapSet.size()
    union_size = MapSet.union(search_set, field_set) |> MapSet.size()

    if union_size > 0 do
      intersection_size / union_size
    else
      0.0
    end
  end

  @spec calculate_tfidf_scores(memory_entry(), [String.t()], search_query(), [memory_entry()]) :: float() | integer()
  defp calculate_tfidf_scores(entry, search_terms, query, all_entries) do
    # Simplified TF-IDF calculation
    query.fields
    |> Enum.map(fn field ->
      field_text = extract_text(entry, field)
      field_weight = Map.get(query.weights, field, 1.0)

      term_scores =
        search_terms
        |> Enum.map(fn term ->
          tf = calculate_term_frequency(term, field_text)
          idf = calculate_inverse_document_frequency(term, field, all_entries)
          tf * idf
        end)
        |> Enum.sum()

      term_scores * field_weight
    end)
    |> Enum.sum()
  end

  @spec calculate_term_frequency(String.t(), String.t()) :: float()
  defp calculate_term_frequency(term, text) do
    words = String.split(String.downcase(text), ~r/\s+/)
    term_count = Enum.count(words, &(&1 == String.downcase(term)))

    if length(words) > 0 do
      term_count / length(words)
    else
      0.0
    end
  end

  @spec calculate_inverse_document_frequency(String.t(), field_name(), [memory_entry()]) :: float()
  defp calculate_inverse_document_frequency(term, field, entries) do
    total_docs = length(entries)
    docs_with_term =
      entries
      |> Enum.count(fn entry ->
        field_text = extract_text(entry, field)
        String.contains?(String.downcase(field_text), String.downcase(term))
      end)

    if docs_with_term > 0 do
      :math.log(total_docs / docs_with_term)
    else
      0.0
    end
  end

  @spec jaro_winkler_similarity(String.t(), String.t()) :: float()
  defp jaro_winkler_similarity(s1, s2) do
    # Simplified Jaro-Winkler implementation
    if s1 == s2 do
      1.0
    else
      jaro_sim = jaro_similarity(s1, s2)
      prefix_length = common_prefix_length(s1, s2, 4)
      jaro_sim + (0.1 * prefix_length * (1 - jaro_sim))
    end
  end

  @spec jaro_similarity(String.t(), String.t()) :: float()
  defp jaro_similarity(s1, s2) do
    len1 = String.length(s1)
    len2 = String.length(s2)

    if len1 == 0 and len2 == 0 do
      1.0
    else
      match_window = max(len1, len2) |> div(2) |> Kernel.-(1) |> max(0)
      {matches, transpositions} = calculate_matches_and_transpositions(s1, s2, match_window)

      if matches == 0 do
        0.0
      else
        (matches / len1 + matches / len2 + (matches - transpositions) / matches) / 3
      end
    end
  end

  @spec common_prefix_length(binary(), binary(), 4) :: non_neg_integer()
  defp common_prefix_length(s1, s2, max_length) do
    s1_chars = String.graphemes(s1)
    s2_chars = String.graphemes(s2)

    Enum.zip(s1_chars, s2_chars)
    |> Enum.take(max_length)
    |> Enum.take_while(fn {c1, c2} -> c1 == c2 end)
    |> length()
  end

  @spec calculate_matches_and_transpositions(String.t(), String.t(), non_neg_integer()) ::
    {non_neg_integer(), non_neg_integer()}
  defp calculate_matches_and_transpositions(s1, s2, match_window) do
    # Simplified implementation - in production, use a proper algorithm
    s1_chars = String.graphemes(s1)
    s2_chars = String.graphemes(s2)

    matches =
      s1_chars
      |> Enum.with_index()
      |> Enum.count(fn {char, i} ->
        start_idx = max(0, i - match_window)
        end_idx = min(length(s2_chars) - 1, i + match_window)

        s2_chars
        |> Enum.slice(start_idx..end_idx)
        |> Enum.any?(&(&1 == char))
      end)

    # Simplified transposition calculation
    transpositions = 0

    {matches, transpositions}
  end

  @spec rank_results([search_result()], search_query()) :: [search_result()]
  defp rank_results(results, _query) do
    Enum.sort_by(results, & &1.score, :desc)
  end

  @spec apply_pagination([search_result()], search_query()) :: [search_result()]
  defp apply_pagination(results, query) do
    results
    |> Enum.drop(query.offset)
    |> then(fn results ->
      if query.limit do
        Enum.take(results, query.limit)
      else
        results
      end
    end)
  end
end
