# AI-Assisted Analysis Workflows

**Comprehensive analysis workflows for documentation, code, and architecture using AI capabilities in the Prismatic ecosystem.**

<!-- NAV_START -->
## Navigation

**Current Location**: [Home](../../README.md) > [Guides](../README.md) > [AI/LLM](README.md) > AI-Assisted Analysis Workflows

### Quick Links

- **📚 [Parent Directory](README.md)** - Return to AI/LLM guides
- **🏠 [Documentation Home](../../README.md)** - Main documentation index
- **🔍 [Search Documentation](../../reference/glossary.md)** - Find terms and concepts

### Related Documentation

- [AI-Assisted Development Integration](../automation/ai-assisted-development-integration.md) - Existing AI analysis framework
- [Prompt Engineering Templates](prompt-engineering-templates.md) - Analysis-specific prompt templates
- [LLM Integration Patterns](llm-integration-patterns.md) - Technical integration patterns
- [Technical Debt Analysis](technical-debt-analysis.md) - Specialized debt analysis workflows
- [Performance Optimization](performance-optimization.md) - AI-enhanced performance analysis
<!-- NAV_END -->

---

## Overview

AI-assisted analysis transforms how development teams understand, evaluate, and improve their codebases and documentation. This guide provides comprehensive workflows for leveraging AI to perform deep analysis across multiple dimensions of software development within the Prismatic ecosystem.

### Analysis Capabilities

**Code Analysis**:
- Quality assessment and improvement recommendations
- Security vulnerability identification
- Performance bottleneck detection
- Architecture pattern analysis
- Dependency relationship mapping

**Documentation Analysis**:
- Completeness and accuracy evaluation
- Consistency checking across documentation sets
- Gap identification and prioritization
- Cross-reference validation
- User experience assessment

**System Analysis**:
- Architecture decision validation
- Technical debt quantification
- Scalability assessment
- Integration pattern evaluation
- Compliance checking

### Integration with Prismatic

Builds upon the existing [AI-Assisted Development Integration Framework](../automation/ai-assisted-development-integration.md) which provides:
- ADR extraction and metadata system
- Code example extraction framework
- Traceability marker system
- AI assistant integration tools
- Validation pipeline integration

---

## Analysis Workflow Categories

### 🔍 Code Quality Analysis
*Comprehensive code quality assessment and improvement recommendations*

### 🛡️ Security Analysis
*Security vulnerability detection and mitigation strategies*

### ⚡ Performance Analysis
*Performance bottleneck identification and optimization guidance*

### 🏗️ Architecture Analysis
*System architecture evaluation and design pattern assessment*

### 📚 Documentation Analysis
*Documentation quality, completeness, and consistency evaluation*

### 🔗 Dependency Analysis
*Dependency relationship mapping and upgrade planning*

### 📊 Technical Debt Analysis
*Technical debt identification, quantification, and prioritization*

---

## Code Quality Analysis Framework

### Multi-Dimensional Quality Assessment

**Use Case**: Comprehensive evaluation of code quality across multiple dimensions

