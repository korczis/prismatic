# LLM Integration Patterns

**Technical patterns for integrating Large Language Models into development workflows using Prismatic's LLM backend system.**

<!-- NAV_START -->
## Navigation

**Current Location**: [Home](../../README.md) > [Guides](../README.md) > [AI/LLM](README.md) > LLM Integration Patterns

### Quick Links

- **📚 [Parent Directory](README.md)** - Return to AI/LLM guides
- **🏠 [Documentation Home](../../README.md)** - Main documentation index
- **🔍 [Search Documentation](../../reference/glossary.md)** - Find terms and concepts

### Related Documentation

- [Prompt Engineering Templates](prompt-engineering-templates.md) - Prompt templates and best practices
- [LLM Backend Implementation](../../../lib/prismatic/llm/backend.ex) - Core LLM system reference
- [Automated Code Generation](automated-code-generation.md) - End-to-end automation workflows
- [Best Practices for AI Development](best-practices.md) - Core principles and guidelines
- [Development Workflow Integration](development-workflow-integration.md) - Daily workflow enhancement
<!-- NAV_END -->

---

## Overview

This guide provides comprehensive patterns for integrating LLMs into development workflows using Prismatic's robust LLM backend system. The patterns cover everything from basic single-request interactions to complex multi-step workflows with error handling, caching, and monitoring.

### Prismatic LLM Backend Architecture

Prismatic's LLM backend provides a unified interface supporting multiple providers:

- **OpenAI** - GPT-4, GPT-3.5-turbo with function calling and vision
- **Anthropic** - Claude-3 Opus, Sonnet, Haiku with advanced reasoning
- **Test Backend** - Development and testing environment
- **Local Models** - Future support for on-premises deployments

**Core Features**:
- Circuit breaker protection
- Automatic retry logic
- Comprehensive metrics collection
- Health monitoring
- Multi-provider abstraction

---

## Integration Pattern Categories

### 🔄 [Basic Integration Patterns](#basic-integration-patterns)
*Simple, direct LLM interactions for common tasks*

### 🏗️ [Workflow Integration Patterns](#workflow-integration-patterns)
*Multi-step processes combining LLM calls with other operations*

### 🛡️ [Reliability Patterns](#reliability-patterns)
*Error handling, retry logic, and fault tolerance*

### ⚡ [Performance Patterns](#performance-patterns)
*Optimization techniques for speed and cost efficiency*

### 📊 [Monitoring Patterns](#monitoring-patterns)
*Observability, metrics, and health monitoring*

### 🔌 [Advanced Integration Patterns](#advanced-integration-patterns)
*Complex scenarios with custom behaviors and extensions*

---

## Basic Integration Patterns

### Pattern: Simple Request-Response

**Use Case**: Direct LLM interaction for single-step tasks

```elixir
defmodule Prismatic.AI.SimpleClient do
  @moduledoc """
  Simple LLM client for basic request-response patterns.
  """
  
  alias Prismatic.LLM.Backend
  
  @doc """
  Executes a simple LLM request with basic error handling.
  
  ## Examples
  
      iex> SimpleClient.ask("Explain recursion in Elixir")
      {:ok, "Recursion in Elixir..."}
      
      iex> SimpleClient.ask("Invalid request", provider: :anthropic)
      {:error, {:api_error, "Invalid request format"}}
  """
  @spec ask(String.t(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def ask(prompt, opts \\ []) do
    provider = Keyword.get(opts, :provider, :openai)
    temperature = Keyword.get(opts, :temperature, 0.3)
    max_tokens = Keyword.get(opts, :max_tokens, 1000)
    
    with {:ok, config} <- create_config(provider),
         {:ok, response} <- Backend.generate_response(
           config,
           prompt,
           %{temperature: temperature, max_tokens: max_tokens}
         ) do
      {:ok, response}
    end
  end
  
  defp create_config(:openai) do
    Backend.create_config(:openai, %{
      api_key: System.get_env("OPENAI_API_KEY"),
      model: "gpt-4",
      timeout: 30_000
    })
  end
  
  defp create_config(:anthropic) do
    Backend.create_config(:anthropic, %{
      api_key: System.get_env("ANTHROPIC_API_KEY"),
      model: "claude-3-sonnet-20240229",
      timeout: 30_000
    })
  end
end
```

### Pattern: Context-Aware Requests

**Use Case**: LLM requests that include project-specific context

