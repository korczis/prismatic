# Automated Code Generation

**End-to-end guide for AI-powered code generation workflows in the Prismatic ecosystem.**

<!-- NAV_START -->
## Navigation

**Current Location**: [Home](../../README.md) > [Guides](../README.md) > [AI/LLM](README.md) > Automated Code Generation

### Quick Links

- **📚 [Parent Directory](README.md)** - Return to AI/LLM guides
- **🏠 [Documentation Home](../../README.md)** - Main documentation index
- **🔍 [Search Documentation](../../reference/glossary.md)** - Find terms and concepts

### Related Documentation

- [Prompt Engineering Templates](prompt-engineering-templates.md) - Code generation prompts and templates
- [LLM Integration Patterns](llm-integration-patterns.md) - Technical integration patterns
- [Template-Driven Development](template-driven-development.md) - Advanced templating techniques
- [Best Practices for AI Development](best-practices.md) - Quality guidelines and standards
- [Development Workflow Integration](development-workflow-integration.md) - Daily workflow enhancement
<!-- NAV_END -->

---

## Overview

Automated code generation leverages AI to accelerate development by generating high-quality, consistent code that follows project patterns and conventions. This guide provides comprehensive workflows for integrating AI-powered code generation into daily development practices within the Prismatic ecosystem.

### Key Benefits

- **🚀 Accelerated Development** - Generate boilerplate code, modules, and functions rapidly
- **📏 Consistency** - Ensure consistent code patterns and conventions across the project
- **🔍 Best Practices** - Automatically incorporate coding standards and architectural patterns
- **🧪 Quality Assurance** - Generate code with built-in testing and validation
- **📚 Documentation** - Automatically generate comprehensive documentation

### Generation Scope

**What AI Excels At**:
- Boilerplate code and scaffolding
- Standard CRUD operations
- API endpoint implementations
- Test case generation
- Documentation creation
- Code transformations and refactoring

**What Requires Human Oversight**:
- Complex business logic
- Performance-critical algorithms
- Security-sensitive implementations
- Architectural decisions
- Domain-specific optimizations

---

## Code Generation Workflows

### 🏗️ [Basic Code Generation](#basic-code-generation)
*Simple, single-file code generation workflows*

### 🔧 [Module and Component Generation](#module-generation)
*Complete modules with dependencies and integration*

### 🌐 [API and Service Generation](#api-generation)
*REST APIs, GraphQL resolvers, and service layers*

### 🧪 [Test Generation](#test-generation)
*Comprehensive test suites and test case automation*

### 📚 [Documentation Generation](#documentation-generation)
*Automated documentation and code explanations*

### 🔄 [Refactoring and Modernization](#refactoring-automation)
*AI-assisted code improvement and modernization*

---

## Basic Code Generation

### Function Generation Workflow

**Use Case**: Generate individual functions with proper documentation and testing

