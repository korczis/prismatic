# Prompt Engineering Templates

**Comprehensive prompt templates and engineering best practices for AI-assisted development in the Prismatic ecosystem.**

<!-- NAV_START -->
## Navigation

**Current Location**: [Home](../../README.md) > [Guides](../README.md) > [AI/LLM](README.md) > Prompt Engineering Templates

### Quick Links

- **📚 [Parent Directory](README.md)** - Return to AI/LLM guides
- **🏠 [Documentation Home](../../README.md)** - Main documentation index
- **🔍 [Search Documentation](../../reference/glossary.md)** - Find terms and concepts

### Related Documentation

- [LLM Integration Patterns](llm-integration-patterns.md) - Technical integration with Prismatic's LLM backend
- [Best Practices for AI Development](best-practices.md) - Core principles and guidelines
- [Automated Code Generation](automated-code-generation.md) - End-to-end automation workflows
- [LLM Backend Implementation](../../../lib/prismatic/llm/backend.ex) - Core LLM system
<!-- NAV_END -->

---

## Overview

Effective prompt engineering is the foundation of successful AI-assisted development. This guide provides battle-tested prompt templates specifically designed for software development tasks, optimized for use with Prismatic's LLM backend supporting OpenAI and Anthropic models.

### Key Principles

- **Context-Rich Prompts** - Include sufficient context for accurate responses
- **Structured Output** - Request specific formats that integrate well with development workflows
- **Iterative Refinement** - Templates designed for progressive enhancement
- **Provider Agnostic** - Work effectively across different LLM providers
- **Validation Ready** - Include verification steps and quality checks

---

## Template Categories

### 🏗️ [Code Generation Templates](#code-generation-templates)
*Generate new code, functions, and modules*

### 🔧 [Code Analysis and Review Templates](#code-analysis-templates)
*Analyze existing code for quality, security, and improvements*

### 🔄 [Refactoring Templates](#refactoring-templates)
*Improve and modernize existing code*

### 📚 [Documentation Templates](#documentation-templates)
*Generate and maintain comprehensive documentation*

### 🧪 [Testing Templates](#testing-templates)
*Create comprehensive test suites and test cases*

### 🐛 [Debugging Templates](#debugging-templates)
*Identify and resolve issues in code*

### 🎯 [Architecture and Design Templates](#architecture-templates)
*Design systems and make architectural decisions*

---

## Code Generation Templates

### Template: Elixir Module Generation

**Use Case**: Generate new Elixir modules following Prismatic conventions

```elixir
# Prismatic LLM Backend Usage
{:ok, config} = Prismatic.LLM.Backend.create_config(:openai, %{
  api_key: System.get_env("OPENAI_API_KEY"),
  model: "gpt-4",
  temperature: 0.3
})

prompt = """
Generate an Elixir module for the Prismatic project with the following requirements:

**Module Name**: {{MODULE_NAME}}
**Purpose**: {{PURPOSE}}
**Domain**: {{DOMAIN}} (e.g., LLM, Documentation, Event, Memory)

**Requirements**:
- Follow Prismatic naming conventions and patterns
- Include comprehensive @moduledoc with examples
- Add @typedoc for all custom types
- Include @spec for all public functions
- Add proper error handling with {:ok, result} | {:error, reason} patterns
- Include at least 3 usage examples in the moduledoc
- Add comprehensive doctests (at least 2 per public function)

**Context**:
- This is part of the Prismatic umbrella application
- Should integrate with existing patterns in lib/prismatic/
- Follow the behavior pattern if it's an interface module
- Include telemetry events for monitoring if applicable

**Style Guidelines**:
- Use descriptive function names
- Prefer pattern matching over conditional logic
- Include private helper functions where appropriate
- Add comprehensive guards for input validation

**Output Format**:
Provide the complete module code with:
1. Module definition with @moduledoc
2. All type definitions with @typedoc
3. Public API functions with @spec and @doc
4. Private helper functions
5. Usage examples in comments
"""

context = %{
  system_message: "You are an expert Elixir developer working on the Prismatic project. Generate high-quality, production-ready code that follows established patterns and conventions.",
  temperature: 0.3,
  max_tokens: 2000
}

{:ok, response} = Prismatic.LLM.Backend.generate_response(config, prompt, context)
```

**Example Usage**:
```elixir
# Replace placeholders
prompt = String.replace(prompt, "{{MODULE_NAME}}", "Prismatic.Analytics.MetricsCollector")
prompt = String.replace(prompt, "{{PURPOSE}}", "Collect and aggregate system metrics")
prompt = String.replace(prompt, "{{DOMAIN}}", "Analytics")
```