```elixir
defmodule Prismatic.Analysis.CodeQuality do
  @moduledoc """
  Comprehensive code quality analysis using AI-powered evaluation.
  """
  
  alias Prismatic.LLM.Backend
  alias Prismatic.AI.TemplateClient
  
  @quality_dimensions [
    :readability,
    :maintainability,
    :testability,
    :performance,
    :security,
    :documentation,
    :patterns,
    :conventions
  ]
  
  @doc """
  Performs comprehensive code quality analysis.
  
  ## Examples
  
      iex> CodeQuality.analyze_file("lib/prismatic/llm/backend.ex")
      {:ok, %{
        overall_score: 8.5,
        dimensions: %{readability: 9.0, maintainability: 8.0},
        issues: [...],
        recommendations: [...]
      }}
  """
  @spec analyze_file(String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def analyze_file(file_path, opts \\ []) do
    dimensions = Keyword.get(opts, :dimensions, @quality_dimensions)
    
    with {:ok, file_content} <- File.read(file_path),
         {:ok, analysis_results} <- perform_quality_analysis(
           file_content, file_path, dimensions, opts
         ) do
      {:ok, analysis_results}
    end
  end
  
  defp perform_quality_analysis(code, file_path, dimensions, opts) do
    provider = Keyword.get(opts, :provider, :openai)
    
    analysis_prompt = """
    Perform comprehensive code quality analysis for this Elixir file:
    
    **File**: #{file_path}
    **Analysis Dimensions**: #{Enum.join(dimensions, ", ")}
    
    ```elixir
    #{String.slice(code, 0, 3000)}
    ```
    
    **Analysis Framework**:
    
    Rate each dimension (1-10) and provide specific issues and recommendations:
    
    1. **Readability**: Variable naming, code structure, comments
    2. **Maintainability**: Function complexity, coupling, error handling
    3. **Testability**: Function purity, dependency injection, mockability
    4. **Performance**: Algorithmic efficiency, memory usage, optimization opportunities
    5. **Security**: Input validation, authentication, data protection
    6. **Documentation**: @moduledoc, @doc, @spec completeness and quality
    7. **Patterns**: OTP patterns, functional programming, Elixir idioms
    8. **Conventions**: Style guide compliance, naming consistency
    
    **Output Format** (JSON):
    {
      "overall_score": 8.5,
      "dimensions": {
        "readability": {"score": 9.0, "issues": [...], "recommendations": [...]},
        "maintainability": {"score": 8.0, "issues": [...], "recommendations": [...]}
      },
      "priority_issues": [
        {"severity": "high", "dimension": "security", "description": "...", "fix": "..."}
      ],
      "quick_wins": [
        {"effort": "low", "impact": "medium", "description": "...", "example": "..."}
      ]
    }
    """
    
    with {:ok, config} <- create_analysis_config(provider),
         {:ok, response} <- Backend.generate_response(
           config,
           analysis_prompt,
           %{temperature: 0.3, max_tokens: 2500}
         ),
         {:ok, parsed_result} <- parse_analysis_response(response) do
      {:ok, parsed_result}
    end
  end
  
  defp create_analysis_config(provider) do
    Backend.create_config(provider, %{
      api_key: get_api_key(provider),
      model: get_analysis_model(provider),
      timeout: 45_000
    })
  end
  
  defp parse_analysis_response(response) do
    case Jason.decode(response) do
      {:ok, parsed} -> {:ok, parsed}
      {:error, _} -> {:ok, %{raw_response: response, overall_score: 5.0}}
    end
  end
  
  defp get_api_key(:openai), do: System.get_env("OPENAI_API_KEY")
  defp get_api_key(:anthropic), do: System.get_env("ANTHROPIC_API_KEY")
  
  defp get_analysis_model(:openai), do: "gpt-4"
  defp get_analysis_model(:anthropic), do: "claude-3-sonnet-20240229"
end
```

---

## Security Analysis Framework

### Vulnerability Detection and Risk Assessment

**Use Case**: AI-powered security analysis with threat identification