```elixir
defmodule Prismatic.CodeGen.FunctionGenerator do
  @moduledoc """
  Generates Elixir functions with comprehensive documentation and examples.
  """
  
  alias Prismatic.LLM.Backend
  alias Prismatic.AI.TemplateClient
  
  @function_template """
  Generate an Elixir function with the following specification:
  
  **Function Name**: {{function_name}}
  **Module**: {{module_name}}
  **Purpose**: {{purpose}}
  **Parameters**: {{parameters}}
  **Return Type**: {{return_type}}
  **Error Conditions**: {{error_conditions}}
  
  **Requirements**:
  - Include comprehensive @spec annotation
  - Add detailed @doc with parameter descriptions
  - Include at least 2 usage examples in @doc
  - Add 2-3 doctests demonstrating functionality
  - Implement proper error handling with {:ok, result} | {:error, reason}
  - Use pattern matching where appropriate
  - Include input validation with guards
  - Add appropriate logging for important operations
  
  **Context**: This function will be part of the Prismatic project.
  Follow Elixir conventions and OTP principles.
  
  **Output Format**:
  Provide only the function implementation with documentation:
  
  ```elixir
  @doc """
  [Function documentation]
  
  ## Examples
  
      iex> ModuleName.function_name(valid_input)
      {:ok, expected_result}
  
      iex> ModuleName.function_name(invalid_input)
      {:error, :invalid_input}
  """
  @spec function_name(param_types) :: return_type
  def function_name(parameters) do
    # Implementation
  end
  ```
  """
  
  @doc """
  Generates a function based on specifications.
  
  ## Examples
  
      iex> FunctionGenerator.generate_function(%{
      ...>   function_name: "validate_email",
      ...>   module_name: "Prismatic.Utils.Validation",
      ...>   purpose: "Validate email address format",
      ...>   parameters: "email :: String.t()",
      ...>   return_type: "{:ok, String.t()} | {:error, atom()}",
      ...>   error_conditions: "Invalid format, empty string"
      ...> })
      {:ok, "@doc...\n@spec validate_email..."}
  """
  @spec generate_function(map(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def generate_function(spec, opts \\ []) do
    TemplateClient.execute_template(
      :function_generation,
      spec,
      Keyword.merge([
        provider: :openai,
        temperature: 0.3,
        max_tokens: 1500
      ], opts)
    )
  end
  
  @doc """
  Generates a function and validates the output.
  
  ## Examples
  
      iex> {:ok, code} = FunctionGenerator.generate_and_validate(spec)
      iex> String.contains?(code, "@spec")
      true
  """
  @spec generate_and_validate(map(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def generate_and_validate(spec, opts \\ []) do
    with {:ok, generated_code} <- generate_function(spec, opts),
         {:ok, validated_code} <- validate_generated_function(generated_code, spec) do
      {:ok, validated_code}
    end
  end
  
  defp validate_generated_function(code, spec) do
    validations = [
      &validate_has_spec/1,
      &validate_has_doc/1,
      &validate_has_examples/1,
      &validate_syntax/1,
      fn code -> validate_function_name(code, spec.function_name) end
    ]
    
    case run_validations(code, validations) do
      :ok -> {:ok, code}
      {:error, failures} -> {:error, {:validation_failed, failures}}
    end
  end
  
  defp validate_has_spec(code) do
    if String.contains?(code, "@spec") do
      :ok
    else
      {:error, :missing_spec}
    end
  end
  
  defp validate_has_doc(code) do
    if String.contains?(code, "@doc") do
      :ok
    else
      {:error, :missing_doc}
    end
  end
  
  defp validate_has_examples(code) do
    if String.contains?(code, "## Examples") do
      :ok
    else
      {:error, :missing_examples}
    end
  end
  
  defp validate_syntax(code) do
    try do
      Code.string_to_quoted!(code)
      :ok
    rescue
      _ -> {:error, :invalid_syntax}
    end
  end
  
  defp validate_function_name(code, expected_name) do
    if String.contains?(code, "def #{expected_name}") do
      :ok
    else
      {:error, {:wrong_function_name, expected_name}}
    end
  end
  
  defp run_validations(code, validations) do
    failures = 
      validations
      |> Enum.map(& &1.(code))
      |> Enum.filter(&match?({:error, _}, &1))
      |> Enum.map(fn {:error, reason} -> reason end)
    
    case failures do
      [] -> :ok
      failures -> {:error, failures}
    end
  end
end
```

### Utility Module Generation

**Use Case**: Generate complete utility modules with multiple related functions

