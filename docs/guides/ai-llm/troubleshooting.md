# Troubleshooting LLM Integrations

**Comprehensive troubleshooting guide for common issues with LLM integrations in the Prismatic ecosystem.**

<!-- NAV_START -->
## Navigation

**Current Location**: [Home](../../README.md) > [Guides](../README.md) > [AI/LLM](README.md) > Troubleshooting LLM Integrations

### Quick Links

- **📚 [Parent Directory](README.md)** - Return to AI/LLM guides
- **🏠 [Documentation Home](../../README.md)** - Main documentation index
- **🔍 [Search Documentation](../../reference/glossary.md)** - Find terms and concepts

### Related Documentation

- [LLM Integration Patterns](llm-integration-patterns.md) - Technical integration patterns
- [LLM Backend Implementation](../../../lib/prismatic/llm/backend.ex) - Core LLM system reference
- [Best Practices for AI Development](best-practices.md) - Prevention strategies
- [Performance Optimization](performance-optimization.md) - Performance-related troubleshooting
- [Monitoring and Observability](monitoring-observability.md) - Monitoring and debugging
<!-- NAV_END -->

---

## Overview

This guide provides systematic troubleshooting strategies for common issues encountered when integrating and using LLMs in the Prismatic ecosystem. It covers configuration problems, network issues, performance bottlenecks, and debugging techniques.

### Troubleshooting Approach

1. **Identify** - Gather symptoms and error information
2. **Isolate** - Narrow down the problem scope
3. **Investigate** - Use debugging tools and techniques
4. **Implement** - Apply targeted solutions
5. **Validate** - Verify the fix works correctly
6. **Document** - Record the solution for future reference

---

## Common Issue Categories

### 🔧 [Configuration Issues](#configuration-issues)
*API keys, model settings, and environment configuration problems*

### 🌐 [Network and Connectivity](#network-and-connectivity)
*Timeouts, connection failures, and proxy problems*

### ⚡ [Performance Issues](#performance-issues)
*Slow responses, timeouts, and optimization problems*

### 🔄 [Rate Limiting](#rate-limiting)
*Rate limit exceeded, quota management, and throttling*

### 📝 [Response Quality](#response-quality)
*Poor outputs, inconsistent results, and prompt problems*

### 🛡️ [Circuit Breaker Issues](#circuit-breaker-issues)
*Circuit breaker failures and retry logic problems*

### 🔍 [Debugging and Monitoring](#debugging-and-monitoring)
*Logging, telemetry, and observability*

---

## Configuration Issues

### Missing or Invalid API Keys

**Symptoms**:
- `{:error, :invalid_api_key}`
- `{:error, {:authentication_failed, reason}}`
- 401 Unauthorized responses

**Quick Diagnosis**:
```elixir
# Check environment variables
System.get_env("OPENAI_API_KEY") |> IO.inspect(label: "OpenAI Key")
System.get_env("ANTHROPIC_API_KEY") |> IO.inspect(label: "Anthropic Key")

# Validate key formats
defp validate_api_keys do
  openai_key = System.get_env("OPENAI_API_KEY")
  anthropic_key = System.get_env("ANTHROPIC_API_KEY")
  
  cond do
    is_nil(openai_key) -> {:error, :missing_openai_key}
    not String.starts_with?(openai_key, "sk-") -> {:error, :invalid_openai_key_format}
    is_nil(anthropic_key) -> {:error, :missing_anthropic_key}
    not String.starts_with?(anthropic_key, "sk-ant-") -> {:error, :invalid_anthropic_key_format}
    true -> :ok
  end
end
```

**Solutions**:

1. **Environment Setup**:
   ```bash
   # Set environment variables
   export OPENAI_API_KEY="sk-your-openai-key"
   export ANTHROPIC_API_KEY="sk-ant-your-anthropic-key"
   
   # Verify keys are set correctly
   echo $OPENAI_API_KEY | head -c 20
   echo $ANTHROPIC_API_KEY | head -c 20
   ```