```elixir
defmodule Prismatic.AI.ContextualClient do
  @moduledoc """
  LLM client that automatically includes project context.
  """
  
  alias Prismatic.LLM.Backend
  
  @default_context """
  You are an expert Elixir developer working on the Prismatic project.
  
  Project Context:
  - Umbrella application with apps/prismatic and apps/prismatic_web
  - Uses Phoenix framework for web interface
  - Implements LLM backend with OpenAI and Anthropic support
  - Follows OTP principles and functional programming
  - Uses comprehensive error handling with {:ok, result} | {:error, reason}
  - Includes telemetry for monitoring and observability
  
  Code Standards:
  - Follow Elixir community conventions
  - Include comprehensive @spec and @doc annotations
  - Use pattern matching over conditional logic
  - Include doctests for examples
  - Add proper error handling and logging
  """
  
  @doc """
  Executes an LLM request with automatic project context injection.
  
  ## Examples
  
      iex> ContextualClient.ask_with_context("Create a GenServer for metrics collection")
      {:ok, "defmodule Prismatic.Analytics.MetricsCollector do..."}
  """
  @spec ask_with_context(String.t(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def ask_with_context(prompt, opts \\ []) do
    provider = Keyword.get(opts, :provider, :openai)
    additional_context = Keyword.get(opts, :context, "")
    
    full_context = build_full_context(additional_context)
    
    with {:ok, config} <- create_config(provider) do
      Backend.generate_response(
        config,
        prompt,
        %{
          system_message: full_context,
          temperature: 0.3,
          max_tokens: 2000
        }
      )
    end
  end
  
  @doc """
  Adds file context to the request for more accurate responses.
  
  ## Examples
  
      iex> ContextualClient.ask_with_file_context(
      ...>   "Improve this module",
      ...>   "lib/prismatic/llm/backend.ex"
      ...> )
      {:ok, "Based on the LLM backend module, here are improvements..."}
  """
  @spec ask_with_file_context(String.t(), String.t(), keyword()) :: 
    {:ok, String.t()} | {:error, term()}
  def ask_with_file_context(prompt, file_path, opts \\ []) do
    case File.read(file_path) do
      {:ok, file_content} ->
        enhanced_prompt = """
        #{prompt}
        
        **File Context** (#{file_path}):
        ```elixir
        #{file_content}
        ```
        
        Please provide suggestions specific to this file and maintain consistency
        with the existing code patterns and style.
        """
        
        ask_with_context(enhanced_prompt, opts)
        
      {:error, reason} ->
        {:error, {:file_read_error, reason}}
    end
  end
  
  defp build_full_context(additional_context) do
    case additional_context do
      "" -> @default_context
      extra -> @default_context <> "\n\nAdditional Context:\n" <> extra
    end
  end
  
  defp create_config(provider) do
    config_map = case provider do
      :openai -> %{
        api_key: System.get_env("OPENAI_API_KEY"),
        model: "gpt-4",
        timeout: 30_000
      }
      :anthropic -> %{
        api_key: System.get_env("ANTHROPIC_API_KEY"),
        model: "claude-3-sonnet-20240229",
        timeout: 30_000
      }
    end
    
    Backend.create_config(provider, config_map)
  end
end
```

---

## Workflow Integration Patterns

### Pattern: Multi-Step Workflow

**Use Case**: Complex workflows requiring multiple LLM interactions

