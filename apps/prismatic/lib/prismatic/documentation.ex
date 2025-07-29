defmodule Prismatic.Documentation do
  @moduledoc """
  Documentation module for the Prismatic application.

  This module provides functionality for AI-assisted development integration,
  including ADR extraction, code example parsing, traceability markers,
  and structured data generation for AI consumption.
  """

  alias Prismatic.Documentation.{
    ADRExtractor,
    CodeExampleExtractor,
    TraceabilityMarker,
    AIAssistantIntegration
  }

  @doc """
  Extract and process all ADRs in the documentation directory.

  Returns structured metadata for all Architecture Decision Records.
  """
  def extract_all_adrs(docs_path \\ "docs") do
    ADRExtractor.extract_all_adrs(docs_path)
  end

  @doc """
  Extract code examples from documentation files.

  Returns categorized code examples with metadata.
  """
  def extract_code_examples(docs_path \\ "docs") do
    CodeExampleExtractor.extract_all_examples(docs_path)
  end

  @doc """
  Generate traceability markers between documentation and code.

  Creates bidirectional references between docs and implementation files.
  """
  def generate_traceability_markers(docs_path \\ "docs", code_path \\ "apps") do
    TraceabilityMarker.generate_markers(docs_path, code_path)
  end

  @doc """
  Generate AI-friendly structured data from documentation.

  Creates optimized data formats for AI assistant consumption.
  """
  def generate_ai_data(docs_path \\ "docs") do
    AIAssistantIntegration.generate_structured_data(docs_path)
  end

  @doc """
  Comprehensive documentation analysis and enhancement.

  Runs all AI-assisted development integration tools and returns
  a comprehensive analysis report.
  """
  def comprehensive_analysis(docs_path \\ "docs", code_path \\ "apps") do
    %{
      adrs: extract_all_adrs(docs_path),
      code_examples: extract_code_examples(docs_path),
      traceability: generate_traceability_markers(docs_path, code_path),
      ai_data: generate_ai_data(docs_path),
      analysis_timestamp: DateTime.utc_now(),
      analysis_version: "1.0.0"
    }
  end
end
