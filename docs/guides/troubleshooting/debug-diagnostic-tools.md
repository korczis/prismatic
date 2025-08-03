# Debug and Diagnostic Tools Guide

**Comprehensive guide to debugging and diagnostic tools for the Prismatic AI Agent Framework**

<!-- NAV_START -->
## Navigation

**Current Location**: [Home](../../README.md) > [Guides](../README.md) > [Troubleshooting](README.md) > Debug Tools Guide

### Quick Links

- **📚 [Parent Directory](README.md)** - Return to troubleshooting guides
- **🏠 [Documentation Home](../../README.md)** - Main documentation index
- **🔧 [Comprehensive Troubleshooting](comprehensive-troubleshooting-guide.md)** - Detailed procedures
- **❓ [FAQ](faq.md)** - Frequently asked questions
- **🚨 [Error Reference](error-reference-guide.md)** - Common error solutions

### Related Documentation

- [Development Guidelines](../development/development-guidelines.md) - Development best practices
- [Testing Guidelines](../development/testing-guidelines.md) - Testing strategies
- [Performance Monitoring](../operations/performance-monitoring.md) - Production monitoring
<!-- NAV_END -->

---

## Table of Contents

1. [Overview](#overview)
2. [Interactive Elixir (IEx) Debugging](#interactive-elixir-iex-debugging)
3. [Observer - System Monitoring](#observer---system-monitoring)
4. [BEAM VM Introspection](#beam-vm-introspection)
5. [Database Query Analysis](#database-query-analysis)
6. [Phoenix and LiveView Debugging](#phoenix-and-liveview-debugging)
7. [Log Analysis and Monitoring](#log-analysis-and-monitoring)
8. [Performance Profiling](#performance-profiling)
9. [Memory and Process Analysis](#memory-and-process-analysis)
10. [Network and Connectivity Debugging](#network-and-connectivity-debugging)
11. [Production Debugging](#production-debugging)
12. [Custom Debugging Tools](#custom-debugging-tools)

---

## Overview

### Available Tools by Category

**Interactive Debugging**:
- IEx (Interactive Elixir)
- IEx.pry/0 - Breakpoints
- Debugger module

**System Monitoring**:
- Observer - GUI monitoring tool
- :observer.start/0
- System info functions

**Performance Analysis**:
- :fprof - Function profiling
- :eprof - Process profiling  
- ExProf - Elixir profiling
- Benchee - Benchmarking

**Memory Analysis**:
- :recon - Production debugging
- Memory inspection tools
- Process tree analysis

**Application-Specific**:
- Ecto query debugging
- Phoenix debugging tools
- LiveView introspection

### Quick Reference Commands

```elixir
# Start interactive session
iex -S mix
iex -S mix phx.server

# System monitoring
:observer.start()
:runtime_tools.start()

# Process inspection
Process.list() |> length()
:recon.proc_count(:memory, 10)

# Memory analysis
:erlang.memory()
:recon.bin_leak(10)
```

---

## Interactive Elixir (IEx) Debugging

### Basic IEx Usage

#### Starting IEx Sessions

```bash
# Basic IEx session
iex

# IEx with project loaded
iex -S mix

# IEx with Phoenix server
iex -S mix phx.server

# IEx with specific environment
MIX_ENV=test iex -S mix

# IEx with additional options
iex --erl "-kernel shell_history enabled" -S mix
```

#### Essential IEx Commands

```elixir
# Help and information
h                    # Help overview
h Enum               # Help for module
h Enum.map           # Help for function
i "hello"            # Inspect data structure
v                    # Show session history
v(3)                 # Get result from line 3

# Code reloading
r ModuleName         # Reload specific module
recompile            # Recompile changed files

# Process and system info
self()               # Current process PID
Node.self()          # Current node name
:observer.start()    # Start Observer GUI

# Exit commands
Ctrl+C, a           # Abort (safe exit)
Ctrl+C, Ctrl+C     # Force quit
Ctrl+G, q           # Job control quit
```

### Advanced IEx Debugging

#### Using IEx.pry for Breakpoints

```elixir
# In your code, add breakpoint
defmodule MyModule do
  def problematic_function(data) do
    # Process some data
    processed = transform_data(data)
    
    # Add breakpoint to inspect state
    require IEx; IEx.pry()
    
    # Continue processing
    final_result = finalize(processed)
  end
end

# Start with pry enabled
iex --dbg pry -S mix

# When breakpoint hits:
# - Inspect variables: processed, data
# - Try different operations
# - Step through code
# - Continue with: respawn()
```

#### Interactive Code Modification

```elixir
# Test functions interactively
iex> defmodule TestModule do
...>   def test_function(x) do
...>     x * 2 + 1
...>   end
...> end

# Test immediately
iex> TestModule.test_function(5)
11

# Modify and retest
iex> defmodule TestModule do
...>   def test_function(x) do
...>     x * 3 + 1  # Changed logic
...>   end
...> end

iex> TestModule.test_function(5)
16
```

#### Debugging with IEx.Helpers

```elixir
# Export function for external use
iex> export_fun(MyModule, :my_function, 2, "/tmp/debug.ex")

# Clear console
iex> clear()

# Flush process messages
iex> flush()

# Get process information
iex> pid(0, 250, 0)  # Convert integers to PID
iex> i pid           # Inspect process

# File system operations
iex> ls              # List files
iex> cd "lib"        # Change directory
iex> pwd             # Print working directory
```

### IEx Configuration

#### Custom .iex.exs Configuration

```elixir
# ~/.iex.exs - Global IEx configuration
IEx.configure(
  colors: [
    eval_result: [:cyan, :bright],
    eval_error: [:red, :bright],
    eval_info: [:yellow, :bright]
  ],
  default_prompt: 
    "<%counter>" <>
    " [#{IO.ANSI.cyan()}%prefix#{IO.ANSI.reset()}]" <>
    " #{IO.ANSI.yellow()}▶#{IO.ANSI.reset()} ",
  alive_prompt:
    "<%counter>" <>
    " [#{IO.ANSI.green()}%node#{IO.ANSI.reset()}]" <>
    " [#{IO.ANSI.cyan()}%prefix#{IO.ANSI.reset()}]" <>
    " #{IO.ANSI.yellow()}▶#{IO.ANSI.reset()} "
)

# Import commonly used modules
import Ecto.Query
alias Prismatic.Repo
alias PrismaticWeb.Router.Helpers, as: Routes

# Helper functions
defmodule IExHelpers do
  def reload_config do
    Application.stop(:prismatic)
    Application.start(:prismatic)
  end
  
  def reset_db do
    Ecto.Adapters.SQL.query!(Repo, "TRUNCATE users RESTART IDENTITY CASCADE")
  end
end

import IExHelpers
```

---

## Observer - System Monitoring

### Starting Observer

```elixir
# Start Observer GUI
:observer.start()

# Start Observer on remote node
:observer.start(node_name)

# Alternative start methods
:runtime_tools.start()
:observer.start()
```

### Observer Tabs Overview

#### System Tab
- **System Information**: Erlang/OTP version, uptime, memory usage
- **Memory Usage**: Total memory, processes, atoms, binaries
- **CPU Utilization**: Per-core usage graphs
- **Statistics**: Message queue lengths, context switches

#### Load Charts Tab
- **Memory Usage Over Time**: Track memory leaks
- **CPU Usage**: Identify performance bottlenecks  
- **IO Usage**: Disk and network activity
- **Scheduler Utilization**: BEAM scheduler efficiency

#### Memory Allocators Tab
- **Allocator Details**: Memory allocator statistics
- **Carrier Utilization**: Memory carrier efficiency
- **Block Information**: Memory block sizes and counts

#### Processes Tab
- **Process List**: All running processes
- **Process Details**: Memory, message queue, current function
- **Process Tree**: Parent-child relationships
- **Kill Processes**: Terminate problematic processes

#### Ports Tab
- **Port Information**: Open ports and their details
- **Port Statistics**: Data transferred, queue sizes
- **Port Types**: Files, sockets, drivers

#### ETS Tab
- **ETS Tables**: All ETS tables in system
- **Table Statistics**: Size, memory usage, access patterns
- **Table Inspector**: Browse table contents

#### Applications Tab
- **Application List**: All loaded applications
- **Application Details**: Version, dependencies, modules
- **Application Control**: Start/stop applications

### Using Observer for Debugging

#### Identifying Memory Leaks

1. **Monitor Memory Tab**:
   - Watch total memory usage over time
   - Look for steadily increasing patterns
   - Identify which memory types are growing

2. **Check Processes Tab**:
   ```elixir
   # Sort by memory usage
   # Look for processes with excessive memory
   # Check message queue lengths
   ```

3. **Analyze ETS Tables**:
   ```elixir
   # Check table sizes
   # Look for tables growing without bounds
   # Verify table cleanup logic
   ```

#### Finding Performance Bottlenecks

```elixir
# Use Load Charts to identify:
# - CPU spikes correlating with slow responses
# - Memory allocation patterns
# - IO bottlenecks affecting performance
# - Scheduler utilization issues
```

---

## BEAM VM Introspection

### System Information Functions

#### Basic System Info

```elixir
# Erlang system information
:erlang.system_info(:schedulers)        # Number of schedulers
:erlang.system_info(:logical_processors) # CPU cores
:erlang.system_info(:process_count)     # Active processes
:erlang.system_info(:process_limit)     # Process limit
:erlang.system_info(:port_count)        # Open ports
:erlang.system_info(:atom_count)        # Atom count
:erlang.system_info(:atom_limit)        # Atom limit

# Memory information
:erlang.memory()                        # Total memory breakdown
:erlang.memory(:total)                  # Total memory
:erlang.memory(:processes)              # Process memory
:erlang.memory(:atom)                   # Atom memory
:erlang.memory(:binary)                 # Binary memory

# Node information
Node.self()                             # Current node
Node.list()                             # Connected nodes
:net_adm.ping(node)                     # Test node connectivity
```

#### Process Inspection

```elixir
# List all processes
Process.list()

# Process information
Process.info(pid)                       # All process info
Process.info(pid, :memory)              # Memory usage
Process.info(pid, :message_queue_len)   # Message queue
Process.info(pid, :current_function)    # Current function
Process.info(pid, :initial_call)        # Initial function
Process.info(pid, :stack_size)          # Stack size

# Process registry
Process.registered()                    # Named processes
Process.whereis(:process_name)          # Find named process

# Process hierarchy
Process.info(pid, :links)               # Linked processes
Process.info(pid, :monitors)            # Monitored processes
```

#### Advanced Introspection

```elixir
# Code server information
:code.all_loaded()                      # Loaded modules
:code.which(Module)                     # Module location
:code.is_loaded(Module)                 # Check if loaded

# ETS table inspection
:ets.all()                              # All ETS tables
:ets.info(table_name)                   # Table information
:ets.tab2list(table_name)               # Table contents

# Application information
Application.loaded_applications()        # Loaded applications
Application.started_applications()       # Started applications
Application.get_all_env(:app_name)       # Application config
```

### Custom Introspection Functions

```elixir
defmodule Prismatic.Debug do
  @moduledoc "Debug utilities for Prismatic"
  
  def system_health do
    %{
      processes: :erlang.system_info(:process_count),
      process_limit: :erlang.system_info(:process_limit),
      memory_mb: :erlang.memory(:total) |> div(1024 * 1024),
      uptime_ms: :erlang.statistics(:wall_clock) |> elem(0),
      schedulers: :erlang.system_info(:schedulers),
      atoms: :erlang.system_info(:atom_count),
      atom_limit: :erlang.system_info(:atom_limit)
    }
  end
  
  def top_processes(n \\ 10) do
    Process.list()
    |> Enum.map(fn pid ->
      case Process.info(pid, [:memory, :message_queue_len, :current_function]) do
        nil -> nil
        info -> {pid, info}
      end
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.sort_by(fn {_pid, info} -> info[:memory] end, :desc)
    |> Enum.take(n)
  end
  
  def memory_report do
    memory = :erlang.memory()
    total = memory[:total]
    
    memory
    |> Enum.map(fn {type, bytes} ->
      percentage = Float.round(bytes / total * 100, 1)
      mb = Float.round(bytes / (1024 * 1024), 1)
      {type, "#{mb} MB (#{percentage}%)"}
    end)
    |> Enum.into(%{})
  end
end
```

---

## Database Query Analysis

### Ecto Query Debugging

#### Enable Query Logging

```elixir
# config/dev.exs - Enable detailed query logging
config :logger, :console,
  format: "$date $time [$level] $metadata$message\n",
  metadata: [:request_id, :mfa]

config :prismatic, Prismatic.Repo,
  # ... other config
  log: :debug,  # Enable query logging
  pool_timeout: 60_000,
  timeout: 60_000
```

#### Query Analysis Tools

```elixir
# Explain query execution plan
query = from u in User, where: u.active == true
Ecto.Adapters.SQL.explain(Repo, :all, query)

# Analyze query with options
Ecto.Adapters.SQL.explain(Repo, :all, query, 
  analyze: true, 
  buffers: true, 
  verbose: true
)

# Custom query analysis
defmodule Prismatic.QueryAnalyzer do
  def explain_query(query) do
    {sql, params} = Ecto.Adapters.SQL.to_sql(:all, Repo, query)
    
    explain_sql = "EXPLAIN (ANALYZE, BUFFERS, VERBOSE) " <> sql
    
    case Ecto.Adapters.SQL.query(Repo, explain_sql, params) do
      {:ok, result} -> 
        result.rows
        |> List.flatten()
        |> Enum.join("\n")
        |> IO.puts()
      
      {:error, error} -> 
        IO.puts("Query analysis failed: #{inspect(error)}")
    end
  end
end
```

#### Slow Query Detection

```elixir
# Custom telemetry handler for slow queries
defmodule Prismatic.SlowQueryLogger do
  require Logger
  
  def handle_event([:prismatic, :repo, :query], measurements, metadata, _config) do
    duration_ms = System.convert_time_unit(measurements.total_time, :native, :millisecond)
    
    if duration_ms > 1000 do  # Log queries > 1 second
      Logger.warning(
        "Slow query detected: #{duration_ms}ms - #{metadata.source}"
      )
      
      Logger.debug(fn ->
        "Query: #{metadata.query}\nParams: #{inspect(metadata.params)}"
      end)
    end
  end
end

# Attach telemetry handler
:telemetry.attach(
  "slow-query-logger",
  [:prismatic, :repo, :query],
  &Prismatic.SlowQueryLogger.handle_event/4,
  %{}
)
```

### Database Connection Debugging

#### Connection Pool Analysis

```elixir
# Check connection pool status
DBConnection.get_connection_metrics(Prismatic.Repo)

# Custom pool monitor
defmodule Prismatic.PoolMonitor do
  def pool_status do
    case :sys.get_state(Prismatic.Repo) do
      {state, _} ->
        %{
          pool_size: state.pool_size,
          available: length(state.available),
          busy: length(state.busy)
        }
      _ -> :error
    end
  end
  
  def monitor_pool do
    :timer.apply_interval(5000, __MODULE__, :log_pool_status, [])
  end
  
  def log_pool_status do
    status = pool_status()
    Logger.info("Pool status: #{inspect(status)}")
  end
end
```

---

## Phoenix and LiveView Debugging

### Phoenix Request Debugging

#### Enable Debug Logging

```elixir
# config/dev.exs
config :phoenix, :logger, true
config :phoenix, :stacktrace_depth, 20

# Enable plug debugging
config :logger, level: :debug
```

#### Request Introspection

```elixir
# In controllers or plugs
defmodule PrismaticWeb.DebugPlug do
  import Plug.Conn
  require Logger
  
  def init(opts), do: opts
  
  def call(conn, _opts) do
    start_time = System.monotonic_time()
    
    Logger.debug(fn ->
      """
      === Request Debug Info ===
      Method: #{conn.method}
      Path: #{conn.request_path}
      Query: #{conn.query_string}
      Headers: #{inspect(conn.req_headers, pretty: true)}
      Params: #{inspect(conn.params, pretty: true)}
      """
    end)
    
    conn
    |> register_before_send(fn conn ->
      duration = System.monotonic_time() - start_time
      duration_ms = System.convert_time_unit(duration, :native, :millisecond)
      
      Logger.debug(fn ->
        """
        === Response Debug Info ===
        Status: #{conn.status}
        Duration: #{duration_ms}ms
        Response Headers: #{inspect(conn.resp_headers, pretty: true)}
        """
      end)
      
      conn
    end)
  end
end
```

### LiveView Debugging

#### LiveView Inspector

```elixir
defmodule PrismaticWeb.DebugLive do
  use PrismaticWeb, :live_view
  require Logger
  
  def mount(params, session, socket) do
    Logger.debug(fn ->
      """
      === LiveView Mount ===
      Params: #{inspect(params, pretty: true)}
      Session: #{inspect(session, pretty: true)}
      Connected: #{connected?(socket)}
      """
    end)
    
    {:ok, assign(socket, debug_info: get_debug_info())}
  end
  
  def handle_event(event, params, socket) do
    Logger.debug(fn ->
      """
      === LiveView Event ===
      Event: #{event}
      Params: #{inspect(params, pretty: true)}
      Assigns: #{inspect(socket.assigns, pretty: true)}
      """
    end)
    
    # Your event handling logic
    {:noreply, socket}
  end
  
  defp get_debug_info do
    %{
      node: Node.self(),
      process_count: :erlang.system_info(:process_count),
      memory_mb: :erlang.memory(:total) |> div(1024 * 1024),
      uptime: :erlang.statistics(:wall_clock) |> elem(0)
    }
  end
end
```

#### LiveView Process Inspection

```elixir
# Find LiveView processes
defmodule Prismatic.LiveViewDebug do
  def find_liveview_processes do
    Process.list()
    |> Enum.filter(fn pid ->
      case Process.info(pid, :initial_call) do
        {:initial_call, {Phoenix.LiveView.Channel, :start_link, _}} -> true
        _ -> false
      end
    end)
  end
  
  def inspect_liveview_process(pid) do
    case Process.info(pid, [:memory, :message_queue_len, :current_function, :dictionary]) do
      nil -> :not_found
      info ->
        socket_info = info[:dictionary]
        |> Enum.find(fn {key, _} -> key == :phoenix_live_view end)
        
        %{
          pid: pid,
          memory: info[:memory],
          message_queue: info[:message_queue_len],
          current_function: info[:current_function],
          socket_assigns: socket_info && elem(socket_info, 1).assigns
        }
    end
  end
end
```

---

## Log Analysis and Monitoring

### Structured Logging

#### Custom Logger Backend

```elixir
defmodule Prismatic.StructuredLogger do
  @behaviour :gen_event
  
  def init(_) do
    {:ok, %{}}
  end
  
  def handle_event({level, gl, {Logger, msg, ts, md}}, state) when node(gl) == node() do
    structured_log = %{
      timestamp: format_timestamp(ts),
      level: level,
      message: IO.iodata_to_binary(msg),
      metadata: Map.new(md),
      node: Node.self(),
      pid: self()
    }
    
    # Send to external logging service or write to file
    handle_structured_log(structured_log)
    
    {:ok, state}
  end
  
  def handle_event(_, state), do: {:ok, state}
  
  def handle_call(_request, state), do: {:ok, :ok, state}
  def handle_info(_msg, state), do: {:ok, state}
  def terminate(_reason, _state), do: :ok
  def code_change(_old_vsn, state, _extra), do: {:ok, state}
  
  defp format_timestamp({{year, month, day}, {hour, minute, second, millisecond}}) do
    "#{year}-#{pad(month)}-#{pad(day)} #{pad(hour)}:#{pad(minute)}:#{pad(second)}.#{pad(millisecond, 3)}"
  end
  
  defp pad(int, count \\ 2) do
    int |> Integer.to_string() |> String.pad_leading(count, "0")
  end
  
  defp handle_structured_log(log) do
    # Implement your logging destination
    Jason.encode!(log) |> IO.puts()
  end
end
```

#### Request Correlation

```elixir
defmodule PrismaticWeb.RequestIDPlug do
  import Plug.Conn
  require Logger
  
  def init(opts), do: opts
  
  def call(conn, _opts) do
    request_id = get_req_header(conn, "x-request-id") |> List.first() || generate_id()
    
    Logger.metadata(request_id: request_id)
    
    conn
    |> put_resp_header("x-request-id", request_id)
    |> assign(:request_id, request_id)
  end
  
  defp generate_id do
    :crypto.strong_rand_bytes(16) |> Base.encode64()
  end
end
```

### Log Aggregation and Analysis

#### Log Parser

```elixir
defmodule Prismatic.LogAnalyzer do
  def parse_log_file(file_path) do
    file_path
    |> File.stream!()
    |> Stream.map(&parse_log_line/1)
    |> Stream.reject(&is_nil/1)
    |> Enum.to_list()
  end
  
  defp parse_log_line(line) do
    # Parse different log formats
    cond do
      String.contains?(line, "[error]") -> parse_error_log(line)
      String.contains?(line, "[info]") -> parse_info_log(line)
      String.contains?(line, "Postgrex.Protocol") -> parse_db_log(line)
      true -> nil
    end
  end
  
  def analyze_errors(logs) do
    logs
    |> Enum.filter(& &1.level == :error)
    |> Enum.group_by(& &1.error_type)
    |> Enum.map(fn {type, errors} ->
      %{
        error_type: type,
        count: length(errors),
        first_seen: errors |> Enum.min_by(& &1.timestamp),
        last_seen: errors |> Enum.max_by(& &1.timestamp)
      }
    end)
  end
  
  def performance_metrics(logs) do
    request_logs = Enum.filter(logs, & &1.type == :request)
    
    %{
      total_requests: length(request_logs),
      avg_response_time: avg_response_time(request_logs),
      slow_requests: Enum.filter(request_logs, & &1.duration > 1000),
      error_rate: calculate_error_rate(request_logs)
    }
  end
end
```

---

## Performance Profiling

### Function Profiling with :fprof

```elixir
# Profile specific function calls
:fprof.start()
:fprof.trace(:start)

# Run your code here
MyModule.expensive_function()

:fprof.trace(:stop)
:fprof.profile()
:fprof.analyse()

# Save analysis to file
:fprof.analyse(dest: 'profile_analysis.txt')
```

### Process Profiling with :eprof

```elixir
# Profile all processes
:eprof.start()
:eprof.start_profiling([self()])

# Run code to profile
MyModule.some_function()

:eprof.stop_profiling()
:eprof.analyze()
:eprof.stop()
```

### Benchmarking with Benchee

```elixir
# Add to mix.exs
{:benchee, "~> 1.0", only: :dev}

# Create benchmark
Benchee.run(
  %{
    "fast_function" => fn -> MyModule.fast_function() end,
    "slow_function" => fn -> MyModule.slow_function() end
  },
  time: 10,
  memory_time: 2
)
```

### Custom Performance Monitoring

```elixir
defmodule Prismatic.Performance do
  def measure(name, fun) do
    start_time = System.monotonic_time()
    start_memory = :erlang.memory(:total)
    
    result = fun.()
    
    end_time = System.monotonic_time()
    end_memory = :erlang.memory(:total)
    
    duration_ms = System.convert_time_unit(end_time - start_time, :native, :millisecond)
    memory_diff = end_memory - start_memory
    
    Logger.info(fn ->
      """
      Performance metrics for #{name}:
      Duration: #{duration_ms}ms
      Memory change: #{memory_diff} bytes
      """
    end)
    
    result
  end
  
  defmacro profile(name, do: block) do
    quote do
      Prismatic.Performance.measure(unquote(name), fn ->
        unquote(block)
      end)
    end
  end
end

# Usage
Prismatic.Performance.profile "database query" do
  Repo.all(User)
end
```

---

## Memory and Process Analysis

### Memory Leak Detection

```elixir
defmodule Prismatic.MemoryAnalyzer do
  def start_monitoring(interval_ms \\ 5000) do
    spawn(fn -> monitor_loop(interval_ms) end)
  end
  
  defp monitor_loop(interval) do
    memory_info = collect_memory_info()
    store_memory_snapshot(memory_info)
    
    :timer.sleep(interval)
    monitor_loop(interval)
  end
  
  defp collect_memory_info do
    %{
      timestamp: DateTime.utc_now(),
      total: :erlang.memory(:total),
      processes: :erlang.memory(:processes),
      atoms: :erlang.memory(:atom),
      binaries: :erlang.memory(:binary),
      ets: :erlang.memory(:ets),
      process_count: :erlang.system_info(:process_count)
    }
  end
  
  def analyze_memory_trend(snapshots) do
    # Detect increasing memory usage patterns
    snapshots
    |> Enum.chunk_every(10, 1, :discard)
    |> Enum.map(fn chunk ->
      first = List.first(chunk)
      last = List.last(chunk)
      
      %{
        period: {first.timestamp, last.timestamp},
        memory_growth: last.total - first.total,
        process_growth: last.process_count - first.process_count
      }
    end)
    |> Enum.filter(& &1.memory_growth > 0)
  end
end
```

### Process Tree Analysis

```elixir
defmodule Prismatic.ProcessTree do
  def build_process_tree do
    processes = Process.list()
    
    processes
    |> Enum.reduce(%{}, fn pid, acc ->
      case Process.info(pid, [:initial_call, :links, :memory]) do
        nil -> acc
        info ->
          Map.put(acc, pid, %{
            initial_call: info[:initial_call],
            links: info[:links],
            memory: info[:memory]
          })
      end
    end)
  end
  
  def find_memory_hogs(limit \\ 10) do
    Process.list()
    |> Enum.map(fn pid ->
      case Process.info(pid, [:memory, :initial_call, :message_queue_len]) do
        nil -> nil
        info -> {pid, info}
      end
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.sort_by(fn {_pid, info} -> info[:memory] end, :desc)
    |> Enum.take(limit)
  end
  
  def analyze_message_queues do
    Process.list()
    |> Enum.map(fn pid ->
      case Process.info(pid, [:message_queue_len, :initial_call]) do
        nil -> nil
        info when info[:message_queue_len] > 100 -> {pid, info}
        _ -> nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end
end
```

---

## Production Debugging

### Remote Node Connection

```bash
# Connect to production node
iex --name debug@hostname --cookie production_cookie

# In IEx, connect to production
Node.connect(:"production@prod-server")

# Execute commands on remote node
Node.spawn(:"production@prod-server", fn ->
  # Your debugging code here
end)
```

### Safe Production Debugging

```elixir
defmodule Prismatic.ProductionDebug do
  @moduledoc """
  Safe debugging utilities for production environment.
  All operations are designed to have minimal performance impact.
  """
  
  def safe_inspect_process(pid, timeout \\ 1000) do
    try do
      case Process.info(pid, [:memory, :message_queue_len, :current_function]) do
        nil -> {:error, :process_not_found}
        info -> {:ok, info}
      end
    catch
      _, error -> {:error, error}
    after
      :timer.sleep(0)  # Yield to scheduler
    end
  end
  
  def system_health_check do
    try do
      memory = :erlang.memory()
      
      health = %{
        status: determine_health_status(memory),
        memory_total_mb: memory[:total] |> div(1024 * 1024),
        process_count: :erlang.system_info(:process_count),
        process_limit: :erlang.system_info(:process_limit),
        atom_count: :erlang.system_info(:atom_count),
        atom_limit: :erlang.system_info(:atom_limit),
        uptime_ms: :erlang.statistics(:wall_clock) |> elem(0)
      }
      
      {:ok, health}
    catch
      _, error -> {:error, error}
    end
  end
  
  defp determine_health_status(memory) do
    total_mb = memory[:total] |> div(1024 * 1024)
    process_count = :erlang.system_info(:process_count)
    process_limit = :erlang.system_info(:process_limit)
    
    cond do
      total_mb > 1000 -> :warning_high_memory
      process_count / process_limit > 0.8 -> :warning_high_processes
      true -> :healthy
    end
  end
end
```

---

## Custom Debugging Tools

### Debug Information Collector

```elixir
defmodule Prismatic.DebugCollector do
  @moduledoc "Collects comprehensive debug information"
  
  def collect_all_info do
    %{
      system: collect_system_info(),
      processes: collect_process_info(),
      memory: collect_memory_info(),
      database: collect_database_info(),
      application: collect_application_info(),
      network: collect_network_info(),
      logs: collect_recent_logs()
    }
  end
  
  defp collect_system_info do
    %{
      node: Node.self(),
      otp_release: :erlang.system_info(:otp_release),
      elixir_version: System.version(),
      schedulers: :erlang.system_info(:schedulers),
      uptime_ms: :erlang.statistics(:wall_clock) |> elem(0),
      load_average: :cpu_sup.avg1() / 256
    }
  end
  
  defp collect_process_info do
    processes = Process.list()
    
    %{
      total_count: length(processes),
      limit: :erlang.system_info(:process_limit),
      top_memory: top_processes_by_memory(10),
      large_queues: processes_with_large_queues()
    }
  end
  
  defp collect_database_info do
    try do
      case Ecto.Adapters.SQL.query(Repo, "SELECT 1", []) do
        {:ok, _} -> 
          %{
            status: :connected,
            pool_size: Application.get_env(:prismatic, Prismatic.Repo)[:pool_size],
            active_connections: count_active_connections()
          }
        {:error, error} -> 
          %{status: :error, error: inspect(error)}
      end
    catch
      _, error -> %{status: :error, error: inspect(error)}
    end
  end
  
  def export_debug_info(filename \\ nil) do
    filename = filename || "debug_info_#{DateTime.utc_now() |> DateTime.to_unix()}.json"
    info = collect_all_info()
    
    case Jason.encode(info, pretty: true) do
      {:ok, json} ->
        File.write!(filename, json)
        {:ok, filename}
      {:error, error} ->
        {:error, error}
    end
  end
end
```

### Interactive Debug Console

```elixir
defmodule Prismatic.DebugConsole do
  def start do
    IO.puts("""
    === Prismatic Debug Console ===
    Available commands:
      h - Help
      s - System info
      p - Process info
      m - Memory info
      d - Database status
      l - Recent logs
      q - Quit
    """)
    
    console_loop()
  end
  
  defp console_loop do
    case IO.gets("debug> ") |> String.trim() do
      "h" -> show_help()
      "s" -> show_system_info()
      "p" -> show_process_info()
      "m" -> show_memory_info()
      "d" -> show_database_status()
      "l" -> show_recent_logs()
      "q" -> IO.puts("Goodbye!")
      cmd -> IO.puts("Unknown command: #{cmd}. Type 'h' for help.")
    end
    
    unless String.trim(IO.gets("debug> ")) == "q" do
      console_loop()
    end
  end
  
  defp show_system_info do
    info = Prismatic.DebugCollector.collect_system_info()
    IO.inspect(info, pretty: true)
  end
  
  # ... other helper functions
end
```

---

## Summary

This comprehensive guide covers the essential debugging and diagnostic tools available for the Prismatic AI Agent Framework. From interactive debugging with IEx to production monitoring with Observer, these tools provide deep insights into application behavior and performance.

### Key Takeaways

1. **Start with IEx** for interactive debugging and exploration
2. **Use Observer** for system-wide monitoring and analysis
3. **Leverage BEAM introspection** for deep system insights
4. **Monitor database performance** with query analysis tools
5. **Implement structured logging** for better troubleshooting
6. **Profile performance** to identify bottlenecks
7. **Analyze memory usage** to prevent leaks
8. **Use safe production debugging** techniques
9. **Build custom tools** for application-specific needs

### Next Steps

- Integrate these tools into your development workflow
- Set up monitoring dashboards for production
- Automate debug information collection
- Train team members on debugging techniques
- Contribute improvements back to the community

For more troubleshooting resources, see:
- [Comprehensive Troubleshooting Guide](comprehensive-troubleshooting-guide.md)
- [Error Reference Guide](error-reference-guide.md)
- [FAQ](faq.md)