```elixir
defmodule Prismatic.AI.WorkflowEngine do
  @moduledoc """
  Orchestrates multi-step AI workflows with state management.
  """
  
  alias Prismatic.LLM.Backend
  
  defstruct [
    :id,
    :steps,
    :current_step,
    :state,
    :config,
    :results,
    :errors
  ]
  
  @type t :: %__MODULE__{
    id: String.t(),
    steps: [workflow_step()],
    current_step: non_neg_integer(),
    state: map(),
    config: map(),
    results: [term()],
    errors: [term()]
  }
  
  @typedoc "Workflow step definition"
  @type workflow_step :: %{
    name: String.t(),
    prompt_template: String.t(),
    context: map(),
    validation: function(),
    error_handler: function()
  }
  
  @doc """
  Creates a new workflow instance.
  
  ## Examples
  
      iex> workflow = WorkflowEngine.new([
      ...>   %{
      ...>     name: "analyze_requirements",
      ...>     prompt_template: "Analyze: {{requirements}}",
      ...>     context: %{temperature: 0.3},
      ...>     validation: &validate_analysis/1,
      ...>     error_handler: &handle_analysis_error/1
      ...>   }
      ...> ])
      iex> workflow.current_step
      0
  """
  @spec new([workflow_step()], keyword()) :: t()
  def new(steps, opts \\ []) do
    provider = Keyword.get(opts, :provider, :openai)
    
    %__MODULE__{
      id: generate_workflow_id(),
      steps: steps,
      current_step: 0,
      state: %{},
      config: create_workflow_config(provider),
      results: [],
      errors: []
    }
  end
  
  @doc """
  Executes the workflow from current step to completion.
  
  ## Examples
  
      iex> {:ok, workflow} = WorkflowEngine.execute(workflow, %{requirements: "Build API"})
      iex> length(workflow.results)
      1
  """
  @spec execute(t(), map()) :: {:ok, t()} | {:error, term()}
  def execute(%__MODULE__{} = workflow, initial_state \\ %{}) do
    workflow = %{workflow | state: Map.merge(workflow.state, initial_state)}
    
    :telemetry.execute(
      [:prismatic, :ai, :workflow, :start],
      %{step_count: length(workflow.steps)},
      %{workflow_id: workflow.id}
    )
    
    execute_steps(workflow)
  end
  
  defp execute_steps(workflow) do
    if workflow.current_step >= length(workflow.steps) do
      :telemetry.execute(
        [:prismatic, :ai, :workflow, :complete],
        %{total_steps: length(workflow.steps)},
        %{workflow_id: workflow.id, success: true}
      )
      
      {:ok, workflow}
    else
      case execute_step(workflow) do
        {:ok, updated_workflow} -> execute_steps(updated_workflow)
        error -> error
      end
    end
  end
  
  defp execute_step(%__MODULE__{current_step: step_index} = workflow) do
    case Enum.at(workflow.steps, step_index) do
      nil -> 
        {:ok, workflow}  # Workflow complete
      
      step ->
        case execute_workflow_step(workflow, step) do
          {:ok, result} ->
            updated_workflow = %{
              workflow |
              current_step: step_index + 1,
              results: workflow.results ++ [result],
              state: Map.put(workflow.state, step.name, result)
            }
            
            {:ok, updated_workflow}
            
          {:error, reason} = error ->
            case step[:error_handler] do
              nil -> error
              handler when is_function(handler, 2) -> handler.(workflow, reason)
              _ -> error
            end
        end
    end
  end
  
  defp execute_workflow_step(workflow, step) do
    with {:ok, prompt} <- build_step_prompt(step, workflow.state),
         {:ok, response} <- Backend.generate_response(
           workflow.config,
           prompt,
           step[:context] || %{}
         ),
         {:ok, validated_result} <- validate_step_result(step, response) do
      {:ok, validated_result}
    end
  end
  
  defp build_step_prompt(step, state) do
    result = Enum.reduce(state, step.prompt_template, fn {key, value}, acc ->
      String.replace(acc, "{{#{key}}}", to_string(value))
    end)
    
    {:ok, result}
  end
  
  defp validate_step_result(step, result) do
    case step[:validation] do
      nil -> {:ok, result}
      validator when is_function(validator, 1) -> validator.(result)
      _ -> {:ok, result}
    end
  end
  
  defp generate_workflow_id do
    :crypto.strong_rand_bytes(16) |> Base.encode64(padding: false)
  end
  
  defp create_workflow_config(provider) do
    {:ok, config} = Backend.create_config(provider, %{
      api_key: get_api_key(provider),
      model: get_model(provider),
      timeout: 45_000  # Longer timeout for workflows
    })
    
    config
  end
  
  defp get_api_key(:openai), do: System.get_env("OPENAI_API_KEY")
  defp get_api_key(:anthropic), do: System.get_env("ANTHROPIC_API_KEY")
  
  defp get_model(:openai), do: "gpt-4"
  defp get_model(:anthropic), do: "claude-3-sonnet-20240229"
end
```

---

## Reliability Patterns

### Pattern: Circuit Breaker Integration

**Use Case**: Automatic failure detection and recovery