```elixir
defmodule Prismatic.Analysis.Security do
  @moduledoc """
  AI-powered security analysis for vulnerability detection and risk assessment.
  """
  
  alias Prismatic.LLM.Backend
  
  @security_categories [
    :authentication,
    :authorization,
    :input_validation,
    :data_protection,
    :session_management,
    :error_handling,
    :dependencies
  ]
  
  @doc """
  Performs comprehensive security analysis.
  
  ## Examples
  
      iex> Security.analyze_security("lib/prismatic_web/controllers/auth_controller.ex")
      {:ok, %{
        risk_score: 7.5,
        vulnerabilities: [...],
        recommendations: [...]
      }}
  """
  @spec analyze_security(String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def analyze_security(file_path, opts \\ []) do
    categories = Keyword.get(opts, :categories, @security_categories)
    
    with {:ok, file_content} <- File.read(file_path),
         {:ok, security_analysis} <- perform_security_analysis(
           file_content, file_path, categories, opts
         ) do
      {:ok, security_analysis}
    end
  end
  
  defp perform_security_analysis(code, file_path, categories, opts) do
    provider = Keyword.get(opts, :provider, :anthropic)
    
    security_prompt = """
    Perform comprehensive security analysis for this Elixir file:
    
    **File**: #{file_path}
    **Security Categories**: #{Enum.join(categories, ", ")}
    
    ```elixir
    #{String.slice(code, 0, 3000)}
    ```
    
    **Security Analysis Framework**:
    
    Identify vulnerabilities and assess risk for:
    
    1. **Authentication**: Bypass vulnerabilities, weak mechanisms, password handling
    2. **Authorization**: Privilege escalation, access control bypasses, RBAC issues
    3. **Input Validation**: SQL injection, XSS, command injection, path traversal
    4. **Data Protection**: Sensitive data exposure, encryption issues, storage security
    5. **Session Management**: Session fixation, hijacking, insecure storage
    6. **Error Handling**: Information disclosure, stack trace exposure
    7. **Dependencies**: Vulnerable dependencies, supply chain risks
    
    **Output Format** (JSON):
    {
      "findings": [
        {
          "category": "input_validation",
          "severity": "high",
          "title": "Potential SQL Injection",
          "description": "User input directly used in query",
          "location": "line 45",
          "impact": "Data breach, unauthorized access",
          "remediation": "Use parameterized queries",
          "example_fix": "from(u in User, where: u.id == ^id)"
        }
      ],
      "summary": {
        "total_findings": 5,
        "critical": 1,
        "high": 2,
        "medium": 1,
        "low": 1,
        "overall_risk": "high"
      }
    }
    """
    
    with {:ok, config} <- create_security_config(provider),
         {:ok, response} <- Backend.generate_response(
           config,
           security_prompt,
           %{temperature: 0.2, max_tokens: 3000}
         ),
         {:ok, parsed_result} <- parse_security_response(response) do
      {:ok, parsed_result}
    end
  end
  
  defp create_security_config(provider) do
    Backend.create_config(provider, %{
      api_key: get_api_key(provider),
      model: get_security_model(provider),
      timeout: 60_000
    })
  end
  
  defp parse_security_response(response) do
    case Jason.decode(response) do
      {:ok, parsed} -> {:ok, parsed}
      {:error, _} -> {:ok, %{"findings" => [], "summary" => %{"overall_risk" => "unknown"}}}
    end
  end
  
  defp get_api_key(:openai), do: System.get_env("OPENAI_API_KEY")
  defp get_api_key(:anthropic), do: System.get_env("ANTHROPIC_API_KEY")
  
  defp get_security_model(:openai), do: "gpt-4"
  defp get_security_model(:anthropic), do: "claude-3-opus-20240229"
end
```

---

## Performance Analysis Framework

### Bottleneck Detection and Optimization

**Use Case**: AI-powered performance analysis with optimization recommendations