2. **Configuration Validation**:
   ```elixir
   defmodule Prismatic.LLM.ConfigValidator do
     def validate_configuration do
       with :ok <- validate_openai_config(),
            :ok <- validate_anthropic_config() do
         :ok
       else
         {:error, reason} -> {:error, reason}
       end
     end
     
     defp validate_openai_config do
       case System.get_env("OPENAI_API_KEY") do
         nil -> {:error, :missing_openai_key}
         key when is_binary(key) ->
           if String.starts_with?(key, "sk-") and String.length(key) > 20 do
             :ok
           else
             {:error, :invalid_openai_key_format}
           end
       end
     end
     
     defp validate_anthropic_config do
       case System.get_env("ANTHROPIC_API_KEY") do
         nil -> {:error, :missing_anthropic_key}
         key when is_binary(key) ->
           if String.starts_with?(key, "sk-ant-") and String.length(key) > 20 do
             :ok
           else
             {:error, :invalid_anthropic_key_format}
           end
       end
     end
   end
   ```

### Model Configuration Problems

**Symptoms**:
- `{:error, :invalid_model}`
- Model not found errors
- Unexpected model behavior

**Solutions**:

1. **Use Current Model Names**:
   ```elixir
   @current_models %{
     openai: [
       "gpt-4-0125-preview",
       "gpt-4-turbo", 
       "gpt-3.5-turbo-0125"
     ],
     anthropic: [
       "claude-3-opus-20240229",
       "claude-3-sonnet-20240229", 
       "claude-3-haiku-20240307"
     ]
   }
   
   defp validate_model(provider, model) do
     available_models = Map.get(@current_models, provider, [])
     
     if model in available_models do
       :ok
     else
       {:error, {:invalid_model, model, available_models}}
     end
   end
   ```

---

## Network and Connectivity

### Timeout Issues

**Symptoms**:
- `{:error, :timeout}`
- `{:error, {:request_failed, :timeout}}`
- Requests hanging indefinitely

**Diagnosis**:
```elixir
# Test with different timeout values
defp diagnose_timeout_issues(config) do
  timeouts = [5_000, 15_000, 30_000, 60_000]
  
  results = Enum.map(timeouts, fn timeout ->
    test_config = Map.put(config, :timeout, timeout)
    
    start_time = System.monotonic_time(:millisecond)
    result = Prismatic.LLM.Backend.health_check(test_config)
    end_time = System.monotonic_time(:millisecond)
    
    {timeout, result, end_time - start_time}
  end)
  
  # Find optimal timeout
  successful = Enum.filter(results, fn {_timeout, result, _duration} -> result == :ok end)
  
  case successful do
    [] -> {:error, :all_timeouts_failed}
    [{recommended_timeout, :ok, _duration} | _] -> {:ok, recommended_timeout}
  end
end
```

**Solutions**:

1. **Dynamic Timeout Calculation**:
   ```elixir
   defp calculate_timeout(prompt, base_timeout \\ 30_000) do
     prompt_length = String.length(prompt)
     
     multiplier = cond do
       prompt_length < 1000 -> 1.0
       prompt_length < 5000 -> 1.5
       prompt_length < 10000 -> 2.0
       true -> 3.0
     end
     
     trunc(base_timeout * multiplier)
   end
   ```

2. **Retry with Exponential Backoff**:
   ```elixir
   defp request_with_backoff(request_fn, max_retries \\ 3) do
     request_with_backoff(request_fn, max_retries, 1, 1000)
   end
   
   defp request_with_backoff(_request_fn, max_retries, attempt, _delay) 
        when attempt > max_retries do
     {:error, :max_retries_exceeded}
   end
   
   defp request_with_backoff(request_fn, max_retries, attempt, delay) do
     case request_fn.() do
       {:ok, result} -> {:ok, result}
       {:error, reason} when reason in [:timeout, :econnrefused, :enetunreach] ->
         Logger.warn("Network error on attempt #{attempt}: #{reason}, retrying in #{delay}ms")
         Process.sleep(delay)
         
         next_delay = min(delay * 2 + :rand.uniform(1000), 30_000)
         request_with_backoff(request_fn, max_retries, attempt + 1, next_delay)
       
       {:error, other} -> {:error, other}
     end
   end
   ```

### Connection Failures

**Symptoms**:
- `{:error, :econnrefused}`
- `{:error, :enetunreach}`
- DNS resolution failures