```elixir
defmodule Prismatic.CodeGen.ModuleGenerator do
  @moduledoc """
  Generates complete Elixir modules with multiple functions and proper structure.
  """
  
  alias Prismatic.AI.TemplateClient
  
  @module_template """
  Generate a complete Elixir module for the Prismatic project:
  
  **Module Name**: {{module_name}}
  **Purpose**: {{purpose}}
  **Domain**: {{domain}}
  **Functions**: {{functions}}
  
  **Module Requirements**:
  - Comprehensive @moduledoc with purpose, usage, and examples
  - Follow Prismatic naming conventions (Prismatic.Domain.ModuleName)
  - Include all necessary type definitions with @typedoc
  - Add proper supervision if it's a GenServer/Agent
  - Include configuration handling if needed
  - Add telemetry events for monitoring
  
  **Function Requirements** (for each function):
  - Detailed @doc with examples
  - Proper @spec annotations
  - Input validation and error handling
  - Consistent return patterns {:ok, result} | {:error, reason}
  - Appropriate logging
  - Doctests for examples
  
  **Code Quality Standards**:
  - Use pattern matching over conditionals
  - Implement with statements for complex operations
  - Include private helper functions where appropriate
  - Add guards for input validation
  - Follow functional programming principles
  
  **Integration Requirements**:
  - Integrate with existing Prismatic patterns
  - Include appropriate error types from the domain
  - Add any necessary dependencies to the module
  - Include configuration for external services if needed
  
  Provide the complete module implementation.
  """
  
  @doc """
  Generates a complete module with multiple functions.
  
  ## Examples
  
      iex> ModuleGenerator.generate_module(%{
      ...>   module_name: "Prismatic.Utils.DateHelper",
      ...>   purpose: "Date and time utility functions",
      ...>   domain: "Utils",
      ...>   functions: [
      ...>     "format_date/2 - Format date with timezone",
      ...>     "parse_iso_date/1 - Parse ISO date string",
      ...>     "days_between/2 - Calculate days between dates"
      ...>   ]
      ...> })
      {:ok, "defmodule Prismatic.Utils.DateHelper do..."}
  """
  @spec generate_module(map(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def generate_module(spec, opts \\ []) do
    # Convert functions list to string if it's a list
    formatted_spec = %{
      spec |
      functions: format_functions_list(spec.functions)
    }
    
    with {:ok, module_code} <- TemplateClient.execute_template(
           :module_generation,
           formatted_spec,
           Keyword.merge([
             provider: :openai,
             temperature: 0.2,  # Lower temperature for more consistent structure
             max_tokens: 3000
           ], opts)
         ),
         {:ok, validated_code} <- validate_module_structure(module_code, spec) do
      {:ok, validated_code}
    end
  end
  
  @doc """
  Generates a module with comprehensive testing.
  
  ## Examples
  
      iex> {:ok, {module_code, test_code}} = ModuleGenerator.generate_with_tests(spec)
      iex> String.contains?(module_code, "defmodule")
      true
      iex> String.contains?(test_code, "defmodule") and String.contains?(test_code, "Test")
      true
  """
  @spec generate_with_tests(map(), keyword()) :: {:ok, {String.t(), String.t()}} | {:error, term()}
  def generate_with_tests(spec, opts \\ []) do
    with {:ok, module_code} <- generate_module(spec, opts),
         {:ok, test_code} <- generate_module_tests(module_code, spec, opts) do
      {:ok, {module_code, test_code}}
    end
  end
  
  defp format_functions_list(functions) when is_list(functions) do
    functions
    |> Enum.with_index(1)
    |> Enum.map(fn {func, idx} -> "#{idx}. #{func}" end)
    |> Enum.join("\n")
  end
  
  defp format_functions_list(functions) when is_binary(functions), do: functions
  
  defp validate_module_structure(code, spec) do
    validations = [
      &validate_module_declaration/1,
      &validate_moduledoc/1,
      &validate_function_specs/1,
      fn code -> validate_module_name(code, spec.module_name) end
    ]
    
    case run_validations(code, validations) do
      :ok -> {:ok, code}
      {:error, failures} -> {:error, {:validation_failed, failures}}
    end
  end
  
  defp validate_module_declaration(code) do
    if String.contains?(code, "defmodule") do
      :ok
    else
      {:error, :missing_module_declaration}
    end
  end
  
  defp validate_moduledoc(code) do
    if String.contains?(code, "@moduledoc") do
      :ok
    else
      {:error, :missing_moduledoc}
    end
  end
  
  defp validate_function_specs(code) do
    if String.contains?(code, "@spec") do
      :ok
    else
      {:error, :missing_function_specs}
    end
  end
  
  defp validate_module_name(code, expected_name) do
    if String.contains?(code, "defmodule #{expected_name}") do
      :ok
    else
      {:error, {:wrong_module_name, expected_name}}
    end
  end
  
  defp generate_module_tests(module_code, spec, opts) do
    test_spec = %{
      module_name: spec.module_name,
      module_code: module_code,
      test_types: ["unit_tests", "integration_tests", "property_tests"]
    }
    
    TemplateClient.execute_template(
      :test_generation,
      test_spec,
      Keyword.merge([
        provider: :openai,
        temperature: 0.3,
        max_tokens: 2500
      ], opts)
    )
  end
  
  defp run_validations(code, validations) do
    failures = 
      validations
      |> Enum.map(& &1.(code))
      |> Enum.filter(&match?({:error, _}, &1))
      |> Enum.map(fn {:error, reason} -> reason end)
    
    case failures do
      [] -> :ok
      failures -> {:error, failures}
    end
  end
end
```

---

## Module Generation

### GenServer Generation

**Use Case**: Generate complete GenServer implementations with OTP compliance