```elixir
defmodule Prismatic.Analysis.Performance do
  @moduledoc """
  AI-assisted performance analysis for bottleneck detection and optimization.
  """
  
  alias Prismatic.LLM.Backend
  
  @performance_categories [
    :algorithmic_complexity,
    :memory_usage,
    :database_queries,
    :concurrent_processing,
    :io_operations,
    :caching_opportunities
  ]
  
  @doc """
  Analyzes performance characteristics of code.
  
  ## Examples
  
      iex> Performance.analyze_performance("lib/prismatic/heavy_computation.ex")
      {:ok, %{
        performance_score: 6.5,
        bottlenecks: [...],
        optimizations: [...]
      }}
  """
  @spec analyze_performance(String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def analyze_performance(file_path, opts \\ []) do
    categories = Keyword.get(opts, :categories, @performance_categories)
    
    with {:ok, file_content} <- File.read(file_path),
         {:ok, performance_analysis} <- perform_performance_analysis(
           file_content, file_path, categories, opts
         ) do
      {:ok, performance_analysis}
    end
  end
  
  defp perform_performance_analysis(code, file_path, categories, opts) do
    provider = Keyword.get(opts, :provider, :openai)
    
    performance_prompt = """
    Perform comprehensive performance analysis for this Elixir code:
    
    **File**: #{file_path}
    **Analysis Categories**: #{Enum.join(categories, ", ")}
    
    ```elixir
    #{String.slice(code, 0, 3000)}
    ```
    
    **Performance Analysis Framework**:
    
    1. **Algorithmic Complexity**: Time/space complexity, algorithm efficiency
    2. **Memory Usage**: Memory allocation patterns, GC impact, memory leaks
    3. **Database Queries**: N+1 problems, query efficiency, indexing
    4. **Concurrent Processing**: Parallelization opportunities, synchronization bottlenecks
    5. **I/O Operations**: File/network I/O efficiency, connection pooling
    6. **Caching Opportunities**: Result caching, query caching, in-memory caching
    
    **Output Format** (JSON):
    {
      "performance_score": 7.5,
      "bottlenecks": [
        {
          "category": "algorithmic_complexity",
          "severity": "high",
          "location": "line 45-60",
          "description": "Nested loops causing O(n²) complexity",
          "impact": "High CPU usage with large datasets",
          "optimization": "Use hash map lookup instead of nested iteration",
          "estimated_improvement": "80% faster with 1000+ items"
        }
      ],
      "optimizations": [
        {
          "type": "caching",
          "priority": "high",
          "description": "Cache expensive computation results",
          "implementation": "Add ETS/GenServer cache",
          "expected_benefit": "50-90% performance improvement"
        }
      ]
    }
    """
    
    with {:ok, config} <- create_performance_config(provider),
         {:ok, response} <- Backend.generate_response(
           config,
           performance_prompt,
           %{temperature: 0.2, max_tokens: 2500}
         ),
         {:ok, parsed_result} <- parse_performance_response(response) do
      {:ok, parsed_result}
    end
  end
  
  defp create_performance_config(provider) do
    Backend.create_config(provider, %{
      api_key: get_api_key(provider),
      model: get_performance_model(provider),
      timeout: 45_000
    })
  end
  
  defp parse_performance_response(response) do
    case Jason.decode(response) do
      {:ok, parsed} -> {:ok, parsed}
      {:error, _} -> {:ok, %{"performance_score" => 5.0, "bottlenecks" => [], "optimizations" => []}}
    end
  end
  
  defp get_api_key(:openai), do: System.get_env("OPENAI_API_KEY")
  defp get_api_key(:anthropic), do: System.get_env("ANTHROPIC_API_KEY")
  
  defp get_performance_model(:openai), do: "gpt-4"
  defp get_performance_model(:anthropic), do: "claude-3-sonnet-20240229"
end
```

---

## Documentation Analysis Framework

### Quality and Completeness Assessment

**Use Case**: Comprehensive evaluation of documentation quality and gaps