### Template: GenServer Implementation

**Use Case**: Generate robust GenServer modules with proper OTP patterns

```text
Create a GenServer module for the Prismatic project:

**Module**: {{MODULE_NAME}}
**Purpose**: {{PURPOSE}}
**State Structure**: {{STATE_DESCRIPTION}}

**Requirements**:
- Complete GenServer implementation with use GenServer
- start_link/1 function with proper options handling
- init/1 callback with state initialization
- Public API functions that call GenServer.call/cast
- Handle all required callbacks (handle_call, handle_cast, handle_info)
- Proper supervision tree integration
- State validation and error handling
- Graceful shutdown with terminate/2
- Include comprehensive logging

**OTP Patterns**:
- Use GenServer.call for synchronous operations
- Use GenServer.cast for asynchronous operations  
- Implement handle_continue for initialization heavy lifting
- Add proper timeout handling
- Include process monitoring where needed

**Prismatic Integration**:
- Include telemetry events for state changes
- Follow Prismatic error handling patterns
- Add health check functionality
- Include metrics collection points

**Output Requirements**:
1. Complete module with all callbacks
2. Comprehensive @moduledoc with examples
3. @spec for all functions
4. Usage examples
5. Integration with supervision tree
```

### Template: Function Implementation

**Use Case**: Generate specific functions with comprehensive error handling

```text
Implement an Elixir function with the following specification:

**Function Name**: {{FUNCTION_NAME}}
**Module Context**: {{MODULE_NAME}}
**Purpose**: {{DESCRIPTION}}
**Input**: {{INPUT_DESCRIPTION}}
**Output**: {{OUTPUT_DESCRIPTION}}

**Technical Requirements**:
- Return {:ok, result} | {:error, reason} tuple
- Include comprehensive input validation
- Add proper @spec and @doc annotations
- Include at least 2 doctests
- Handle edge cases explicitly
- Use pattern matching effectively
- Include logging for important operations

**Quality Standards**:
- No nested conditionals deeper than 2 levels
- Use with statements for complex operations
- Include descriptive variable names
- Add inline comments for complex logic
- Follow Elixir community conventions

**Error Handling**:
- Validate all inputs with guards or pattern matching
- Return descriptive error atoms
- Log errors appropriately
- Include error context in error tuples

**Examples Needed**:
- Happy path example
- Error case example
- Edge case example

Provide the complete function implementation with documentation.
```

---

## Code Analysis Templates

### Template: Code Quality Review

**Use Case**: Comprehensive analysis of existing code for quality improvements

```text
Analyze the following Elixir code for quality, performance, and maintainability:

```elixir
{{CODE_TO_ANALYZE}}
```

**Analysis Framework**:

1. **Code Quality**:
   - Readability and clarity
   - Naming conventions
   - Function complexity
   - Documentation quality
   - Test coverage implications

2. **Elixir Best Practices**:
   - Pattern matching usage
   - Error handling patterns
   - OTP compliance
   - Functional programming principles
   - Performance considerations

3. **Prismatic Standards**:
   - Consistency with project patterns
   - Integration with existing modules
   - Error handling conventions
   - Logging and telemetry
   - Type specification completeness

4. **Security Considerations**:
   - Input validation
   - Potential vulnerabilities
   - Data sanitization
   - Access control implications

**Output Format**:
1. **Overall Assessment**: Brief summary with score (1-10)
2. **Strengths**: What the code does well
3. **Issues Found**: Categorized list of problems
4. **Specific Recommendations**: Actionable improvements
5. **Refactored Code**: Improved version (if needed)
6. **Testing Suggestions**: Additional test cases to consider

**Priority Levels**:
- 🔴 Critical: Must fix before production
- 🟡 Important: Should fix in current iteration
- 🟢 Enhancement: Nice to have improvements
```

### Template: Security Analysis

**Use Case**: Security-focused code review and vulnerability assessment