```elixir
defmodule Prismatic.AI.ReliableClient do
  @moduledoc """
  LLM client with enhanced reliability features.
  """
  
  alias Prismatic.LLM.Backend
  
  require Logger
  
  @doc """
  Executes LLM request with circuit breaker protection and fallback.
  
  ## Examples
  
      iex> ReliableClient.request_with_fallback(
      ...>   "Generate code",
      ...>   fallback: fn -> "Fallback response" end
      ...> )
      {:ok, "Generated code response"}
  """
  @spec request_with_fallback(String.t(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def request_with_fallback(prompt, opts \\ []) do
    provider = Keyword.get(opts, :provider, :openai)
    fallback_fn = Keyword.get(opts, :fallback)
    
    case execute_with_circuit_breaker(provider, prompt, opts) do
      {:ok, response} -> 
        {:ok, response}
        
      {:error, :circuit_breaker_open} when not is_nil(fallback_fn) ->
        Logger.warn("Circuit breaker open for #{provider}, using fallback")
        
        :telemetry.execute(
          [:prismatic, :ai, :fallback, :used],
          %{provider: provider},
          %{reason: :circuit_breaker_open}
        )
        
        {:ok, fallback_fn.()}
        
      {:error, reason} = error ->
        Logger.error("LLM request failed: #{inspect(reason)}")
        
        if fallback_fn do
          Logger.info("Using fallback for failed request")
          {:ok, fallback_fn.()}
        else
          error
        end
    end
  end
  
  @doc """
  Executes request with automatic provider failover.
  
  ## Examples
  
      iex> ReliableClient.request_with_failover(
      ...>   "Analyze code",
      ...>   providers: [:openai, :anthropic]
      ...> )
      {:ok, "Analysis result"}
  """
  @spec request_with_failover(String.t(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def request_with_failover(prompt, opts \\ []) do
    providers = Keyword.get(opts, :providers, [:openai, :anthropic])
    
    request_with_failover_recursive(prompt, providers, opts, [])
  end
  
  defp request_with_failover_recursive(_prompt, [], _opts, errors) do
    {:error, {:all_providers_failed, errors}}
  end
  
  defp request_with_failover_recursive(prompt, [provider | rest], opts, errors) do
    case execute_with_circuit_breaker(provider, prompt, opts) do
      {:ok, response} ->
        if length(errors) > 0 do
          Logger.info("Provider #{provider} succeeded after #{length(errors)} failures")
        end
        {:ok, response}
        
      {:error, reason} ->
        Logger.warn("Provider #{provider} failed: #{inspect(reason)}")
        
        :telemetry.execute(
          [:prismatic, :ai, :provider, :failed],
          %{provider: provider},
          %{reason: reason}
        )
        
        request_with_failover_recursive(
          prompt, 
          rest, 
          opts, 
          errors ++ [{provider, reason}]
        )
    end
  end
  
  defp execute_with_circuit_breaker(provider, prompt, opts) do
    with {:ok, config} <- create_config(provider, opts) do
      context = build_context(opts)
      Backend.generate_response(config, prompt, context)
    end
  end
  
  defp create_config(provider, opts) do
    config_map = case provider do
      :openai -> %{
        api_key: System.get_env("OPENAI_API_KEY"),
        model: Keyword.get(opts, :model, "gpt-4"),
        timeout: Keyword.get(opts, :timeout, 30_000),
        max_retries: Keyword.get(opts, :max_retries, 3)
      }
      :anthropic -> %{
        api_key: System.get_env("ANTHROPIC_API_KEY"),
        model: Keyword.get(opts, :model, "claude-3-sonnet-20240229"),
        timeout: Keyword.get(opts, :timeout, 30_000),
        max_retries: Keyword.get(opts, :max_retries, 3)
      }
    end
    
    Backend.create_config(provider, config_map)
  end
  
  defp build_context(opts) do
    %{
      temperature: Keyword.get(opts, :temperature, 0.3),
      max_tokens: Keyword.get(opts, :max_tokens, 1500),
      system_message: Keyword.get(opts, :system_message)
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end
end
```

---

## Performance Patterns

### Pattern: Request Caching

**Use Case**: Cache responses to avoid redundant LLM calls

