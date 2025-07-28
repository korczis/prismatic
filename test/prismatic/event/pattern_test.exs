defmodule Prismatic.Event.PatternTest do
  use ExUnit.Case, async: true

  alias Prismatic.Event.Pattern

  doctest Pattern

  describe "match?/2" do
    test "exact matches work correctly" do
      assert Pattern.match?("agent.alice.message", "agent.alice.message")
      refute Pattern.match?("agent.alice.message", "agent.bob.message")
      refute Pattern.match?("agent.alice.message", "system.error")
    end

    test "single wildcard matches work correctly" do
      assert Pattern.match?("agent.*.message", "agent.alice.message")
      assert Pattern.match?("agent.*.message", "agent.bob.message")
      refute Pattern.match?("agent.*.message", "agent.alice.error")
      refute Pattern.match?("agent.*.message", "system.alice.message")
    end

    test "multi-segment wildcard matches work correctly" do
      assert Pattern.match?("agent.**", "agent.alice.message")
      assert Pattern.match?("agent.**", "agent.alice.message.urgent")
      assert Pattern.match?("agent.**", "agent.system.deep.nested.event")
      refute Pattern.match?("agent.**", "system.alice.message")
    end

    test "suffix wildcard matches work correctly" do
      assert Pattern.match?("**.error", "system.memory.error")
      assert Pattern.match?("**.error", "agent.alice.error")
      assert Pattern.match?("**.error", "deep.nested.system.error")
      refute Pattern.match?("**.error", "system.memory.success")
    end

    test "alternative patterns work correctly" do
      assert Pattern.match?("agent.{alice,bob}", "agent.alice")
      assert Pattern.match?("agent.{alice,bob}", "agent.bob")
      refute Pattern.match?("agent.{alice,bob}", "agent.charlie")
      refute Pattern.match?("agent.{alice,bob}", "system.alice")
    end

    test "complex patterns work correctly" do
      # Multi-level alternatives
      assert Pattern.match?("system.{memory,llm}.*.{store,retrieve}", "system.memory.cache.store")
      assert Pattern.match?("system.{memory,llm}.*.{store,retrieve}", "system.llm.backend.retrieve")
      refute Pattern.match?("system.{memory,llm}.*.{store,retrieve}", "system.event.cache.store")
      refute Pattern.match?("system.{memory,llm}.*.{store,retrieve}", "system.memory.cache.delete")

      # Mixed wildcards and alternatives
      assert Pattern.match?("{agent,system}.**.error", "agent.alice.message.error")
      assert Pattern.match?("{agent,system}.**.error", "system.deep.nested.error")
      refute Pattern.match?("{agent,system}.**.error", "user.system.error")
    end

    test "edge cases are handled correctly" do
      # Empty segments
      refute Pattern.match?("agent..message", "agent.alice.message")

      # Single character matches
      assert Pattern.match?("a", "a")
      refute Pattern.match?("a", "b")

      # Very long patterns
      long_pattern = String.duplicate("a.", 100) <> "*"
      long_event = String.duplicate("a.", 100) <> "b"
      assert Pattern.match?(long_pattern, long_event)
    end
  end

  describe "is_exact_match?/1" do
    test "identifies exact patterns correctly" do
      assert Pattern.is_exact_match?("agent.alice.message")
      assert Pattern.is_exact_match?("system.error")
      assert Pattern.is_exact_match?("a.b.c.d.e")
    end

    test "identifies wildcard patterns correctly" do
      refute Pattern.is_exact_match?("agent.*.message")
      refute Pattern.is_exact_match?("agent.**")
      refute Pattern.is_exact_match?("**.error")
      refute Pattern.is_exact_match?("*")
    end

    test "identifies alternative patterns correctly" do
      refute Pattern.is_exact_match?("agent.{alice,bob}")
      refute Pattern.is_exact_match?("{system,agent}.error")
      refute Pattern.is_exact_match?("system.{memory,llm}.store")
    end
  end

  describe "compile_pattern/1" do
    test "compiles exact patterns" do
      compiled = Pattern.compile_pattern("agent.alice.message")
      assert elem(compiled, 0) == :exact
      assert elem(compiled, 1) == ["agent", "alice", "message"]
    end

    test "compiles wildcard patterns" do
      compiled = Pattern.compile_pattern("agent.*.message")
      assert elem(compiled, 0) in [:wildcard, :compound]
    end

    test "compiles multi-wildcard patterns" do
      compiled = Pattern.compile_pattern("agent.**")
      assert elem(compiled, 0) == :multi_wildcard
    end

    test "compiles alternative patterns" do
      compiled = Pattern.compile_pattern("agent.{alice,bob}")
      assert elem(compiled, 0) in [:alternatives, :compound]
    end
  end

  describe "validate_pattern/1" do
    test "validates correct patterns" do
      assert Pattern.validate_pattern("agent.alice.message") == :ok
      assert Pattern.validate_pattern("agent.*.message") == :ok
      assert Pattern.validate_pattern("agent.**") == :ok
      assert Pattern.validate_pattern("agent.{alice,bob}") == :ok
      assert Pattern.validate_pattern("*.{system,agent}.error") == :ok
    end

    test "rejects empty patterns" do
      assert {:error, :empty_pattern} = Pattern.validate_pattern("")
    end

    test "rejects empty alternatives" do
      assert {:error, :empty_alternatives} = Pattern.validate_pattern("agent.{}")
    end

    test "rejects unclosed alternatives" do
      assert {:error, :unclosed_alternatives} = Pattern.validate_pattern("agent.{alice")
      assert {:error, :unclosed_alternatives} = Pattern.validate_pattern("agent.alice}")
    end

    test "rejects invalid wildcard sequences" do
      assert {:error, :invalid_wildcard_sequence} = Pattern.validate_pattern("agent.***")
    end
  end

  describe "performance characteristics" do
    test "handles large number of patterns efficiently" do
      patterns = for i <- 1..1000 do
        "pattern.#{i}.*.test"
      end

      event_type = "pattern.500.data.test"

      start_time = System.monotonic_time()

      matches = Enum.filter(patterns, &Pattern.match?(&1, event_type))

      end_time = System.monotonic_time()
      duration = System.convert_time_unit(end_time - start_time, :native, :microsecond)

      assert length(matches) == 1
      # Should complete within reasonable time (adjust threshold as needed)
      assert duration < 10_000  # 10ms
    end

    test "handles complex patterns efficiently" do
      complex_patterns = [
        "system.{memory,llm,event}.*.{store,retrieve,delete,update}",
        "agent.{alice,bob,charlie}.{message,action,state}.{urgent,normal,low}",
        "**.{error,warning,info,debug}",
        "{frontend,backend,mobile}.**.{user,system}.event"
      ]

      test_events = [
        "system.memory.cache.store",
        "agent.alice.message.urgent",
        "deep.nested.system.error",
        "frontend.web.user.event"
      ]

      start_time = System.monotonic_time()

      results = for pattern <- complex_patterns, event <- test_events do
        Pattern.match?(pattern, event)
      end

      end_time = System.monotonic_time()
      duration = System.convert_time_unit(end_time - start_time, :native, :microsecond)

      assert length(results) == 16
      # Should complete within reasonable time
      assert duration < 5_000  # 5ms
    end
  end

  describe "real-world scenarios" do
    test "agent communication patterns" do
      patterns = [
        "agent.*.message.*",
        "agent.alice.*",
        "**.urgent",
        "agent.{alice,bob}.{message,action}"
      ]

      events = [
        "agent.alice.message.urgent",
        "agent.bob.action.normal",
        "agent.charlie.state.urgent",
        "system.agent.alice.message.urgent"
      ]

      expected_matches = [
        # agent.*.message.*
        [true, false, false, false],
        # agent.alice.*
        [true, false, false, false],
        # **.urgent
        [true, false, true, true],
        # agent.{alice,bob}.{message,action}
        [true, true, false, false]
      ]

      actual_matches = for pattern <- patterns do
        for event <- events do
          Pattern.match?(pattern, event)
        end
      end

      assert actual_matches == expected_matches
    end

    test "system monitoring patterns" do
      _monitoring_patterns = [
        "system.*.error",
        "**.{error,critical}",
        "system.{memory,llm,event}.*.{failure,timeout}",
        "{database,cache,queue}.connection.*"
      ]

      _system_events = [
        "system.memory.error",
        "database.connection.lost",
        "system.llm.backend.failure",
        "cache.redis.connection.timeout",
        "application.system.critical"
      ]

      # Test that monitoring patterns correctly identify relevant events
      error_pattern = "system.*.error"
      assert Pattern.match?(error_pattern, "system.memory.error")
      assert Pattern.match?(error_pattern, "system.database.error")
      refute Pattern.match?(error_pattern, "application.error")

      critical_pattern = "**.{error,critical}"
      assert Pattern.match?(critical_pattern, "system.memory.error")
      assert Pattern.match?(critical_pattern, "application.system.critical")
      refute Pattern.match?(critical_pattern, "system.memory.warning")

      connection_pattern = "{database,cache,queue}.connection.*"
      assert Pattern.match?(connection_pattern, "database.connection.lost")
      assert Pattern.match?(connection_pattern, "cache.connection.timeout")
      refute Pattern.match?(connection_pattern, "system.connection.lost")
    end

    test "user interaction patterns" do
      _user_patterns = [
        "user.{login,logout,register}",
        "user.*.action.*",
        "**.{click,view,download}",
        "frontend.user.{profile,settings,dashboard}.*"
      ]

      _user_events = [
        "user.login",
        "user.profile.action.update",
        "frontend.page.click",
        "frontend.user.dashboard.view",
        "backend.user.register"
      ]

      # Verify user interaction patterns work as expected
      login_pattern = "user.{login,logout,register}"
      assert Pattern.match?(login_pattern, "user.login")
      assert Pattern.match?(login_pattern, "user.register")
      refute Pattern.match?(login_pattern, "user.profile")

      interaction_pattern = "**.{click,view,download}"
      assert Pattern.match?(interaction_pattern, "frontend.page.click")
      assert Pattern.match?(interaction_pattern, "app.document.download")
      refute Pattern.match?(interaction_pattern, "app.document.upload")
    end
  end
end