```text
Perform a security analysis of the following code:

```elixir
{{CODE_TO_ANALYZE}}
```

**Security Analysis Areas**:

1. **Input Validation**:
   - User input sanitization
   - Type checking and validation
   - Boundary condition handling
   - Injection attack prevention

2. **Data Handling**:
   - Sensitive data exposure
   - Data encryption requirements
   - Logging of sensitive information
   - Data storage security

3. **Authentication & Authorization**:
   - Access control checks
   - Permission validation
   - Session management
   - Token handling

4. **External Dependencies**:
   - Third-party library usage
   - API call security
   - Network communication
   - Certificate validation

5. **Error Handling**:
   - Information leakage in errors
   - Stack trace exposure
   - Error logging practices
   - Graceful failure handling

**Risk Assessment**:
- **High Risk**: Immediate security threats
- **Medium Risk**: Potential vulnerabilities
- **Low Risk**: Security improvements

**Output Requirements**:
1. Security score (1-10)
2. Vulnerability summary
3. Risk assessment with CVSS-like scoring
4. Mitigation strategies
5. Secure code alternatives
6. Testing recommendations for security
```

---

## Refactoring Templates

### Template: Legacy Code Modernization

**Use Case**: Modernize existing code to current standards and patterns

```text
Refactor the following code to modern Elixir standards and Prismatic conventions:

```elixir
{{LEGACY_CODE}}
```

**Modernization Goals**:

1. **Language Features**:
   - Use latest Elixir idioms
   - Leverage new language features
   - Improve pattern matching
   - Optimize function composition

2. **Error Handling**:
   - Convert to {:ok, result} | {:error, reason} patterns
   - Add comprehensive error coverage
   - Improve error messages
   - Add proper logging

3. **Performance**:
   - Optimize for current Elixir/OTP version
   - Reduce memory allocations
   - Improve algorithmic complexity
   - Add lazy evaluation where appropriate

4. **Maintainability**:
   - Break down large functions
   - Add comprehensive documentation
   - Improve naming conventions
   - Add type specifications

5. **Testing**:
   - Make code more testable
   - Reduce coupling
   - Add dependency injection
   - Include test examples

**Constraints**:
- Maintain backward compatibility where possible
- Preserve existing public API
- Don't break existing tests
- Document breaking changes clearly

**Output Format**:
1. **Refactored Code**: Complete modernized implementation
2. **Change Summary**: List of modifications made
3. **Breaking Changes**: Any API changes
4. **Migration Guide**: How to update calling code
5. **Performance Impact**: Expected performance changes
6. **Test Updates**: Necessary test modifications
```

### Template: Performance Optimization

**Use Case**: Optimize code for better performance characteristics

```text
Optimize the following code for performance:

```elixir
{{CODE_TO_OPTIMIZE}}
```

**Performance Analysis**:

1. **Algorithmic Complexity**:
   - Current time/space complexity
   - Bottleneck identification
   - Alternative algorithms
   - Data structure optimization

2. **Elixir-Specific Optimizations**:
   - Process spawning efficiency
   - Message passing optimization
   - Memory usage reduction
   - Garbage collection impact

3. **Concurrent Processing**:
   - Parallelization opportunities
   - Task/GenServer usage
   - Flow/Stream optimization
   - Backpressure handling

4. **I/O Operations**:
   - Database query optimization
   - Network call efficiency
   - File system operations
   - Caching strategies

**Optimization Targets**:
- **Latency**: Reduce response time
- **Throughput**: Increase operations per second
- **Memory**: Reduce memory footprint
- **CPU**: Reduce computational overhead

**Output Requirements**:
1. **Optimized Code**: Performance-improved implementation
2. **Performance Analysis**: Before/after comparison
3. **Benchmarking Code**: Code to measure improvements
4. **Trade-offs**: Complexity vs performance considerations
5. **Monitoring**: Metrics to track performance
6. **Scaling Considerations**: How optimization affects scaling
```

---

## Documentation Templates

### Template: Module Documentation

**Use Case**: Generate comprehensive module documentation

```text
Create comprehensive documentation for the following Elixir module:

```elixir
{{MODULE_CODE}}
```

**Documentation Requirements**:

1. **@moduledoc**:
   - Clear purpose statement
   - High-level usage overview
   - Architecture context
   - Key concepts explanation
   - Integration examples

2. **Function Documentation**:
   - @doc for all public functions
   - Parameter descriptions
   - Return value explanations
   - Usage examples
   - Error conditions

3. **Examples Section**:
   - Basic usage examples
   - Advanced usage patterns
   - Common workflows
   - Integration examples
   - Error handling examples

4. **Type Documentation**:
   - @typedoc for all custom types
   - Clear type definitions
   - Usage context
   - Relationship to other types

**Documentation Style**:
- Use active voice
- Include concrete examples
- Explain the "why" not just the "what"
- Link to related modules
- Include performance considerations

**Code Examples Format**:
```elixir
# Good example with setup
iex> config = %{api_key: "test", model: "gpt-4"}
iex> Prismatic.LLM.Backend.validate_config(config)
:ok