```elixir
defmodule Prismatic.CodeGen.GenServerGenerator do
  @moduledoc """
  Generates production-ready GenServer modules with comprehensive OTP patterns.
  """
  
  alias Prismatic.AI.TemplateClient
  
  @genserver_template """
  Generate a complete GenServer module for the Prismatic project:
  
  **Module Name**: {{module_name}}
  **Purpose**: {{purpose}}
  **State Structure**: {{state_structure}}
  **Public API**: {{public_api}}
  
  **GenServer Requirements**:
  - Complete GenServer implementation with `use GenServer`
  - start_link/1 function with proper options handling
  - init/1 callback with comprehensive state initialization
  - Public API functions using GenServer.call/cast appropriately
  - All required callbacks: handle_call, handle_cast, handle_info
  - terminate/2 for graceful shutdown
  - handle_continue/2 for heavy initialization work
  - code_change/3 for hot code upgrades
  
  **OTP Patterns**:
  - Use GenServer.call for synchronous operations
  - Use GenServer.cast for asynchronous operations
  - Implement proper timeout handling (5000ms default)
  - Include process monitoring where appropriate
  - Add supervision tree integration
  - Handle EXIT messages appropriately
  
  **Prismatic Integration**:
  - Include telemetry events for state changes
  - Follow Prismatic error handling patterns
  - Add health check functionality via handle_call
  - Include metrics collection points
  - Use structured logging with metadata
  
  **Quality Standards**:
  - Comprehensive @moduledoc with architecture explanation
  - @spec for all public functions
  - @doc for all public functions with examples
  - Input validation in all API functions
  - Proper error handling and logging
  - State validation in callbacks
  
  **Child Spec**:
  - Include child_spec/1 function for supervision
  - Proper restart strategy configuration
  - Shutdown timeout configuration
  
  Provide the complete GenServer implementation.
  """
  
  @doc """
  Generates a complete GenServer with OTP compliance.
  
  ## Examples
  
      iex> GenServerGenerator.generate_genserver(%{
      ...>   module_name: "Prismatic.Cache.Manager",
      ...>   purpose: "Manages application-wide caching with TTL support",
      ...>   state_structure: "%{cache: %{}, ttls: %{}, cleanup_timer: nil}",
      ...>   public_api: [
      ...>     "get(key) - Retrieve cached value",
      ...>     "put(key, value, ttl) - Store value with TTL",
      ...>     "delete(key) - Remove cached value",
      ...>     "clear() - Clear all cached values"
      ...>   ]
      ...> })
      {:ok, "defmodule Prismatic.Cache.Manager do..."}
  """
  @spec generate_genserver(map(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def generate_genserver(spec, opts \\ []) do
    formatted_spec = %{
      spec |
      public_api: format_api_list(spec.public_api)
    }
    
    with {:ok, genserver_code} <- TemplateClient.execute_template(
           :genserver_generation,
           formatted_spec,
           Keyword.merge([
             provider: :openai,
             temperature: 0.2,
             max_tokens: 4000
           ], opts)
         ),
         {:ok, validated_code} <- validate_genserver_structure(genserver_code, spec) do
      {:ok, validated_code}
    end
  end
  
  @doc """
  Generates GenServer with supervision tree integration.
  
  ## Examples
  
      iex> {:ok, {genserver, supervisor}} = GenServerGenerator.generate_with_supervisor(spec)
      iex> String.contains?(supervisor, "Supervisor.init")
      true
  """
  @spec generate_with_supervisor(map(), keyword()) :: 
    {:ok, {String.t(), String.t()}} | {:error, term()}
  def generate_with_supervisor(spec, opts \\ []) do
    with {:ok, genserver_code} <- generate_genserver(spec, opts),
         {:ok, supervisor_code} <- generate_supervisor(spec, opts) do
      {:ok, {genserver_code, supervisor_code}}
    end
  end
  
  defp generate_supervisor(spec, opts) do
    supervisor_spec = %{
      supervisor_name: String.replace(spec.module_name, "GenServer", "Supervisor"),
      genserver_module: spec.module_name,
      purpose: "Supervises #{spec.module_name}"
    }
    
    TemplateClient.execute_template(
      :supervisor_generation,
      supervisor_spec,
      Keyword.merge([
        provider: :openai,
        temperature: 0.2,
        max_tokens: 1500
      ], opts)
    )
  end
  
  defp format_api_list(api) when is_list(api) do
    api
    |> Enum.with_index(1)
    |> Enum.map(fn {func, idx} -> "#{idx}. #{func}" end)
    |> Enum.join("\n")
  end
  
  defp format_api_list(api) when is_binary(api), do: api
  
  defp validate_genserver_structure(code, spec) do
    validations = [
      &validate_use_genserver/1,
      &validate_start_link/1,
      &validate_init_callback/1,
      &validate_handle_call/1,
      &validate_handle_cast/1,
      &validate_child_spec/1
    ]
    
    case run_validations(code, validations) do
      :ok -> {:ok, code}
      {:error, failures} -> {:error, {:validation_failed, failures}}
    end
  end
  
  defp validate_use_genserver(code) do
    if String.contains?(code, "use GenServer") do
      :ok
    else
      {:error, :missing_use_genserver}
    end
  end
  
  defp validate_start_link(code) do
    if String.contains?(code, "def start_link") do
      :ok
    else
      {:error, :missing_start_link}
    end
  end
  
  defp validate_init_callback(code) do
    if String.contains?(code, "def init") do
      :ok
    else
      {:error, :missing_init_callback}
    end
  end
  
  defp validate_handle_call(code) do
    if String.contains?(code, "def handle_call") do
      :ok
    else
      {:error, :missing_handle_call}
    end
  end
  
  defp validate_handle_cast(code) do
    if String.contains?(code, "def handle_cast") do
      :ok
    else
      {:error, :missing_handle_cast}
    end
  end
  
  defp validate_child_spec(code) do
    if String.contains?(code, "def child_spec") do
      :ok
    else
      {:error, :missing_child_spec}
    end
  end
  
  defp run_validations(code, validations) do
    failures = 
      validations
      |> Enum.map(& &1.(code))
      |> Enum.filter(&match?({:error, _}, &1))
      |> Enum.map(fn {:error, reason} -> reason end)
    
    case failures do
      [] -> :ok
      failures -> {:error, failures}
    end
  end
end
```

---

## API Generation

### Phoenix Controller Generation

**Use Case**: Generate RESTful API controllers with comprehensive error handling