**Quick Network Test**:
```elixir
defp test_network_connectivity do
  tests = [
    {"OpenAI DNS", fn -> :inet.gethostbyname('api.openai.com') end},
    {"Anthropic DNS", fn -> :inet.gethostbyname('api.anthropic.com') end},
    {"HTTP Connectivity", fn -> HTTPoison.get("https://api.openai.com", [], timeout: 5000) end}
  ]
  
  Enum.map(tests, fn {name, test_fn} ->
    case test_fn.() do
      {:ok, _} -> {name, :ok}
      {:error, reason} -> {name, {:error, reason}}
    end
  end)
end
```

---

## Performance Issues

### Slow Response Times

**Symptoms**:
- Requests taking longer than expected
- High latency measurements
- Timeouts occurring frequently

**Performance Benchmarking**:
```elixir
defp benchmark_performance(config, test_prompts) do
  results = Enum.map(test_prompts, fn prompt ->
    start_time = System.monotonic_time(:millisecond)
    
    result = Prismatic.LLM.Backend.generate_response(
      config,
      prompt,
      %{max_tokens: 100, temperature: 0.3}
    )
    
    end_time = System.monotonic_time(:millisecond)
    duration = end_time - start_time
    
    %{
      prompt_length: String.length(prompt),
      duration: duration,
      success: match?({:ok, _}, result)
    }
  end)
  
  %{
    average_duration: Enum.sum(Enum.map(results, & &1.duration)) / length(results),
    success_rate: Enum.count(results, & &1.success) / length(results),
    results: results
  }
end
```

**Optimization Strategies**:

1. **Request Parameter Optimization**:
   ```elixir
   defp optimize_request_params(prompt, context) do
     # Adjust parameters based on prompt characteristics
     optimized = context
     
     # Reduce max_tokens for shorter responses
     optimized = case String.length(prompt) do
       len when len < 500 -> Map.put(optimized, :max_tokens, 150)
       len when len < 1500 -> Map.put(optimized, :max_tokens, 300)
       _ -> Map.put(optimized, :max_tokens, 1000)
     end
     
     # Lower temperature for faster, more deterministic responses
     Map.put(optimized, :temperature, 0.1)
   end
   ```

2. **Response Caching**:
   ```elixir
   defp cached_request(prompt, context, cache_ttl \\ 3600) do
     cache_key = generate_cache_key(prompt, context)
     
     case get_from_cache(cache_key) do
       {:ok, cached_response} -> 
         Logger.debug("Cache hit for prompt")
         {:ok, cached_response}
       :miss ->
         case make_request(prompt, context) do
           {:ok, response} = success ->
             store_in_cache(cache_key, response, cache_ttl)
             success
           error -> error
         end
     end
   end
   
   defp generate_cache_key(prompt, context) do
     cache_data = %{
       prompt: prompt,
       temperature: Map.get(context, :temperature, 0.3),
       max_tokens: Map.get(context, :max_tokens, 1000)
     }
     
     :crypto.hash(:sha256, :erlang.term_to_binary(cache_data))
     |> Base.encode16(case: :lower)
   end
   ```

---

## Rate Limiting

### Rate Limit Exceeded Errors

**Symptoms**:
- `{:error, :rate_limit_exceeded}`
- HTTP 429 Too Many Requests
- Quota exceeded messages