# Error case example
iex> Prismatic.LLM.Backend.validate_config(%{})
{:error, {:missing_required_fields, [:backend_type, :api_key]}}
```

**Output Format**:
1. Complete @moduledoc with examples
2. @doc for each public function
3. @typedoc for custom types
4. Usage examples section
5. Integration guide
6. Troubleshooting section
```

### Template: API Documentation

**Use Case**: Document API endpoints and integration patterns

```text
Generate API documentation for the following module/endpoint:

**Module/Endpoint**: {{API_NAME}}
**Purpose**: {{PURPOSE}}
**Context**: {{CONTEXT}}

**Documentation Structure**:

1. **Overview**:
   - What the API does
   - When to use it
   - Prerequisites
   - Rate limits/constraints

2. **Authentication**:
   - Required credentials
   - Authentication method
   - Permission requirements
   - Security considerations

3. **Request Format**:
   - HTTP method and URL
   - Required headers
   - Request body structure
   - Parameter validation

4. **Response Format**:
   - Success response structure
   - Error response format
   - Status codes
   - Response headers

5. **Examples**:
   - cURL examples
   - Elixir client examples
   - JavaScript/frontend examples
   - Error handling examples

6. **Integration Guide**:
   - Client library usage
   - Common patterns
   - Best practices
   - Troubleshooting

**Code Example Format**:
```elixir
# Elixir client example
{:ok, response} = HTTPoison.post(
  "https://api.prismatic.dev/v1/{{endpoint}}",
  Jason.encode!(request_body),
  [("Authorization", "Bearer #{token}"), ("Content-Type", "application/json")]
)

case response do
  %{status_code: 200, body: body} ->
    {:ok, Jason.decode!(body)}
  %{status_code: status, body: body} ->
    {:error, {status, Jason.decode!(body)}}
end
```

Provide complete API documentation with practical examples.
```

---

## Testing Templates

### Template: Test Suite Generation

**Use Case**: Generate comprehensive test suites for modules

```text
Generate a comprehensive ExUnit test suite for the following module:

```elixir
{{MODULE_CODE}}
```

**Test Coverage Requirements**:

1. **Unit Tests**:
   - Test each public function
   - Cover all code paths
   - Test edge cases
   - Validate error conditions
   - Test input validation

2. **Integration Tests**:
   - Test module interactions
   - Test external dependencies
   - Test configuration handling
   - Test error propagation

3. **Property-Based Tests**:
   - Use StreamData for property testing
   - Test function properties
   - Generate test data
   - Validate invariants

4. **Performance Tests**:
   - Benchmark critical functions
   - Test under load
   - Memory usage tests
   - Concurrency tests

**Test Structure**:
```elixir
defmodule {{ModuleName}}Test do
  use ExUnit.Case, async: true
  use ExUnitProperties
  
  doctest {{ModuleName}}
  
  alias {{ModuleName}}
  
  describe "function_name/arity" do
    test "happy path description" do
      # Test implementation
    end
    
    test "error case description" do
      # Error test implementation
    end
    
    property "property description" do
      # Property-based test
    end
  end
end
```

**Test Quality Standards**:
- Descriptive test names
- Clear arrange/act/assert structure
- Comprehensive assertions
- Mock external dependencies
- Test cleanup when needed

**Output Requirements**:
1. Complete test module
2. Tests for all public functions
3. Property-based tests where appropriate
4. Mock configurations
5. Test helpers if needed
6. Performance benchmarks
```

### Template: Test Case Generation

**Use Case**: Generate specific test cases for functions

```text
Generate comprehensive test cases for the following function:

```elixir
{{FUNCTION_CODE}}
```

**Function Analysis**:
- **Function Name**: {{FUNCTION_NAME}}
- **Parameters**: {{PARAMETERS}}
- **Return Type**: {{RETURN_TYPE}}
- **Side Effects**: {{SIDE_EFFECTS}}

**Test Case Categories**:

1. **Happy Path Tests**:
   - Valid input scenarios
   - Expected output verification
   - Normal operation flow
   - Success conditions

2. **Edge Case Tests**:
   - Boundary conditions
   - Empty inputs
   - Maximum/minimum values
   - Special characters/formats

3. **Error Case Tests**:
   - Invalid inputs
   - Missing parameters
   - Type mismatches
   - External dependency failures

4. **Performance Tests**:
   - Large input handling
   - Memory usage
   - Execution time
   - Concurrent access

**Test Implementation Format**:
```elixir
test "descriptive test name" do
  # Arrange
  input = setup_test_data()
  expected = expected_result()
  
  # Act
  result = ModuleName.function_name(input)
  
  # Assert
  assert result == expected
  # Additional assertions