```elixir
defmodule Prismatic.AI.CachedClient do
  @moduledoc """
  LLM client with intelligent response caching.
  """
  
  alias Prismatic.LLM.Backend
  
  require Logger
  
  @doc """
  Executes request with caching based on prompt hash.
  
  ## Examples
  
      iex> CachedClient.request_with_cache("Explain recursion")
      {:ok, "Recursion is..."}
      
      iex> CachedClient.request_with_cache("Explain recursion")  # Cache hit
      {:ok, "Recursion is..."}
  """
  @spec request_with_cache(String.t(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def request_with_cache(prompt, opts \\ []) do
    cache_key = generate_cache_key(prompt, opts)
    ttl = Keyword.get(opts, :cache_ttl, 3600)  # 1 hour default
    
    case get_from_cache(cache_key) do
      {:ok, cached_response} ->
        Logger.debug("Cache hit for prompt: #{String.slice(prompt, 0, 50)}...")
        
        :telemetry.execute(
          [:prismatic, :ai, :cache, :hit],
          %{prompt_length: String.length(prompt)},
          %{cache_key: cache_key}
        )
        
        {:ok, cached_response}
        
      :miss ->
        case execute_request(prompt, opts) do
          {:ok, response} ->
            store_in_cache(cache_key, response, ttl)
            
            :telemetry.execute(
              [:prismatic, :ai, :cache, :miss],
              %{prompt_length: String.length(prompt), response_length: String.length(response)},
              %{cache_key: cache_key}
            )
            
            {:ok, response}
            
          error -> error
        end
    end
  end
  
  defp generate_cache_key(prompt, opts) do
    # Include relevant options in cache key
    cache_data = %{
      prompt: prompt,
      provider: Keyword.get(opts, :provider, :openai),
      model: Keyword.get(opts, :model),
      temperature: Keyword.get(opts, :temperature, 0.3),
      system_message: Keyword.get(opts, :system_message)
    }
    
    :crypto.hash(:sha256, :erlang.term_to_binary(cache_data))
    |> Base.encode16(case: :lower)
  end
  
  defp get_from_cache(cache_key) do
    case :ets.lookup(:ai_cache, cache_key) do
      [{^cache_key, response, timestamp}] ->
        if System.system_time(:second) - timestamp < get_ttl(cache_key) do
          {:ok, response}
        else
          :ets.delete(:ai_cache, cache_key)
          :miss
        end
        
      [] -> :miss
    end
  end
  
  defp store_in_cache(cache_key, response, ttl) do
    timestamp = System.system_time(:second)
    :ets.insert(:ai_cache, {cache_key, response, timestamp})
    :ets.insert(:ai_cache_ttl, {cache_key, ttl})
  end
  
  defp execute_request(prompt, opts) do
    provider = Keyword.get(opts, :provider, :openai)
    
    with {:ok, config} <- create_config(provider, opts) do
      context = build_context(opts)
      Backend.generate_response(config, prompt, context)
    end
  end
  
  defp create_config(provider, opts) do
    config_map = case provider do
      :openai -> %{
        api_key: System.get_env("OPENAI_API_KEY"),
        model: Keyword.get(opts, :model, "gpt-4"),
        timeout: 30_000
      }
      :anthropic -> %{
        api_key: System.get_env("ANTHROPIC_API_KEY"),
        model: Keyword.get(opts, :model, "claude-3-sonnet-20240229"),
        timeout: 30_000
      }
    end
    
    Backend.create_config(provider, config_map)
  end
  
  defp build_context(opts) do
    %{
      temperature: Keyword.get(opts, :temperature, 0.3),
      max_tokens: Keyword.get(opts, :max_tokens, 1500),
      system_message: Keyword.get(opts, :system_message)
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end
  
  defp get_ttl(cache_key) do
    case :ets.lookup(:ai_cache_ttl, cache_key) do
      [{^cache_key, ttl}] -> ttl
      [] -> 3600  # Default 1 hour
    end
  end
end
```

---

## Advanced Integration Patterns

### Pattern: AI-Powered Code Analysis

**Use Case**: Comprehensive code analysis using LLM capabilities