**Rate Limit Monitoring**:
```elixir
defmodule Prismatic.LLM.RateLimitTracker do
  use GenServer
  
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def record_request(provider) do
    GenServer.cast(__MODULE__, {:record_request, provider, System.system_time(:second)})
  end
  
  def check_rate_limit(provider) do
    GenServer.call(__MODULE__, {:check_rate_limit, provider})
  end
  
  def init(_opts) do
    {:ok, %{requests: %{}}}
  end
  
  def handle_cast({:record_request, provider, timestamp}, state) do
    minute = div(timestamp, 60)
    
    requests = Map.update(state.requests, {provider, minute}, 1, & &1 + 1)
    
    # Clean old data (keep last 5 minutes)
    current_minute = div(System.system_time(:second), 60)
    requests = Map.filter(requests, fn {{_provider, minute}, _} -> 
      current_minute - minute <= 5 
    end)
    
    {:noreply, %{state | requests: requests}}
  end
  
  def handle_call({:check_rate_limit, provider}, _from, state) do
    current_minute = div(System.system_time(:second), 60)
    
    recent_requests = 
      state.requests
      |> Enum.filter(fn {{p, minute}, _} -> p == provider and current_minute - minute <= 1 end)
      |> Enum.map(fn {_, count} -> count end)
      |> Enum.sum()
    
    limit = get_provider_rate_limit(provider)
    utilization = recent_requests / limit
    
    status = cond do
      utilization < 0.8 -> :ok
      utilization < 0.95 -> {:wait, 1000}
      true -> {:error, :rate_limit_exceeded}
    end
    
    {:reply, status, state}
  end
  
  defp get_provider_rate_limit(:openai), do: 60
  defp get_provider_rate_limit(:anthropic), do: 50
end
```

**Rate Limiting Solution**:
```elixir
defp request_with_rate_limit(provider, request_fn) do
  case Prismatic.LLM.RateLimitTracker.check_rate_limit(provider) do
    :ok -> 
      result = request_fn.()
      Prismatic.LLM.RateLimitTracker.record_request(provider)
      result
    {:wait, delay} -> 
      Logger.info("Rate limit approaching, waiting #{delay}ms")
      Process.sleep(delay)
      request_with_rate_limit(provider, request_fn)
    {:error, :rate_limit_exceeded} ->
      {:error, :rate_limit_exceeded}
  end
end
```

---

## Response Quality

### Poor or Inconsistent Responses

**Symptoms**:
- Responses don't match expected format
- Quality varies between requests
- Incomplete or truncated responses

**Response Validation**:
```elixir
defp validate_response_quality(response, expected_format) do
  issues = []
  
  # Check minimum length
  issues = if String.length(response) < 50 do
    [:too_short | issues]
  else
    issues
  end
  
  # Check format compliance
  issues = case expected_format do
    :json ->
      case Jason.decode(response) do
        {:ok, _} -> issues
        {:error, _} -> [:invalid_json | issues]
      end
    _ -> issues
  end
  
  # Check for completeness
  issues = if String.ends_with?(response, "...") do
    [:incomplete | issues]
  else
    issues
  end
  
  case issues do
    [] -> :ok
    issues -> {:error, issues}
  end
end
```

**Quality Improvement Strategies**:

1. **Enhanced Prompting**:
   ```elixir
   defp enhance_prompt_for_quality(base_prompt) do
     quality_instructions = """
     
     IMPORTANT INSTRUCTIONS:
     - Provide a complete, detailed response
     - Follow the specified format exactly
     - Use specific, concrete examples
     - Ensure technical accuracy
     - Do not truncate your response
     """
     
     base_prompt <> quality_instructions
   end
   ```

2. **Response Retry with Adjustments**:
   ```elixir
   defp request_with_quality_retry(config, prompt, context, max_retries \\ 2) do
     case make_request(config, prompt, context) do
       {:ok, response} ->
         case validate_response_quality(response, Map.get(context, :format)) do
           :ok -> {:ok, response}
           {:error, issues} when max_retries > 0 ->
             Logger.warn("Response quality issues: #{inspect(issues)}, retrying")
             
             # Adjust context for retry
             adjusted_context = adjust_context_for_issues(context, issues)
             request_with_quality_retry(config, prompt, adjusted_context, max_retries - 1)
           
           {:error, issues} -> 
             {:error, {:quality_issues, issues}}
         end
       error -> error
     end
   end
   
   defp adjust_context_for_issues(context, issues) do
     context
     |> adjust_for_length_issues(issues)
     |> adjust_for_format_issues(issues)
   end
   
   defp adjust_for_length_issues(context, issues) do
     if :too_short in issues do
       current_max_tokens = Map.get(context, :max_tokens, 1000)
       Map.put(context, :max_tokens, current_max_tokens * 1.5 |> trunc())
     else
       context
     end
   end
   
   defp adjust_for_format_issues(context, issues) do
     if :invalid_json in issues do
       Map.put(context, :temperature, 0.1)  # Lower temperature for structured output
     else
       context
     end
   end
   ```