end
```

**Requirements**:
- Cover all function branches
- Test all error conditions
- Include integration scenarios
- Add performance considerations
- Mock external dependencies

Generate complete test cases with setup and assertions.
```

---

## Debugging Templates

### Template: Bug Analysis

**Use Case**: Analyze and debug reported issues

```text
Analyze the following bug report and provide debugging guidance:

**Bug Report**:
- **Description**: {{BUG_DESCRIPTION}}
- **Steps to Reproduce**: {{REPRODUCTION_STEPS}}
- **Expected Behavior**: {{EXPECTED}}
- **Actual Behavior**: {{ACTUAL}}
- **Error Messages**: {{ERROR_MESSAGES}}
- **Environment**: {{ENVIRONMENT}}

**Code Context**:
```elixir
{{RELEVANT_CODE}}
```

**Debugging Analysis**:

1. **Root Cause Analysis**:
   - Identify potential causes
   - Analyze code paths
   - Review error patterns
   - Check for race conditions

2. **Investigation Steps**:
   - Logging points to add
   - Data to collect
   - Tests to run
   - Monitoring to check

3. **Hypothesis Testing**:
   - Possible causes ranked by likelihood
   - Specific tests to validate each hypothesis
   - Quick verification methods
   - Elimination strategies

4. **Fix Strategies**:
   - Immediate workarounds
   - Short-term fixes
   - Long-term solutions
   - Prevention measures

**Debugging Code**:
Provide specific debugging code:
```elixir
# Add detailed logging
require Logger
Logger.debug("Debug point: #{inspect(variable)}", module: __MODULE__)

# Add assertion checks
assert variable != nil, "Variable should not be nil at this point"

# Add monitoring
:telemetry.execute([:debug, :checkpoint], %{value: variable})
```

**Output Requirements**:
1. **Root Cause Hypothesis**: Most likely cause
2. **Investigation Plan**: Step-by-step debugging approach
3. **Debugging Code**: Specific code to add for investigation
4. **Fix Recommendations**: Proposed solutions
5. **Prevention Strategy**: How to avoid similar issues
6. **Test Cases**: Tests to prevent regression
```

### Template: Performance Debugging

**Use Case**: Debug performance issues and bottlenecks

```text
Analyze the following performance issue:

**Performance Problem**:
- **Description**: {{PERFORMANCE_ISSUE}}
- **Symptoms**: {{SYMPTOMS}}
- **Metrics**: {{CURRENT_METRICS}}
- **Expected Performance**: {{EXPECTED_METRICS}}
- **Environment**: {{ENVIRONMENT}}

**Code Under Investigation**:
```elixir
{{CODE_TO_ANALYZE}}
```

**Performance Analysis**:

1. **Profiling Strategy**:
   - Tools to use (:fprof, :eprof, observer)
   - Metrics to collect
   - Profiling duration
   - Load conditions

2. **Bottleneck Identification**:
   - CPU-bound operations
   - Memory allocations
   - I/O operations
   - Process communication

3. **Measurement Code**:
   - Benchmarking setup
   - Performance markers
   - Memory tracking
   - Timing measurements

4. **Optimization Strategies**:
   - Algorithmic improvements
   - Data structure changes
   - Concurrency adjustments
   - Caching opportunities

**Profiling Code Examples**:
```elixir
# Benchmarking with Benchee
Benchee.run(%{
  "current_implementation" => fn -> current_function(input) end,
  "optimized_implementation" => fn -> optimized_function(input) end
})

# Memory profiling
:erlang.process_info(self(), :memory)
result = function_to_profile()
:erlang.process_info(self(), :memory)

# Timing with telemetry
start_time = System.monotonic_time()
result = function_call()
end_time = System.monotonic_time()
duration = System.convert_time_unit(end_time - start_time, :native, :microsecond)
```

**Output Requirements**:
1. **Performance Analysis**: Detailed bottleneck analysis
2. **Profiling Plan**: Specific profiling approach
3. **Measurement Code**: Code to measure performance
4. **Optimization Recommendations**: Specific improvements
5. **Before/After Comparison**: Expected performance gains
6. **Monitoring Setup**: Long-term performance tracking
```

---

## Architecture Templates

### Template: System Design

**Use Case**: Design new systems or components