```elixir
defmodule Prismatic.Analysis.Documentation do
  @moduledoc """
  AI-powered documentation analysis for quality assessment and improvement.
  """
  
  alias Prismatic.LLM.Backend
  alias Prismatic.Documentation.{ADRExtractor, CodeExampleExtractor}
  
  @doc_categories [
    :completeness,
    :accuracy,
    :clarity,
    :consistency,
    :usability,
    :examples
  ]
  
  @doc """
  Analyzes documentation quality across multiple dimensions.
  
  ## Examples
  
      iex> Documentation.analyze_documentation("docs/guides/ai-llm")
      {:ok, %{
        quality_score: 8.2,
        gaps: [...],
        improvements: [...]
      }}
  """
  @spec analyze_documentation(String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def analyze_documentation(docs_path, opts \\ []) do
    categories = Keyword.get(opts, :categories, @doc_categories)
    
    with {:ok, doc_files} <- gather_documentation_files(docs_path),
         {:ok, analysis_results} <- perform_documentation_analysis(
           doc_files, categories, opts
         ) do
      {:ok, analysis_results}
    end
  end
  
  defp gather_documentation_files(docs_path) do
    doc_patterns = ["**/*.md", "**/*.rst"]
    
    files = 
      doc_patterns
      |> Enum.flat_map(&Path.wildcard(Path.join(docs_path, &1)))
      |> Enum.map(fn file_path ->
        case File.read(file_path) do
          {:ok, content} -> %{path: file_path, content: content}
          {:error, _} -> nil
        end
      end)
      |> Enum.filter(& &1)
    
    {:ok, files}
  end
  
  defp perform_documentation_analysis(doc_files, categories, opts) do
    provider = Keyword.get(opts, :provider, :anthropic)
    
    # Analyze a sample of files to avoid token limits
    sample_files = Enum.take(doc_files, 3)
    
    batch_content = 
      sample_files
      |> Enum.map(fn doc ->
        "**File**: #{doc.path}\n\n#{String.slice(doc.content, 0, 1500)}\n\n---\n\n"
      end)
      |> Enum.join("")
    
    doc_analysis_prompt = """
    Analyze the quality of this documentation:
    
    **Categories to Analyze**: #{Enum.join(categories, ", ")}
    
    #{batch_content}
    
    **Documentation Quality Framework**:
    
    1. **Completeness**: Coverage of necessary topics, missing sections
    2. **Accuracy**: Technical accuracy, code example correctness
    3. **Clarity**: Writing clarity, logical organization, appropriate language
    4. **Consistency**: Style consistency, terminology, format
    5. **Usability**: Navigation ease, quick reference availability
    6. **Examples**: Example quality, completeness, working examples
    
    **Output Format** (JSON):
    {
      "overall_score": 8.2,
      "categories": {
        "completeness": {"score": 8.5, "issues": [...], "improvements": [...]},
        "accuracy": {"score": 9.0, "issues": [...], "improvements": []}
      },
      "critical_issues": [
        {"type": "accuracy", "file": "file1.md", "issue": "Outdated API reference"}
      ],
      "recommendations": [
        {"priority": "high", "description": "Update code examples", "files": [...]}
      ]
    }
    """
    
    with {:ok, config} <- create_documentation_config(provider),
         {:ok, response} <- Backend.generate_response(
           config,
           doc_analysis_prompt,
           %{temperature: 0.3, max_tokens: 2000}
         ),
         {:ok, parsed_result} <- parse_documentation_response(response) do
      {:ok, parsed_result}
    end
  end
  
  defp create_documentation_config(provider) do
    Backend.create_config(provider, %{
      api_key: get_api_key(provider),
      model: get_documentation_model(provider),
      timeout: 45_000
    })
  end
  
  defp parse_documentation_response(response) do
    case Jason.decode(response) do
      {:ok, parsed} -> {:ok, parsed}
      {:error, _} -> {:ok, %{"overall_score" => 5.0, "categories" => %{}}}
    end
  end
  
  defp get_api_key(:openai), do: System.get_env("OPENAI_API_KEY")
  defp get_api_key(:anthropic), do: System.get_env("ANTHROPIC_API_KEY")
  
  defp get_documentation_model(:openai), do: "gpt-4"
  defp get_documentation_model(:anthropic), do: "claude-3-sonnet-20240229"
end
```

---

## Analysis Orchestration

### Comprehensive Analysis Pipeline

**Use Case**: Run multiple analysis types in a coordinated workflow