```elixir
defmodule Prismatic.CodeGen.ControllerGenerator do
  @moduledoc """
  Generates Phoenix controllers with RESTful endpoints and proper error handling.
  """
  
  alias Prismatic.AI.TemplateClient
  
  @controller_template """
  Generate a Phoenix controller for the Prismatic project:
  
  **Controller Name**: {{controller_name}}
  **Resource**: {{resource_name}}
  **Schema Module**: {{schema_module}}
  **Actions**: {{actions}}
  
  **Controller Requirements**:
  - Follow Phoenix conventions and RESTful patterns
  - Include comprehensive error handling
  - Add proper parameter validation
  - Implement pagination for index actions
  - Include authorization checks
  - Add request/response logging
  - Follow JSON API or custom response format
  
  **Standard Actions** (if specified):
  - index/2 - List resources with pagination and filtering
  - show/2 - Get single resource by ID
  - create/2 - Create new resource with validation
  - update/2 - Update existing resource
  - delete/2 - Delete resource
  
  **Error Handling**:
  - Handle validation errors with detailed messages
  - Return appropriate HTTP status codes
  - Include error context and metadata
  - Log errors with request correlation IDs
  - Handle not found, unauthorized, and forbidden cases
  
  **Response Format**:
  - Consistent JSON response structure
  - Include metadata for pagination
  - Add request timing and correlation IDs
  - Follow Prismatic API conventions
  
  **Security**:
  - Input sanitization and validation
  - Authorization checks for each action
  - Rate limiting considerations
  - CSRF protection where applicable
  
  **Integration**:
  - Use existing Prismatic context modules
  - Include telemetry events
  - Add OpenAPI/Swagger documentation comments
  - Follow existing authentication patterns
  
  Provide the complete controller implementation.
  """
  
  @doc """
  Generates a RESTful Phoenix controller.
  
  ## Examples
  
      iex> ControllerGenerator.generate_controller(%{
      ...>   controller_name: "Prismatic.Web.UserController",
      ...>   resource_name: "user",
      ...>   schema_module: "Prismatic.Accounts.User",
      ...>   actions: ["index", "show", "create", "update", "delete"]
      ...> })
      {:ok, "defmodule Prismatic.Web.UserController do..."}
  """
  @spec generate_controller(map(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def generate_controller(spec, opts \\ []) do
    formatted_spec = %{
      spec |
      actions: format_actions_list(spec.actions)
    }
    
    with {:ok, controller_code} <- TemplateClient.execute_template(
           :controller_generation,
           formatted_spec,
           Keyword.merge([
             provider: :openai,
             temperature: 0.2,
             max_tokens: 3500
           ], opts)
         ),
         {:ok, validated_code} <- validate_controller_structure(controller_code, spec) do
      {:ok, validated_code}
    end
  end
  
  @doc """
  Generates controller with comprehensive test suite.
  
  ## Examples
  
      iex> {:ok, {controller, tests}} = ControllerGenerator.generate_with_tests(spec)
      iex> String.contains?(tests, "ConnCase")
      true
  """
  @spec generate_with_tests(map(), keyword()) :: 
    {:ok, {String.t(), String.t()}} | {:error, term()}
  def generate_with_tests(spec, opts \\ []) do
    with {:ok, controller_code} <- generate_controller(spec, opts),
         {:ok, test_code} <- generate_controller_tests(controller_code, spec, opts) do
      {:ok, {controller_code, test_code}}
    end
  end
  
  @doc """
  Generates OpenAPI documentation for the controller.
  
  ## Examples
  
      iex> {:ok, openapi_spec} = ControllerGenerator.generate_openapi_spec(spec)
      iex> String.contains?(openapi_spec, "paths:")
      true
  """
  @spec generate_openapi_spec(map(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def generate_openapi_spec(spec, opts \\ []) do
    openapi_spec = %{
      controller_name: spec.controller_name,
      resource_name: spec.resource_name,
      actions: spec.actions,
      schema_module: spec.schema_module
    }
    
    TemplateClient.execute_template(
      :openapi_generation,
      openapi_spec,
      Keyword.merge([
        provider: :anthropic,  # Anthropic often better for documentation
        temperature: 0.3,
        max_tokens: 2000
      ], opts)
    )
  end
  
  defp format_actions_list(actions) when is_list(actions) do
    Enum.join(actions, ", ")
  end
  
  defp format_actions_list(actions) when is_binary(actions), do: actions
  
  defp generate_controller_tests(controller_code, spec, opts) do
    test_spec = %{
      controller_module: spec.controller_name,
      resource_name: spec.resource_name,
      actions: spec.actions,
      schema_module: spec.schema_module
    }
    
    TemplateClient.execute_template(
      :controller_test_generation,
      test_spec,
      Keyword.merge([
        provider: :openai,
        temperature: 0.3,
        max_tokens: 3000
      ], opts)
    )
  end
  
  defp validate_controller_structure(code, spec) do
    validations = [
      &validate_phoenix_controller/1,
      &validate_action_functions/1,
      &validate_error_handling/1,
      fn code -> validate_controller_name(code, spec.controller_name) end
    ]
    
    case run_validations(code, validations) do
      :ok -> {:ok, code}
      {:error, failures} -> {:error, {:validation_failed, failures}}
    end
  end
  
  defp validate_phoenix_controller(code) do
    if String.contains?(code, "use Prismatic.Web, :controller") or 
       String.contains?(code, "use Phoenix.Controller") do
      :ok
    else
      {:error, :missing_phoenix_controller}
    end
  end
  
  defp validate_action_functions(code) do
    if String.contains?(code, "def index") or String.contains?(code, "def show") do
      :ok
    else
      {:error, :missing_action_functions}
    end
  end
  
  defp validate_error_handling(code) do
    if String.contains?(code, "handle_errors") or String.contains?(code, "rescue") do
      :ok
    else
      {:error, :missing_error_handling}
    end
  end
  
  defp validate_controller_name(code, expected_name) do
    if String.contains?(code, "defmodule #{expected_name}") do
      :ok
    else
      {:error, {:wrong_controller_name, expected_name}}
    end
  end
  
  defp run_validations(code, validations) do
    failures = 
      validations
      |> Enum.map(& &1.(code))
      |> Enum.filter(&match?({:error, _}, &1))
      |> Enum.map(fn {:error, reason} -> reason end)
    
    case failures do
      [] -> :ok
      failures -> {:error, failures}
    end
  end
end
```

