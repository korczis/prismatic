import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :prismatic, Prismatic.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "prismatic_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :prismatic_web, PrismaticWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "test_secret_key_base_that_is_at_least_64_characters_long_for_security",
  server: false

# In test we don't send emails
config :prismatic, Prismatic.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Configure ExUnit
config :ex_unit,
  capture_log: true,
  assert_receive_timeout: 1000

# Test Coverage Configuration
config :excoveralls,
  test_coverage: [
    minimum_coverage: 85,
    refuse_coverage_below: 80
  ],
  coverage_options: [
    treat_no_relevant_lines_as_covered: true,
    output_dir: "cover/",
    template_path: "cover/coverage.html.eex"
  ]

# Property-based testing configuration
config :stream_data,
  max_runs: 100,
  max_run_time: 30_000,
  max_shrinking_steps: 1000

# LLM Backend Test Configuration
config :prismatic, :llm_backends,
  test: %{
    module: Prismatic.LLM.TestBackend,
    config: %{
      responses: %{
        "default" => "This is a test response",
        "error" => {:error, :test_error}
      }
    }
  },
  mock: %{
    module: Prismatic.LLM.MockBackend,
    config: %{}
  }

# Memory System Test Configuration
config :prismatic, :memory,
  adapter: Prismatic.Memory.TestAdapter,
  config: %{
    persistence: :memory,
    max_size: 1000,
    ttl: :timer.minutes(30)
  }

# Agent System Test Configuration
config :prismatic, :agents,
  default_config: %{
    timeout: 5000,
    max_retries: 2,
    memory_size: 100
  }

# Event Bus Test Configuration
config :prismatic, :event_bus,
  adapter: Prismatic.EventBus.TestAdapter,
  config: %{
    max_events: 1000,
    persistence: false
  }

# Telemetry Test Configuration
config :telemetry, :test_mode, true

# Disable external HTTP calls in tests
config :prismatic, :http_client, Prismatic.HTTPClient.Mock

# Test-specific feature flags
config :prismatic, :features,
  chaos_engineering: true,
  performance_monitoring: true,
  debug_logging: true
