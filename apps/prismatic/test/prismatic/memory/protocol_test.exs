defmodule Prismatic.Memory.ProtocolTest do
  use ExUnit.Case, async: true
  doctest Prismatic.Memory.Protocol

  alias Prismatic.Memory.Protocol

  describe "create_config/2" do
    test "creates valid test backend config" do
      {:ok, config} = Protocol.create_config(:test, %{})

      assert config.backend_type == :test
      assert config.timeout == 30_000
      assert config.max_retries == 3
      assert is_atom(config.name)
    end

    test "creates config with custom options" do
      {:ok, config} = Protocol.create_config(:test, %{
        name: :custom_memory,
        timeout: 5_000,
        max_retries: 5
      })

      assert config.name == :custom_memory
      assert config.timeout == 5_000
      assert config.max_retries == 5
    end

    test "rejects invalid backend type" do
      assert {:error, {:unsupported_backend, :invalid}} =
        Protocol.create_config(:invalid, %{})
    end
  end

  describe "memory operations" do
    setup do
      {:ok, config} = Protocol.create_config(:test, %{})
      %{config: config}
    end

    test "store and retrieve operations", %{config: config} do
      # Store data
      assert {:ok, _memory} = Protocol.store(config, :working, "test_key", "test_value")

      # Retrieve data
      assert {:ok, "test_value"} = Protocol.retrieve(config, :working, "test_key")
    end

    test "retrieve non-existent key returns not_found", %{config: config} do
      assert {:error, :not_found} = Protocol.retrieve(config, :working, "nonexistent")
    end

    test "forget operation", %{config: config} do
      # Store and verify
      assert {:ok, _} = Protocol.store(config, :working, "temp_key", "temp_value")
      assert {:ok, "temp_value"} = Protocol.retrieve(config, :working, "temp_key")

      # Forget and verify
      assert {:ok, _} = Protocol.forget(config, :working, "temp_key")
      assert {:error, :not_found} = Protocol.retrieve(config, :working, "temp_key")
    end

    test "search operation", %{config: config} do
      # Store test data
      assert {:ok, _} = Protocol.store(config, :working, "user_1", "Alice")
      assert {:ok, _} = Protocol.store(config, :working, "user_2", "Bob")
      assert {:ok, _} = Protocol.store(config, :working, "admin_1", "Charlie")

      # Search with pattern
      assert {:ok, results} = Protocol.search(config, :working, "user_*")
      assert length(results) == 2

      # Verify results contain expected keys
      result_keys = Enum.map(results, fn {key, _value} -> key end)
      assert "user_1" in result_keys
      assert "user_2" in result_keys
      refute "admin_1" in result_keys
    end

    test "consolidate operation", %{config: config} do
      # Store some data
      assert {:ok, _} = Protocol.store(config, :working, "consolidate_test", "data")

      # Consolidate should succeed
      assert {:ok, _memory} = Protocol.consolidate(config)
    end
  end

  describe "validation" do
    setup do
      {:ok, config} = Protocol.create_config(:test, %{})
      %{config: config}
    end

    test "validates memory types", %{config: config} do
      assert {:error, {:invalid_memory_type, :invalid}} =
        Protocol.store(config, :invalid, "key", "value")
    end

    test "validates keys", %{config: config} do
      assert {:error, {:invalid_key, 123}} =
        Protocol.store(config, :working, 123, "value")
    end

    test "validates search patterns", %{config: config} do
      assert {:error, {:invalid_pattern, 123}} =
        Protocol.search(config, :working, 123)
    end
  end

  describe "backend info and health" do
    setup do
      {:ok, config} = Protocol.create_config(:test, %{})
      %{config: config}
    end

    test "health check returns ok", %{config: config} do
      assert :ok = Protocol.health_check(config)
    end

    test "get backend info returns valid info", %{config: config} do
      assert {:ok, info} = Protocol.get_backend_info(config)
      assert info.backend_type == :test
      assert is_integer(info.max_entries)
      assert is_boolean(info.supports_ttl)
    end
  end

  describe "available backends and memory types" do
    test "lists available backends" do
      backends = Protocol.available_backends()
      assert :test in backends
      assert :cachex in backends
      assert :nebulex in backends
      assert :mnesia in backends
      assert :layered in backends
    end

    test "lists memory types" do
      types = Protocol.memory_types()
      assert :working in types
      assert :episodic in types
      assert :semantic in types
      assert :procedural in types
    end
  end
end