---

## Test Generation

### Comprehensive Test Suite Generation

**Use Case**: Generate complete test suites with unit, integration, and property tests

```elixir
defmodule Prismatic.CodeGen.TestGenerator do
  @moduledoc """
  Generates comprehensive test suites for Elixir modules.
  """
  
  alias Prismatic.AI.TemplateClient
  
  @test_template """
  Generate a comprehensive ExUnit test suite for the following module:
  
  **Module Code**:
  ```elixir
  {{module_code}}
  ```
  
  **Module Name**: {{module_name}}
  **Test Types**: {{test_types}}
  
  **Test Suite Requirements**:
  - Complete ExUnit test module with proper setup
  - use ExUnit.Case with appropriate async setting
  - doctest for all documented functions
  - Comprehensive test coverage for all public functions
  - Test all code paths and edge cases
  - Include negative test cases for error conditions
  
  **Test Categories**:
  1. **Unit Tests**: Test individual functions in isolation
  2. **Integration Tests**: Test module interactions
  3. **Property Tests**: Use StreamData for property-based testing
  4. **Performance Tests**: Basic performance validation
  
  **Test Structure**:
  - Group tests by function using describe blocks
  - Clear test names describing the scenario
  - Arrange/Act/Assert pattern
  - Proper setup and cleanup
  - Mock external dependencies
  
  **ExUnit Features**:
  - Use setup/setup_all for test preparation
  - Include tags for categorizing tests
  - Use ExUnit.CaptureLog for testing log output
  - Include async: true where appropriate
  
  **Property-Based Testing**:
  - Use StreamData generators for input data
  - Test function properties and invariants
  - Include shrinking for better error reporting
  - Focus on edge cases and boundary conditions
  
  **Mocking and Fixtures**:
  - Mock external HTTP calls and database operations
  - Use test fixtures for consistent test data
  - Include factory functions for creating test data
  - Mock GenServer calls where appropriate
  
  **Performance Testing**:
  - Basic timing assertions for critical functions
  - Memory usage validation
  - Concurrency testing where applicable
  
  Provide the complete test module implementation.
  """
  
  @doc """
  Generates a comprehensive test suite for a module.
  
  ## Examples
  
      iex> TestGenerator.generate_tests(%{
      ...>   module_code: "defmodule Example do...",
      ...>   module_name: "Example",
      ...>   test_types: ["unit", "integration", "property"]
      ...> })
      {:ok, "defmodule ExampleTest do..."}
  """
  @spec generate_tests(map(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def generate_tests(spec, opts \\ []) do
    formatted_spec = %{
      spec |
      test_types: format_test_types(spec[:test_types] || ["unit", "integration"])
    }
    
    with {:ok, test_code} <- TemplateClient.execute_template(
           :test_generation,
           formatted_spec,
           Keyword.merge([
             provider: :openai,
             temperature: 0.3,
             max_tokens: 3500
           ], opts)
         ),
         {:ok, validated_code} <- validate_test_structure(test_code, spec) do
      {:ok, validated_code}
    end
  end
  
  @doc """
  Generates property-based tests using StreamData.
  
  ## Examples
  
      iex> TestGenerator.generate_property_tests(module_code, function_specs)
      {:ok, "property \"function maintains invariant\" do..."}
  """
  @spec generate_property_tests(String.t(), [map()], keyword()) :: 
    {:ok, String.t()} | {:error, term()}
  def generate_property_tests(module_code, function_specs, opts \\ []) do
    property_spec = %{
      module_code: module_code,
      functions: format_function_specs(function_specs)
    }
    
    TemplateClient.execute_template(
      :property_test_generation,
      property_spec,
      Keyword.merge([
        provider: :anthropic,  # Often better for complex property reasoning
        temperature: 0.4,
        max_tokens: 2500
      ], opts)
    )
  end
  
  @doc """
  Generates performance benchmarks for functions.
  
  ## Examples
  
      iex> TestGenerator.generate_benchmarks(module_code, critical_functions)
      {:ok, "Benchee.run(%{\"function_name\" => fn -> ..."}
  """
  @spec generate_benchmarks(String.t(), [String.t()], keyword()) :: 
    {:ok, String.t()} | {:error, term()}
  def generate_benchmarks(module_code, critical_functions, opts \\ []) do
    benchmark_spec = %{
      module_code: module_code,
      functions: Enum.join(critical_functions, ", ")
    }
    
    TemplateClient.execute_template(
      :benchmark_generation,
      benchmark_spec,
      Keyword.merge([
        provider: :openai,
        temperature: 0.2,
        max_tokens: 2000
      ], opts)
    )
  end
  
  defp format_test_types(types) when is_list(types) do
    Enum.join(types, ", ")
  end
  
  defp format_test_types(types) when is_binary(types), do: types
  
  defp format_function_specs(specs) when is_list(specs) do
    specs
    |> Enum.map(fn spec ->
      "#{spec.name}/#{spec.arity} - #{spec.description}"
    end)
    |> Enum.join("\n")
  end
  
  defp validate_test_structure(code, _spec) do
    validations = [
      &validate_exunit_case/1,
      &validate_test_functions/1,
      &validate_describe_blocks/1,
      &validate_doctests/1
    ]
    
    case run_validations(code, validations) do
      :ok -> {:ok, code}
      {:error, failures} -> {:error, {:validation_failed, failures}}
    end
  end
  
  defp validate_exunit_case(code) do
    if String.contains?(code, "use ExUnit.Case") do
      :ok
    else
      {:error, :missing_exunit_case}
    end
  end
  
  defp validate_test_functions(code) do
    if String.contains?(code, "test \"") do
      :ok
    else
      {:error, :missing_test_functions}
    end
  end
  
  defp validate_describe_blocks(code) do
    if String.contains?(code, "describe \"") do
      :ok
    else
      {:error, :missing_describe_blocks}
    end
  end
  
  defp validate_doctests(code) do
    if String.contains?(code, "doctest") do
      :ok
    else
      {:error, :missing_doctests}
    end
  end
  
  defp run_validations(code, validations) do
    failures = 
      validations
      |> Enum.map(& &1.(code))
      |> Enum.filter(&match?({:error, _}, &1))
      |> Enum.map(fn {:error, reason} -> reason end)
    
    case failures do
      [] -> :ok
      failures -> {:error, failures}
    end
  end
end
```