```text
Design a system component with the following requirements:

**System Requirements**:
- **Purpose**: {{PURPOSE}}
- **Functional Requirements**: {{FUNCTIONAL_REQUIREMENTS}}
- **Non-Functional Requirements**: {{NON_FUNCTIONAL_REQUIREMENTS}}
- **Constraints**: {{CONSTRAINTS}}
- **Integration Points**: {{INTEGRATION_POINTS}}

**Design Considerations**:

1. **Architecture Patterns**:
   - Suitable design patterns
   - OTP behaviors to use
   - Supervision strategies
   - Process organization

2. **Data Flow**:
   - Input/output specifications
   - Data transformations
   - State management
   - Error propagation

3. **Scalability**:
   - Performance characteristics
   - Scaling strategies
   - Resource requirements
   - Bottleneck analysis

4. **Reliability**:
   - Fault tolerance
   - Recovery mechanisms
   - Monitoring points
   - Health checks

**Design Artifacts**:

1. **Module Structure**:
```elixir
defmodule Prismatic.{{Domain}}.{{Component}} do
  @moduledoc """
  {{PURPOSE}}
  
  ## Architecture
  
  {{ARCHITECTURE_DESCRIPTION}}
  
  ## Usage
  
  {{USAGE_EXAMPLES}}
  """
end
```

2. **Supervision Tree**:
```elixir
defmodule Prismatic.{{Domain}}.Supervisor do
  use Supervisor
  
  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def init(_opts) do
    children = [
      # Child specifications
    ]
    
    Supervisor.init(children, strategy: :one_for_one)
  end
end
```

**Output Requirements**:
1. **Architecture Overview**: High-level design
2. **Module Specifications**: Detailed module design
3. **Interface Definitions**: Public APIs
4. **Data Structures**: Core data types
5. **Integration Plan**: How it fits into Prismatic
6. **Implementation Roadmap**: Development phases
```

### Template: Architecture Decision Record (ADR)

**Use Case**: Document significant architectural decisions

```text
Create an Architecture Decision Record for the following decision:

**Decision Context**:
- **Title**: {{DECISION_TITLE}}
- **Problem**: {{PROBLEM_DESCRIPTION}}
- **Context**: {{CONTEXT_AND_CONSTRAINTS}}
- **Decision Makers**: {{STAKEHOLDERS}}

**ADR Template**:

# ADR-{{NUMBER}}: {{TITLE}}

**Status**: {{STATUS}} (Proposed/Accepted/Deprecated/Superseded)
**Date**: {{DATE}}
**Deciders**: {{DECIDERS}}
**Technical Story**: {{TECHNICAL_CONTEXT}}

## Context and Problem Statement

{{PROBLEM_DESCRIPTION}}

**Key Questions**:
- {{QUESTION_1}}
- {{QUESTION_2}}
- {{QUESTION_3}}

## Decision Drivers

- {{DRIVER_1}}
- {{DRIVER_2}}
- {{DRIVER_3}}

## Considered Options

### Option 1: {{OPTION_1_NAME}}

**Description**: {{OPTION_1_DESCRIPTION}}

**Pros**:
- {{PRO_1}}
- {{PRO_2}}

**Cons**:
- {{CON_1}}
- {{CON_2}}

**Implementation**:
```elixir
# Example implementation
```

### Option 2: {{OPTION_2_NAME}}

**Description**: {{OPTION_2_DESCRIPTION}}

**Pros**:
- {{PRO_1}}
- {{PRO_2}}

**Cons**:
- {{CON_1}}
- {{CON_2}}

## Decision Outcome

**Chosen Option**: {{CHOSEN_OPTION}}

**Justification**: {{JUSTIFICATION}}

**Positive Consequences**:
- {{POSITIVE_1}}
- {{POSITIVE_2}}

**Negative Consequences**:
- {{NEGATIVE_1}}
- {{NEGATIVE_2}}

## Implementation Plan

1. {{STEP_1}}
2. {{STEP_2}}
3. {{STEP_3}}

## Monitoring and Review

**Success Metrics**:
- {{METRIC_1}}
- {{METRIC_2}}

**Review Date**: {{REVIEW_DATE}}

## Related Decisions

- [ADR-{{RELATED_NUMBER}}](link-to-related-adr)

Generate a complete ADR following this structure.
```

---

## Advanced Prompt Techniques

### Chain of Thought Prompting

**Use Case**: Complex problem-solving requiring step-by-step reasoning

