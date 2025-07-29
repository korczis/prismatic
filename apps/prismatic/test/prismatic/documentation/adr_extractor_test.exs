defmodule Prismatic.Documentation.ADRExtractorTest do
  use ExUnit.Case, async: true
  alias Prismatic.Documentation.ADRExtractor

  describe "extract_adr_metadata/1" do
    test "extracts basic ADR metadata from file" do
      # Create a test ADR file
      test_file = create_test_adr_file()

      result = ADRExtractor.extract_adr_metadata(test_file)

      assert result.decision_id == 1
      assert result.title == "ADR-0001: Test Decision"
      assert result.status == "Accepted"
      assert result.date == ~D[2024-01-15]
      assert is_binary(result.summary)
      assert is_binary(result.context)
      assert is_binary(result.decision)
      assert is_list(result.alternatives)
      assert is_map(result.consequences)
      assert result.architectural_domain in ["general", "security", "performance", "integration", "data", "frontend", "infrastructure", "architecture"]

      # Clean up
      File.rm!(test_file)
    end

    test "handles ADR with alternatives" do
      test_file = create_adr_with_alternatives()

      result = ADRExtractor.extract_adr_metadata(test_file)

      assert length(result.alternatives) > 0

      first_alternative = List.first(result.alternatives)
      assert Map.has_key?(first_alternative, :name)
      assert Map.has_key?(first_alternative, :description)
      assert Map.has_key?(first_alternative, :pros)
      assert Map.has_key?(first_alternative, :cons)
      assert Map.has_key?(first_alternative, :rejection_reason)

      File.rm!(test_file)
    end

    test "categorizes architectural domain correctly" do
      security_file = create_security_adr()

      result = ADRExtractor.extract_adr_metadata(security_file)

      assert result.architectural_domain == "security"

      File.rm!(security_file)
    end

    test "extracts cross-references" do
      test_file = create_adr_with_references()

      result = ADRExtractor.extract_adr_metadata(test_file)

      assert length(result.cross_references) > 0
      assert length(result.code_references) > 0

      File.rm!(test_file)
    end
  end

  describe "extract_all_adrs/1" do
    test "extracts multiple ADRs from directory" do
      test_dir = setup_test_adr_directory()

      result = ADRExtractor.extract_all_adrs(test_dir)

      assert is_map(result)
      assert Map.has_key?(result, :summary)
      assert Map.has_key?(result, :adrs)
      assert length(result.adrs) >= 2

      # Check summary statistics
      assert result.summary.total_adrs == length(result.adrs)
      assert is_map(result.summary.status_distribution)
      assert is_map(result.summary.domain_distribution)

      cleanup_test_directory(test_dir)
    end

    test "handles empty directory" do
      empty_dir = create_empty_directory()

      result = ADRExtractor.extract_all_adrs(empty_dir)

      assert result.summary.total_adrs == 0
      assert result.adrs == []

      cleanup_test_directory(empty_dir)
    end
  end

  # Helper functions for test setup
  defp create_test_adr_file do
    content = """
    # ADR-0001: Test Decision

    **Status**: Accepted
    **Date**: 2024-01-15
    **Authors**: Test Author
    **Reviewers**: Test Reviewer

    ## Summary

    This is a test ADR for unit testing purposes.

    ## Context

    We need to test the ADR extraction functionality to ensure
    it properly parses and categorizes architectural decisions.

    ## Decision

    We will use this test ADR to validate the extraction process
    and ensure all metadata is correctly parsed.

    ## Alternatives Considered

    ### Alternative 1: Manual Testing
    **Description:** Test manually without automated tests.
    **Pros:**
    - Quick to implement
    - No additional test code needed

    **Cons:**
    - Error-prone
    - Not repeatable

    **Why rejected:** Automated testing is more reliable.

    ## Consequences

    ### Positive Consequences
    - Tests pass successfully
    - Extraction works correctly
    - Validation is automated

    ### Negative Consequences
    - Additional test maintenance required
    - More complex test setup

    ### Mitigation Strategies
    - Keep tests simple and focused
    - Use helper functions for setup

    ## Implementation

    The implementation will include comprehensive test coverage
    for all ADR extraction functionality.

    ## Related Decisions

    - ADR-0002: Testing Strategy
    - ADR-0003: Documentation Standards
    """

    temp_file = Path.join(System.tmp_dir!(), "adr-0001-test-decision.md")
    File.write!(temp_file, content)
    temp_file
  end

  defp create_adr_with_alternatives do
    content = """
    # ADR-0002: Alternative Testing

    **Status**: Proposed
    **Date**: 2024-01-16

    ## Summary
    Testing ADR with multiple alternatives.

    ## Context
    Need to test alternative parsing.

    ## Decision
    Use multiple alternatives for testing.

    ## Alternatives Considered

    ### Alternative 1: Single Alternative
    **Description:** Use only one alternative.
    **Pros:**
    - Simple
    - Easy to understand

    **Cons:**
    - Limited testing coverage

    **Why rejected:** Need comprehensive testing.

    ### Alternative 2: Multiple Alternatives
    **Description:** Use several alternatives for thorough testing.
    **Pros:**
    - Comprehensive coverage
    - Tests edge cases
    - Better validation

    **Cons:**
    - More complex setup

    **Why rejected:** Actually, this is the chosen approach.

    ## Consequences

    ### Positive Consequences
    - Better test coverage

    ### Negative Consequences
    - More test maintenance
    """

    temp_file = Path.join(System.tmp_dir!(), "adr-0002-alternative-testing.md")
    File.write!(temp_file, content)
    temp_file
  end

  defp create_security_adr do
    content = """
    # ADR-0003: Security Authentication

    **Status**: Accepted
    **Date**: 2024-01-17

    ## Summary
    Implement secure authentication using JWT tokens with encryption.

    ## Context
    The application needs robust security measures to protect user data
    and prevent unauthorized access through authentication and authorization.

    ## Decision
    We will implement JWT-based authentication with encryption and
    multi-factor authentication for enhanced security.

    ## Consequences

    ### Positive Consequences
    - Strong security posture
    - Encrypted token storage
    - Multi-factor authentication support

    ### Negative Consequences
    - Additional complexity
    - Performance overhead from encryption
    """

    temp_file = Path.join(System.tmp_dir!(), "adr-0003-security-authentication.md")
    File.write!(temp_file, content)
    temp_file
  end

  defp create_adr_with_references do
    content = """
    # ADR-0004: Reference Testing

    **Status**: Accepted
    **Date**: 2024-01-18

    ## Summary
    Test ADR with various references and code examples.

    ## Context
    This ADR includes references to other documentation files like
    [Architecture Overview](../core/architecture-overview.md) and
    [API Documentation](../reference/api-endpoints.md).

    ## Decision
    We will use `AuthModule.authenticate/2` and implement the
    authentication logic in `auth_service.ex` file.

    The implementation will use the `Prismatic.Auth` module and
    integrate with `Phoenix.Controller` for web requests.

    ## Implementation

    Key files to modify:
    - `lib/auth_service.ex`
    - `lib/prismatic/auth.ex`
    - Configuration in `config/config.exs`

    ## Related Decisions
    - ADR-0001: Test Decision
    - ADR-0003: Security Authentication
    """

    temp_file = Path.join(System.tmp_dir!(), "adr-0004-reference-testing.md")
    File.write!(temp_file, content)
    temp_file
  end

  defp setup_test_adr_directory do
    test_dir = Path.join(System.tmp_dir!(), "test_adrs_#{:rand.uniform(10000)}")
    File.mkdir_p!(test_dir)

    # Create multiple ADR files
    files = [
      create_test_adr_file(),
      create_security_adr(),
      create_adr_with_references()
    ]

    # Move files to test directory
    Enum.each(files, fn source_file ->
      filename = Path.basename(source_file)
      target_file = Path.join(test_dir, filename)
      File.cp!(source_file, target_file)
      File.rm!(source_file)
    end)

    test_dir
  end

  defp create_empty_directory do
    test_dir = Path.join(System.tmp_dir!(), "empty_test_#{:rand.uniform(10000)}")
    File.mkdir_p!(test_dir)
    test_dir
  end

  defp cleanup_test_directory(test_dir) do
    if File.exists?(test_dir) do
      File.rm_rf!(test_dir)
    end
  end
end