---

## Documentation Generation

### Automated Documentation Creation

**Use Case**: Generate comprehensive documentation for existing code

```elixir
defmodule Prismatic.CodeGen.DocumentationGenerator do
  @moduledoc """
  Generates comprehensive documentation for Elixir modules and functions.
  """
  
  alias Prismatic.AI.TemplateClient
  
  @doc """
  Generates complete module documentation.
  
  ## Examples
  
      iex> DocumentationGenerator.generate_module_docs(module_code)
      {:ok, "@moduledoc \"\"\"\nComprehensive module for...\"\"\""}
  """
  @spec generate_module_docs(String.t(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def generate_module_docs(module_code, opts \\ []) do
    doc_spec = %{
      module_code: module_code,
      include_examples: Keyword.get(opts, :include_examples, true),
      include_architecture: Keyword.get(opts, :include_architecture, true)
    }
    
    TemplateClient.execute_template(
      :module_documentation,
      doc_spec,
      Keyword.merge([
        provider: :anthropic,  # Often better for documentation
        temperature: 0.4,
        max_tokens: 3000
      ], opts)
    )
  end
  
  @doc """
  Generates API reference documentation.
  
  ## Examples
  
      iex> DocumentationGenerator.generate_api_docs(controller_modules)
      {:ok, "# API Reference\n\n## Endpoints\n..."}
  """
  @spec generate_api_docs([String.t()], keyword()) :: {:ok, String.t()} | {:error, term()}
  def generate_api_docs(controller_modules, opts \\ []) do
    api_spec = %{
      controllers: Enum.join(controller_modules, "\n\n"),
      format: Keyword.get(opts, :format, "markdown")
    }
    
    TemplateClient.execute_template(
      :api_documentation,
      api_spec,
      Keyword.merge([
        provider: :anthropic,
        temperature: 0.3,
        max_tokens: 4000
      ], opts)
    )
  end
end
```

---

## Refactoring Automation

### AI-Assisted Code Improvement

**Use Case**: Automate code refactoring and modernization