```text
Solve this complex development problem step by step:

**Problem**: {{COMPLEX_PROBLEM}}

**Instructions**: Work through this problem step by step. For each step:
1. State what you're analyzing
2. Explain your reasoning
3. Show your work
4. Draw conclusions
5. Move to the next logical step

**Step-by-Step Analysis**:

Step 1: {{ANALYSIS_FOCUS}}
- Reasoning: {{REASONING}}
- Findings: {{FINDINGS}}
- Conclusion: {{CONCLUSION}}

Step 2: {{NEXT_FOCUS}}
- Reasoning: {{REASONING}}
- Findings: {{FINDINGS}}
- Conclusion: {{CONCLUSION}}

[Continue until problem is solved]

**Final Solution**:
{{COMPREHENSIVE_SOLUTION}}

**Validation**:
{{HOW_TO_VERIFY_SOLUTION}}
```

### Few-Shot Learning

**Use Case**: Teaching AI specific patterns through examples

```text
Learn from these examples and apply the pattern to a new case:

**Example 1**:
Input: {{EXAMPLE_1_INPUT}}
Output: {{EXAMPLE_1_OUTPUT}}
Explanation: {{EXAMPLE_1_EXPLANATION}}

**Example 2**:
Input: {{EXAMPLE_2_INPUT}}
Output: {{EXAMPLE_2_OUTPUT}}
Explanation: {{EXAMPLE_2_EXPLANATION}}

**Example 3**:
Input: {{EXAMPLE_3_INPUT}}
Output: {{EXAMPLE_3_OUTPUT}}
Explanation: {{EXAMPLE_3_EXPLANATION}}

**Pattern Recognition**:
The pattern I should follow is: {{PATTERN_DESCRIPTION}}

**New Case**:
Input: {{NEW_INPUT}}

Apply the learned pattern to generate the output with explanation.
```

### Self-Correction Prompting

**Use Case**: Improving AI responses through self-review

```text
{{INITIAL_TASK_PROMPT}}

**Initial Response**:
{{GENERATE_INITIAL_RESPONSE}}

**Self-Review Process**:
Now review your response and check for:
1. **Accuracy**: Are all facts and code examples correct?
2. **Completeness**: Did you address all parts of the request?
3. **Quality**: Does the code follow best practices?
4. **Clarity**: Is the explanation clear and well-structured?
5. **Integration**: Does it fit well with Prismatic patterns?

**Issues Found**:
{{LIST_ANY_ISSUES}}

**Improved Response**:
{{PROVIDE_CORRECTED_VERSION}}

**Final Validation**:
{{CONFIRM_QUALITY_STANDARDS_MET}}
```

---

## Prompt Optimization Strategies

### Context Window Management

**Technique**: Efficiently use available context space

1. **Prioritize Information**:
   - Most relevant context first
   - Remove redundant information
   - Use concise but complete descriptions
   - Include only necessary examples

2. **Structured Context**:
   - Use clear sections and headers
   - Bullet points for lists
   - Code blocks for examples
   - Consistent formatting

3. **Progressive Disclosure**:
   - Start with high-level requirements
   - Add details incrementally
   - Use follow-up prompts for specifics
   - Build on previous responses

### Temperature and Parameter Tuning

**Guidelines** for different use cases:

```elixir
# Code generation - Low temperature for consistency
context = %{
  temperature: 0.1,  # Very deterministic
  max_tokens: 2000,
  top_p: 0.9
}

# Creative problem solving - Medium temperature
context = %{
  temperature: 0.7,  # Balanced creativity/consistency
  max_tokens: 1500,
  top_p: 0.95
}

# Brainstorming - Higher temperature
context = %{
  temperature: 0.9,  # More creative/diverse
  max_tokens: 1000,
  top_p: 0.95
}

# Analysis tasks - Low-medium temperature
context = %{
  temperature: 0.3,  # Focused and analytical
  max_tokens: 2500,
  top_p: 0.9
}
```

### Error Handling in Prompts

**Technique**: Building robust prompts that handle edge cases

```text
{{MAIN_PROMPT_CONTENT}}

**Error Handling Instructions**:

If you encounter any of these situations:

1. **Insufficient Information**:
   - Clearly state what information is missing
   - Provide best guess with assumptions listed
   - Suggest how to obtain missing information

2. **Conflicting Requirements**:
   - Identify the conflicts
   - Suggest resolution strategies
   - Provide alternative approaches

3. **Ambiguous Requests**:
   - Ask clarifying questions
   - Provide multiple interpretations
   - Recommend the most likely intent

4. **Technical Impossibilities**:
   - Explain why something can't be done
   - Suggest closest possible alternatives
   - Provide workaround strategies

**Response Format for Errors**:
- State the issue clearly
- Explain the impact
- Provide actionable next steps
- Include partial solutions where possible
```