```elixir
defmodule Prismatic.Analysis.Pipeline do
  @moduledoc """
  Orchestrates multiple analysis workflows for comprehensive evaluation.
  """
  
  alias Prismatic.Analysis.{CodeQuality, Security, Performance, Documentation}
  
  @doc """
  Executes comprehensive analysis across all dimensions.
  
  ## Examples
  
      iex> Pipeline.analyze_comprehensive("lib/prismatic/llm")
      {:ok, %{
        code_quality: %{...},
        security: %{...},
        performance: %{...},
        summary: %{...}
      }}
  """
  @spec analyze_comprehensive(String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def analyze_comprehensive(target_path, opts \\ []) do
    analysis_types = Keyword.get(opts, :types, [:code_quality, :security, :performance])
    
    results = 
      analysis_types
      |> Task.async_stream(
        fn type -> {type, execute_analysis_type(type, target_path, opts)} end,
        max_concurrency: 3,
        timeout: 120_000
      )
      |> Enum.reduce(%{}, fn
        {:ok, {type, {:ok, result}}} -> &Map.put(&1, type, result)
        {:ok, {type, {:error, reason}}} -> &Map.put(&1, type, {:error, reason})
        _ -> & &1
      end)
    
    summary = generate_analysis_summary(results)
    
    {:ok, Map.put(results, :summary, summary)}
  end
  
  defp execute_analysis_type(:code_quality, path, opts) do
    if File.dir?(path) do
      analyze_directory_quality(path, opts)
    else
      CodeQuality.analyze_file(path, opts)
    end
  end
  
  defp execute_analysis_type(:security, path, opts) do
    if File.dir?(path) do
      analyze_directory_security(path, opts)
    else
      Security.analyze_security(path, opts)
    end
  end
  
  defp execute_analysis_type(:performance, path, opts) do
    if File.dir?(path) do
      analyze_directory_performance(path, opts)
    else
      Performance.analyze_performance(path, opts)
    end
  end
  
  defp execute_analysis_type(:documentation, path, opts) do
    Documentation.analyze_documentation(path, opts)
  end
  
  defp analyze_directory_quality(directory, opts) do
    files = Path.wildcard(Path.join(directory, "**/*.ex"))
    
    results = 
      files
      |> Enum.take(10)  # Limit for demo
      |> Enum.map(fn file ->
        case CodeQuality.analyze_file(file, opts) do
          {:ok, result} -> {file, result}
          {:error, _} -> {file, nil}
        end
      end)
      |> Enum.filter(fn {_file, result} -> result != nil end)
    
    if length(results) > 0 do
      average_score = 
        results
        |> Enum.map(fn {_file, result} -> result.overall_score end)
        |> Enum.sum()
        |> Kernel./(length(results))
      
      {:ok, %{
        directory: directory,
        files_analyzed: length(results),
        average_quality_score: average_score,
        file_results: results
      }}
    else
      {:error, :no_files_analyzed}
    end
  end
  
  defp analyze_directory_security(directory, opts) do
    files = Path.wildcard(Path.join(directory, "**/*.ex"))
    
    results = 
      files
      |> Enum.take(5)  # Limit for security analysis
      |> Enum.map(fn file ->
        case Security.analyze_security(file, opts) do
          {:ok, result} -> {file, result}
          {:error, _} -> {file, nil}
        end
      end)
      |> Enum.filter(fn {_file, result} -> result != nil end)
    
    if length(results) > 0 do
      total_vulnerabilities = 
        results
        |> Enum.flat_map(fn {_file, result} -> result.vulnerabilities end)
        |> length()
      
      {:ok, %{
        directory: directory,
        files_analyzed: length(results),
        total_vulnerabilities: total_vulnerabilities,
        file_results: results
      }}
    else
      {:error, :no_files_analyzed}
    end
  end
  
  defp analyze_directory_performance(directory, opts) do
    files = Path.wildcard(Path.join(directory, "**/*.ex"))
    
    results = 
      files
      |> Enum.take(5)  # Limit for performance analysis
      |> Enum.map(fn file ->
        case Performance.analyze_performance(file, opts) do
          {:ok, result} -> {file, result}
          {:error, _} -> {file, nil}
        end
      end)
      |> Enum.filter(fn {_file, result} -> result != nil end)
    
    if length(results) > 0 do
      average_score = 
        results
        |> Enum.map(fn {_file, result} -> result.performance_score end)
        |> Enum.sum()
        |> Kernel./(length(results))
      
      {:ok, %{
        directory: directory,
        files_analyzed: length(results),
        average_performance_score: average_score,
        file_results: results
      }}
    else
      {:error, :no_files_analyzed}
    end
  end
  
  defp generate_analysis_summary(results) do
    %{
      analyzed_at: DateTime.utc_now(),
      analysis_types: Map.keys(results),
      overall_health: determine_overall_health(results),
      key_findings: extract_key_findings(results),
      priority_actions: identify_priority_actions(results)
    }
  end
  
  defp determine_overall_health(results) do
    # Simple health determination based on available results
    cond do
      Map.has_key?(results, :security) and 
      match?(%{total_vulnerabilities: count} when count > 5, results.security) ->
        "needs_attention"
      
      Map.has_key?(results, :code_quality) and 
      match?(%{average_quality_score: score} when score < 6.0, results.code_quality) ->
        "fair"
      
      true ->
        "good"
    end
  end
  
  defp extract_key_findings(results) do
    # Extract top findings from each analysis type
    Enum.reduce(results, [], fn {type, result}, acc ->
      case {type, result} do
        {:code_quality, %{average_quality_score: score}} when score < 7.0 ->
          ["Code quality below target (#{Float.round(score, 1)}/10)" | acc]
        
        {:security, %{total_vulnerabilities: count}} when count > 0 ->
          ["#{count} security vulnerabilities found" | acc]
        
        {:performance, %{average_performance_score: score}} when score < 7.0 ->
          ["Performance issues identified (#{Float.round(score, 1)}/10)" | acc]
        
        _ ->
          acc
      end
    end)
  end
  
  defp identify_priority_actions(results) do
    actions = []
    
    actions = if Map.has_key?(results, :security) and 
                 match?(%{total_vulnerabilities: count} when count > 0, results.security) do
      ["Address security vulnerabilities" | actions]
    else
      actions
    end
    
    actions = if Map.has_key?(results, :code_quality) and 
                 match?(%{average_quality_score: score} when score < 6.0, results.code_quality) do
      ["Improve code quality" | actions]
    else
      actions
    end
    
    if length(actions) == 0 do
      ["Continue monitoring and maintaining current quality levels"]
    else
      actions
    end
  end
end
```