---

## Circuit Breaker Issues

### Circuit Breaker Open

**Symptoms**:
- `{:error, :circuit_breaker_open}`
- Requests failing immediately
- Circuit breaker not recovering

**Circuit Breaker Status Check**:
```elixir
defp check_circuit_breaker_status(provider) do
  # This would integrate with your circuit breaker implementation
  case Prismatic.LLM.Backend.CircuitBreaker.get_status(provider) do
    :closed -> :ok
    :open -> {:error, :circuit_breaker_open}
    :half_open -> {:warning, :circuit_breaker_recovering}
  end
end
```

**Recovery Strategies**:

1. **Manual Reset with Connectivity Test**:
   ```elixir
   defp reset_circuit_breaker_if_healthy(provider) do
     case test_provider_connectivity(provider) do
       :ok ->
         Prismatic.LLM.Backend.CircuitBreaker.reset(provider)
         Logger.info("Circuit breaker reset for #{provider}")
         :ok
       {:error, reason} ->
         Logger.warn("Circuit breaker reset failed, connectivity issue: #{reason}")
         {:error, reason}
     end
   end
   
   defp test_provider_connectivity(provider) do
     minimal_config = get_minimal_test_config(provider)
     Prismatic.LLM.Backend.health_check(minimal_config)
   end
   ```

2. **Fallback Provider Strategy**:
   ```elixir
   defp request_with_fallback(primary_provider, fallback_providers, prompt, context) do
     providers = [primary_provider | fallback_providers]
     try_providers(providers, prompt, context, [])
   end
   
   defp try_providers([], _prompt, _context, errors) do
     {:error, {:all_providers_failed, errors}}
   end
   
   defp try_providers([provider | rest], prompt, context, errors) do
     config = get_config_for_provider(provider)
     
     case Prismatic.LLM.Backend.generate_response(config, prompt, context) do
       {:ok, response} -> {:ok, response}
       {:error, :circuit_breaker_open} = error ->
         try_providers(rest, prompt, context, [{provider, error} | errors])
       {:error, reason} = error ->
         try_providers(rest, prompt, context, [{provider, error} | errors])
     end
   end
   ```

---

## Debugging and Monitoring

### Comprehensive Logging

```elixir
defmodule Prismatic.LLM.Logger do
  require Logger
  
  def log_request_start(provider, prompt, context) do
    request_id = generate_request_id()
    
    Logger.info("LLM request started", [
      request_id: request_id,
      provider: provider,
      prompt_length: String.length(prompt),
      temperature: Map.get(context, :temperature),
      max_tokens: Map.get(context, :max_tokens)
    ])
    
    request_id
  end
  
  def log_request_complete(request_id, result, duration) do
    case result do
      {:ok, response} ->
        Logger.info("LLM request completed", [
          request_id: request_id,
          duration: duration,
          response_length: String.length(response),
          status: :success
        ])
      
      {:error, reason} ->
        Logger.error("LLM request failed", [
          request_id: request_id,
          duration: duration,
          error: reason,
          status: :error
        ])
    end
  end
  
  defp generate_request_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end
end
```

### Health Monitoring System