---

## Integration with Prismatic LLM Backend

### Configuration Examples

```elixir
# Production configuration
defp get_llm_config(provider) do
  case provider do
    :openai ->
      %{
        backend_type: :openai,
        api_key: System.get_env("OPENAI_API_KEY"),
        model: "gpt-4",
        timeout: 30_000,
        max_retries: 3,
        temperature: 0.3
      }
    
    :anthropic ->
      %{
        backend_type: :anthropic,
        api_key: System.get_env("ANTHROPIC_API_KEY"),
        model: "claude-3-sonnet-20240229",
        timeout: 30_000,
        max_retries: 3,
        temperature: 0.3
      }
  end
end

# Execute prompt with error handling
def execute_prompt(provider, prompt, context \\ %{}) do
  with {:ok, config} <- Prismatic.LLM.Backend.create_config(provider, get_llm_config(provider)),
       {:ok, response} <- Prismatic.LLM.Backend.generate_response(config, prompt, context) do
    {:ok, response}
  else
    {:error, reason} ->
      Logger.error("LLM request failed: #{inspect(reason)}")
      {:error, reason}
  end
end
```

### Prompt Template System

```elixir
defmodule Prismatic.PromptTemplates do
  @moduledoc """
  Centralized prompt template management for consistent AI interactions.
  """
  
  @templates %{
    code_generation: """
    Generate Elixir code for the following specification:
    
    **Requirements**: {{requirements}}
    **Context**: {{context}}
    **Constraints**: {{constraints}}
    
    Follow Prismatic coding standards and include comprehensive documentation.
    """,
    
    code_review: """
    Review the following code for quality and improvements:
    
    ```elixir
    {{code}}
    ```
    
    Provide specific, actionable feedback following Prismatic standards.
    """,
    
    documentation: """
    Generate documentation for the following module:
    
    ```elixir
    {{module_code}}
    ```
    
    Include comprehensive examples and integration guidance.
    """
  }
  
  def get_template(template_name, variables \\ %{}) do
    case Map.get(@templates, template_name) do
      nil -> {:error, {:template_not_found, template_name}}
      template -> {:ok, substitute_variables(template, variables)}
    end
  end
  
  defp substitute_variables(template, variables) do
    Enum.reduce(variables, template, fn {key, value}, acc ->
      String.replace(acc, "{{#{key}}}", to_string(value))
    end)
  end
end
```

### Monitoring and Metrics

```elixir
# Add telemetry events for prompt tracking
:telemetry.execute(
  [:prismatic, :llm, :prompt, :start],
  %{template: template_name, provider: provider},
  %{prompt_length: String.length(prompt)}
)

# Track response quality
:telemetry.execute(
  [:prismatic, :llm, :prompt, :complete],
  %{response_length: String.length(response), duration: duration},
  %{template: template_name, provider: provider, success: true}
)
```

---

## Troubleshooting Prompts

### Common Issues and Solutions

1. **Inconsistent Responses**:
   - Lower temperature (0.1-0.3)
   - Add more specific constraints
   - Include explicit format requirements
   - Use few-shot examples

2. **Incomplete Responses**:
   - Increase max_tokens
   - Break complex requests into smaller parts
   - Use "continue" prompts for long responses
   - Optimize prompt length

3. **Off-Topic Responses**:
   - Add stronger context constraints
   - Use system messages effectively
   - Include explicit scope limitations
   - Add task-specific instructions

4. **Poor Code Quality**:
   - Include specific quality criteria
   - Add code review as second step
   - Use self-correction prompting
   - Include project-specific patterns

### Debugging Prompts

```elixir
# Add debug information to responses
debug_context = %{
  debug_mode: true,
  include_reasoning: true,
  show_alternatives: true
}

# Log prompt and response for analysis
Logger.debug("Prompt: #{inspect(prompt)}")
Logger.debug("Context: #{inspect(context)}")
Logger.debug("Response: #{inspect(response)}")
```

---

**💡 Pro Tip**: The most effective prompts combine clear instructions, relevant context, specific constraints, and validation steps. Start with simple prompts and iteratively refine based on results. Always include error handling and validation in your prompt workflows.

---

## Related Documentation

- [LLM Integration Patterns](llm-integration-patterns.md) - Technical integration patterns
- [Best Practices for AI Development](best-practices.md) - Core principles and guidelines
- [Automated Code Generation](automated-code-generation.md) - End-to-end automation workflows
- [LLM Backend Implementation](../../../lib/prismatic/llm/backend.ex) - Core LLM system reference