```elixir
defmodule Prismatic.CodeGen.RefactoringEngine do
  @moduledoc """
  AI-powered code refactoring and improvement engine.
  """
  
  alias Prismatic.AI.TemplateClient
  
  @doc """
  Refactors code to improve quality and maintainability.
  
  ## Examples
  
      iex> RefactoringEngine.refactor_code(legacy_code, [:performance, :readability])
      {:ok, {improved_code, change_summary}}
  """
  @spec refactor_code(String.t(), [atom()], keyword()) :: 
    {:ok, {String.t(), String.t()}} | {:error, term()}
  def refactor_code(code, improvements, opts \\ []) do
    refactor_spec = %{
      original_code: code,
      improvements: Enum.join(improvements, ", "),
      preserve_api: Keyword.get(opts, :preserve_api, true)
    }
    
    with {:ok, refactored_result} <- TemplateClient.execute_template(
           :code_refactoring,
           refactor_spec,
           Keyword.merge([
             provider: :openai,
             temperature: 0.2,
             max_tokens: 3500
           ], opts)
         ) do
      parse_refactoring_result(refactored_result)
    end
  end
  
  defp parse_refactoring_result(result) do
    # Parse the AI response to extract code and summary
    # This would need more sophisticated parsing in practice
    case String.split(result, "CHANGE_SUMMARY:", parts: 2) do
      [code, summary] -> {:ok, {String.trim(code), String.trim(summary)}}
      [code] -> {:ok, {String.trim(code), "No summary provided"}}
    end
  end
end
```

---

## Integration Workflow

### Complete Code Generation Pipeline

**Use Case**: End-to-end workflow for generating, validating, and integrating new code

```elixir
defmodule Prismatic.CodeGen.Pipeline do
  @moduledoc """
  Complete code generation pipeline with validation and integration.
  """
  
  alias Prismatic.CodeGen.{
    ModuleGenerator,
    TestGenerator,
    DocumentationGenerator
  }
  
  @doc """
  Executes complete code generation pipeline.
  
  ## Examples
  
      iex> Pipeline.generate_complete_feature(feature_spec)
      {:ok, %{
        module_code: "defmodule...",
        test_code: "defmodule...Test...",
        documentation: "# Feature Documentation..."
      }}
  """
  @spec generate_complete_feature(map(), keyword()) :: {:ok, map()} | {:error, term()}
  def generate_complete_feature(spec, opts \\ []) do
    with {:ok, module_code} <- ModuleGenerator.generate_module(spec, opts),
         {:ok, test_code} <- TestGenerator.generate_tests(
           %{module_code: module_code, module_name: spec.module_name}, opts
         ),
         {:ok, documentation} <- DocumentationGenerator.generate_module_docs(
           module_code, opts
         ) do
      
      result = %{
        module_code: module_code,
        test_code: test_code,
        documentation: documentation,
        integration_notes: generate_integration_notes(spec)
      }
      
      {:ok, result}
    end
  end
  
  defp generate_integration_notes(spec) do
    """
    Integration Notes for #{spec.module_name}:
    
    1. Add module to supervision tree if it's a GenServer
    2. Update application configuration if needed
    3. Add to router if it's a controller
    4. Run tests: mix test
    5. Update documentation: mix docs
    6. Check formatting: mix format
    """
  end
end
```

---

## Quality Assurance

### Automated Code Validation

**Validation Checklist**:
1. **Syntax Validation** - Ensure generated code compiles
2. **Convention Compliance** - Follow Elixir and project conventions
3. **Documentation Quality** - Comprehensive docs with examples
4. **Test Coverage** - Adequate test coverage for all functions
5. **Performance Considerations** - No obvious performance issues
6. **Security Review** - No apparent security vulnerabilities

### Integration Testing

```elixir
# Run generated code through validation pipeline
mix format --check-formatted
mix compile --warnings-as-errors
mix credo --strict
mix test
mix dialyzer
```

---

## Best Practices

### Code Generation Guidelines

1. **Start Simple**: Begin with basic function generation before complex modules
2. **Validate Everything**: Always validate generated code before integration
3. **Iterative Improvement**: Refine prompts based on output quality
4. **Human Review**: Always review generated code before production use
5. **Test Thoroughly**: Generate comprehensive tests alongside code

### Template Management

1. **Version Control**: Keep prompt templates in version control
2. **Template Testing**: Test templates with various inputs
3. **Documentation**: Document template usage and expected outputs
4. **Continuous Improvement**: Regularly update templates based on results

### Performance Optimization

1. **Batch Generation**: Generate related code together
2. **Caching**: Cache responses for similar requests
3. **Provider Selection**: Choose optimal provider for each task type
4. **Parallel Processing**: Generate independent components in parallel

---

## Related Documentation

- [Prompt Engineering Templates](prompt-engineering-templates.md) - Detailed prompt templates
- [LLM Integration Patterns](llm-integration-patterns.md) - Integration patterns and workflows
- [Template-Driven Development](template-driven-development.md) - Advanced templating techniques
- [Best Practices for AI Development](best-practices.md) - Quality guidelines and standards
- [Development Workflow Integration](development-workflow-integration.md) - Daily workflow integration

---

**🚀 Generation Tip**: Start with simple function generation to build confidence and understanding. Gradually move to more complex module generation as you refine your prompts and validation processes. Always prioritize code quality and maintainability over generation speed.