```elixir
defmodule Prismatic.LLM.HealthMonitor do
  use GenServer
  
  @check_interval 60_000  # 1 minute
  
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def get_health_status do
    GenServer.call(__MODULE__, :get_status)
  end
  
  def init(_opts) do
    Process.send_after(self(), :health_check, 1000)
    {:ok, %{providers: [:openai, :anthropic], status: %{}}}
  end
  
  def handle_call(:get_status, _from, state) do
    {:reply, state.status, state}
  end
  
  def handle_info(:health_check, state) do
    new_status = perform_health_checks(state.providers)
    
    # Emit telemetry
    :telemetry.execute(
      [:prismatic, :llm, :health_check],
      %{healthy_providers: count_healthy(new_status)},
      %{status: new_status}
    )
    
    Process.send_after(self(), :health_check, @check_interval)
    {:noreply, %{state | status: new_status}}
  end
  
  defp perform_health_checks(providers) do
    providers
    |> Enum.map(fn provider ->
      {provider, check_provider_health(provider)}
    end)
    |> Map.new()
  end
  
  defp check_provider_health(provider) do
    start_time = System.monotonic_time(:millisecond)
    config = get_health_check_config(provider)
    
    case Prismatic.LLM.Backend.health_check(config) do
      :ok ->
        duration = System.monotonic_time(:millisecond) - start_time
        %{status: :healthy, response_time: duration, last_check: DateTime.utc_now()}
      
      {:error, reason} ->
        duration = System.monotonic_time(:millisecond) - start_time
        %{status: :unhealthy, error: reason, response_time: duration, last_check: DateTime.utc_now()}
    end
  end
  
  defp get_health_check_config(provider) do
    case provider do
      :openai -> %{
        backend_type: :openai,
        api_key: System.get_env("OPENAI_API_KEY"),
        model: "gpt-3.5-turbo",
        timeout: 10_000
      }
      :anthropic -> %{
        backend_type: :anthropic,
        api_key: System.get_env("ANTHROPIC_API_KEY"),
        model: "claude-3-haiku-20240307",
        timeout: 10_000
      }
    end
  end
  
  defp count_healthy(status) do
    status
    |> Map.values()
    |> Enum.count(fn provider_status -> provider_status.status == :healthy end)
  end
end
```

---

## Emergency Procedures

### Complete System Recovery

**When All Providers Fail**:

1. **Check System Status**:
   ```bash
   # Verify environment
   env | grep -E "(OPENAI|ANTHROPIC)_API_KEY"
   
   # Test network connectivity
   curl -I https://api.openai.com
   curl -I https://api.anthropic.com
   
   # Check application health
   mix run -e "Prismatic.LLM.HealthMonitor.get_health_status() |> IO.inspect"
   ```

2. **Reset All Circuit Breakers**:
   ```elixir
   defp emergency_reset_all_circuit_breakers do
     providers = [:openai, :anthropic]
     
     results = Enum.map(providers, fn provider ->
       case reset_circuit_breaker_if_healthy(provider) do
         :ok -> {provider, :reset_successful}
         {:error, reason} -> {provider, {:reset_failed, reason}}
       end
     end)
     
     Logger.info("Emergency circuit breaker reset completed: #{inspect(results)}")
     results
   end
   ```

3. **Fallback to Test Backend**:
   ```elixir
   defp enable_emergency_test_backend do
     # Temporarily use test backend for critical functionality
     Application.put_env(:prismatic, :llm, [
       default_provider: :test,
       emergency_mode: true
     ])
     
     Logger.warn("Emergency mode activated: using test backend")
   end
   ```

---

## Quick Reference

### Common Error Codes

| Error | Meaning | Quick Fix |
|-------|---------|-------|
| `:invalid_api_key` | API key missing/invalid | Check environment variables |
| `:timeout` | Request timed out | Increase timeout or optimize prompt |
| `:rate_limit_exceeded` | Too many requests | Implement rate limiting |
| `:circuit_breaker_open` | Circuit breaker active | Reset circuit breaker or use fallback |
| `:invalid_model` | Model not found | Update to current model names |
| `:econnrefused` | Connection refused | Check network connectivity |

### Diagnostic Commands

```elixir
# Quick health check
Prismatic.LLM.HealthMonitor.get_health_status()

# Validate configuration
Prismatic.LLM.ConfigValidator.validate_configuration()

# Test connectivity
test_network_connectivity()

# Check rate limits
Prismatic.LLM.RateLimitTracker.check_rate_limit(:openai)

# Emergency reset
emergency_reset_all_circuit_breakers()
```

---

## Related Documentation

- [LLM Integration Patterns](llm-integration-patterns.md) - Technical integration patterns
- [Best Practices for AI Development](best-practices.md) - Prevention strategies
- [Performance Optimization](performance-optimization.md) - Performance improvement guides
- [Monitoring and Observability](monitoring-observability.md) - Advanced monitoring setup
- [LLM Backend Implementation](../../../lib/prismatic/llm/backend.ex) - Core system reference

---

**🔧 Troubleshooting Tip**: Most LLM integration issues fall into configuration, network, or rate limiting categories. Start with the quick diagnostic commands above to identify the problem area, then apply the targeted solutions. Always test fixes in development before applying to production.