---

## Best Practices

### Analysis Workflow Guidelines

1. **Start with Security**: Always prioritize security analysis for critical systems
2. **Iterative Improvement**: Use analysis results to guide incremental improvements
3. **Context Awareness**: Include project-specific context in analysis prompts
4. **Validation**: Always validate AI analysis results with human review
5. **Continuous Monitoring**: Integrate analysis into CI/CD pipelines

### Integration Strategies

1. **Automated Scheduling**: Run analysis on schedule or code changes
2. **Threshold Alerts**: Set quality/security thresholds for notifications
3. **Team Dashboards**: Create dashboards showing analysis trends
4. **Action Items**: Convert analysis results into actionable tasks
5. **Knowledge Sharing**: Share analysis insights across teams

### Performance Optimization

1. **Batching**: Analyze multiple files together when possible
2. **Sampling**: Use representative samples for large codebases
3. **Caching**: Cache analysis results for unchanged files
4. **Parallel Processing**: Run different analysis types in parallel
5. **Result Storage**: Store analysis history for trend analysis

---

## Related Documentation

- [AI-Assisted Development Integration](../automation/ai-assisted-development-integration.md) - Existing AI analysis framework
- [Prompt Engineering Templates](prompt-engineering-templates.md) - Analysis-specific prompts
- [LLM Integration Patterns](llm-integration-patterns.md) - Technical integration patterns
- [Best Practices for AI Development](best-practices.md) - Quality guidelines
- [Technical Debt Analysis](technical-debt-analysis.md) - Specialized debt analysis
- [Performance Optimization](performance-optimization.md) - Performance improvement strategies

---

**🔍 Analysis Tip**: Start with automated analysis to identify areas of concern, then use human expertise to validate findings and prioritize improvements. AI analysis is most effective when combined with domain knowledge and contextual understanding.