```elixir
defmodule Prismatic.AI.CodeAnalyzer do
  @moduledoc """
  Advanced code analysis using LLM capabilities.
  """
  
  alias Prismatic.LLM.Backend
  alias Prismatic.AI.TemplateClient
  
  @analysis_types [
    :quality,
    :security,
    :performance,
    :maintainability,
    :documentation
  ]
  
  @doc """
  Performs comprehensive code analysis.
  
  ## Examples
  
      iex> {:ok, analysis} = CodeAnalyzer.analyze_code(
      ...>   "defmodule Example do\n  def hello, do: :world\nend",
      ...>   types: [:quality, :security]
      ...> )
      iex> Map.has_key?(analysis, :quality)
      true
  """
  @spec analyze_code(String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def analyze_code(code, opts \\ []) do
    analysis_types = Keyword.get(opts, :types, @analysis_types)
    provider = Keyword.get(opts, :provider, :openai)
    
    results = 
      analysis_types
      |> Task.async_stream(
        fn type -> {type, perform_analysis(code, type, provider)} end,
        max_concurrency: 3,
        timeout: 60_000
      )
      |> Enum.reduce(%{}, fn
        {:ok, {type, {:ok, result}}} -> &Map.put(&1, type, result)
        {:ok, {type, {:error, reason}}} -> &Map.put(&1, type, {:error, reason})
        _ -> & &1
      end)
    
    {:ok, results}
  end
  
  defp perform_analysis(code, :quality, provider) do
    TemplateClient.execute_template(
      :quality_analysis,
      %{code: code},
      provider: provider
    )
  end
  
  defp perform_analysis(code, :security, provider) do
    TemplateClient.execute_template(
      :security_analysis,
      %{code: code},
      provider: provider
    )
  end
  
  defp perform_analysis(code, :performance, provider) do
    TemplateClient.execute_template(
      :performance_analysis,
      %{code: code},
      provider: provider
    )
  end
  
  defp perform_analysis(code, :maintainability, provider) do
    TemplateClient.execute_template(
      :maintainability_analysis,
      %{code: code},
      provider: provider
    )
  end
  
  defp perform_analysis(code, :documentation, provider) do
    TemplateClient.execute_template(
      :documentation_analysis,
      %{code: code},
      provider: provider
    )
  end
end
```

---

## Best Practices

### Configuration Management

1. **Environment-Based Configuration**:
   ```elixir
   # config/config.exs
   config :prismatic, :llm,
     default_provider: :openai,
     default_timeout: 30_000,
     max_retries: 3,
     cache_ttl: 3600
   
   # config/dev.exs
   config :prismatic, :llm,
     default_provider: :test  # Use test backend in development
   ```

2. **Secure API Key Management**:
   ```elixir
   # Use environment variables
   api_key = System.get_env("OPENAI_API_KEY") || 
             raise "OPENAI_API_KEY environment variable not set"
   ```

3. **Provider-Specific Defaults**:
   ```elixir
   defp get_provider_defaults(:openai) do
     %{model: "gpt-4", temperature: 0.3, max_tokens: 1500}
   end
   
   defp get_provider_defaults(:anthropic) do
     %{model: "claude-3-sonnet-20240229", temperature: 0.3, max_tokens: 1500}
   end
   ```

### Error Handling Strategy

1. **Categorize Errors**:
   ```elixir
   defp handle_llm_error({:api_error, 429, _}), do: {:retry_later, "Rate limit exceeded"}
   defp handle_llm_error({:api_error, 401, _}), do: {:config_error, "Invalid API key"}
   defp handle_llm_error({:timeout, _}), do: {:retry, "Request timeout"}
   defp handle_llm_error(reason), do: {:error, reason}
   ```

2. **Graceful Degradation**:
   ```elixir
   def analyze_with_fallback(code) do
     case analyze_code(code) do
       {:ok, result} -> {:ok, result}
       {:error, _} -> {:ok, basic_static_analysis(code)}
     end
   end
   ```

### Performance Optimization

1. **Request Batching**:
   ```elixir
   def analyze_multiple_files(file_paths) do
     file_paths
     |> Enum.chunk_every(5)  # Process in batches
     |> Enum.map(&analyze_batch/1)
     |> List.flatten()
   end
   ```

2. **Intelligent Caching**:
   ```elixir
   # Cache based on code hash + analysis type
   cache_key = :crypto.hash(:sha256, code <> to_string(analysis_type))
   ```

3. **Resource Management**:
   ```elixir
   # Limit concurrent requests
   @max_concurrent_requests 5
   
   def process_with_semaphore(requests) do
     Semaphore.acquire(@max_concurrent_requests)
     try do
       process_request(requests)
     after
       Semaphore.release(@max_concurrent_requests)
     end
   end
   ```

---

## Related Documentation

- [Prompt Engineering Templates](prompt-engineering-templates.md) - Detailed prompt templates and examples
- [Best Practices for AI Development](best-practices.md) - Core principles and guidelines
- [Automated Code Generation](automated-code-generation.md) - End-to-end automation workflows
- [Performance Optimization](performance-optimization.md) - Optimizing AI workflows
- [Troubleshooting LLM Integrations](troubleshooting.md) - Common issues and solutions

---

**💡 Integration Tip**: Start with simple patterns and gradually introduce complexity. Always include proper error handling, monitoring, and fallback mechanisms. Test integration patterns thoroughly with different providers to ensure robustness.