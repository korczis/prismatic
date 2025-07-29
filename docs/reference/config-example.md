# Configuration Examples

Comprehensive configuration examples and reference for all environments and deployment scenarios in the Prismatic application.

<!-- NAV_START -->
## Navigation

**Current Location**: [Home](../README.md) > [Reference](README.md) > Configuration Examples

### Quick Links

- **📚 [Parent Directory](README.md)** - Return to reference index
- **🏠 [Documentation Home](../README.md)** - Main documentation index
- **🔍 [Search Documentation](glossary.md)** - Find terms and concepts

### Related Documentation

- [Database Setup](../operations/database-setup.md) - Database configuration and setup
- [Deployment Procedures](../operations/deployment-procedures.md) - Deployment-specific configurations
- [Security Guidelines](../guides/security-guidelines.md) - Security configuration best practices
- [Performance Optimization](../guides/performance-optimization.md) - Performance-related configuration
- [CI/CD Configuration](../operations/cicd-configuration.md) - Continuous integration and deployment setup
<!-- NAV_END -->

## Overview

This document provides comprehensive configuration examples for the Prismatic application across different environments (development, test, staging, production). All sensitive values should be stored as environment variables and never committed to version control.

## Environment Configuration Structure

### Configuration Files
```
config/
├── config.exs          # Base configuration (shared)
├── dev.exs            # Development environment
├── test.exs           # Test environment  
├── prod.exs           # Production environment
└── runtime.exs        # Runtime configuration (loads env vars)
```

### Environment Variable Naming
- **Format**: `PRISMATIC_<COMPONENT>_<SETTING>`
- **Examples**: `PRISMATIC_DB_URL`, `PRISMATIC_SECRET_KEY_BASE`
- **Booleans**: Use `true`/`false` strings
- **Lists**: Comma-separated values

## Base Configuration

### config/config.exs
```elixir
import Config

# Application configuration
config :prismatic,
  ecto_repos: [Prismatic.Repo],
  generators: [
    binary_id: true,
    sample_binary_id: "11111111-1111-1111-1111-111111111111"
  ]

# Web application configuration
config :prismatic_web,
  ecto_repos: [Prismatic.Repo],
  generators: [context_app: :prismatic, binary_id: true]

# Endpoint configuration
config :prismatic_web, PrismaticWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: PrismaticWeb.ErrorHTML, json: PrismaticWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Prismatic.PubSub,
  live_view: [signing_salt: "secure_signing_salt"]

# Mailer configuration base
config :prismatic, Prismatic.Mailer,
  adapter: Swoosh.Adapters.Local

# Logger configuration
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Phoenix configuration
config :phoenix, :json_library, Jason

# Gettext configuration
config :prismatic_web, PrismaticWeb.Gettext,
  default_locale: "en",
  locales: ~w(en es fr de)

# Import environment-specific config
import_config "#{config_env()}.exs"
```

## Development Configuration

### config/dev.exs
```elixir
import Config

# Database configuration
config :prismatic, Prismatic.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "prismatic_dev",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10,
  # Development debugging
  log: :debug,
  queue_target: 5000,
  queue_interval: 5000

# Endpoint configuration
config :prismatic_web, PrismaticWeb.Endpoint,
  # Binding to loopback ipv4
  http: [ip: {127, 0, 0, 1}, port: 4000],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "super_secret_key_base_for_development_only_do_not_use_in_production",
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:prismatic_web, ~w(--sourcemap=inline --watch)]},
    tailwind: {Tailwind, :install_and_run, [:prismatic_web, ~w(--watch)]}
  ],
  live_reload: [
    patterns: [
      ~r"priv/static/(?!uploads/).*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"priv/gettext/.*(po)$",
      ~r"lib/prismatic_web/(controllers|live|components)/.*(ex|heex)$",
      ~r"lib/prismatic_web/templates/.*(eex)$"
    ]
  ]

# Mailer configuration for development
config :prismatic, Prismatic.Mailer,
  adapter: Swoosh.Adapters.Local

# Swoosh API client for mailbox preview
config :swoosh, :api_client, Swoosh.ApiClient.Finch

# Disable SSL in development
config :prismatic, Prismatic.Repo,
  ssl: false

# Authentication configuration
config :prismatic, Prismatic.Auth,
  jwt_secret: "dev_jwt_secret_key",
  jwt_ttl: {4, :hour},
  refresh_token_ttl: {30, :day}

# File upload configuration
config :prismatic, Prismatic.Uploads,
  adapter: Prismatic.Uploads.Local,
  upload_path: "priv/static/uploads",
  max_file_size: 10_000_000, # 10MB
  allowed_extensions: ~w(.jpg .jpeg .png .gif .pdf .doc .docx)

# Cache configuration
config :prismatic, Prismatic.Cache,
  adapter: Prismatic.Cache.Memory,
  ttl: :timer.minutes(30)

# Background job configuration
config :prismatic, Oban,
  engine: Oban.Engines.Basic,
  queues: [
    default: 10,
    mailers: 5,
    media: 3
  ],
  repo: Prismatic.Repo

# External API configuration (test endpoints)
config :prismatic, :external_apis,
  payment_gateway: [
    adapter: :stripe_sandbox,
    secret_key: "sk_test_sandbox_key",
    publishable_key: "pk_test_sandbox_key",
    webhook_secret: "whsec_test_webhook_secret"
  ],
  analytics: [
    adapter: :google_analytics_debug,
    tracking_id: "UA-000000-0"
  ]

# Phoenix LiveDashboard configuration
config :prismatic_web, PrismaticWeb.Endpoint,
  live_dashboard: [
    metrics: PrismaticWeb.Telemetry,
    additional_pages: [
      oban: {Oban.Web, [repo: Prismatic.Repo]}
    ]
  ]

# Development tools
config :phoenix_live_reload,
  backend: :fs_poll,
  dirs: [
    "lib/",
    "priv/"
  ]

# Logger configuration for development
config :logger, :console,
  level: :debug,
  format: "[$level] $message\n",
  colors: [enabled: true]

# Do not include metadata nor timestamps in development logs
config :logger, :console, format: "[$level] $message\n"
```

## Test Configuration

### config/test.exs
```elixir
import Config

# Test database configuration
config :prismatic, Prismatic.Repo,
  username: "postgres",
  password: "postgres", 
  hostname: "localhost",
  database: "prismatic_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2,
  # Disable migration locking for parallel tests
  migration_lock: nil,
  # Faster test runs
  ownership_timeout: 10_000,
  timeout: 5_000

# Test endpoint configuration
config :prismatic_web, PrismaticWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "test_secret_key_base_for_testing_environment_only",
  server: false

# Mailer configuration for tests
config :prismatic, Prismatic.Mailer,
  adapter: Swoosh.Adapters.Test

# Authentication configuration for tests
config :prismatic, Prismatic.Auth,
  jwt_secret: "test_jwt_secret_key",
  jwt_ttl: {1, :hour},
  refresh_token_ttl: {1, :day}

# File upload configuration for tests
config :prismatic, Prismatic.Uploads,
  adapter: Prismatic.Uploads.Test,
  upload_path: "tmp/test_uploads"

# Cache configuration for tests
config :prismatic, Prismatic.Cache,
  adapter: Prismatic.Cache.Test

# Background job configuration for tests
config :prismatic, Oban,
  testing: :inline,
  repo: Prismatic.Repo

# External API configuration (mocked)
config :prismatic, :external_apis,
  payment_gateway: [
    adapter: :mock,
    mock_responses: %{
      create_payment: {:ok, %{id: "mock_payment_123"}},
      refund_payment: {:ok, %{id: "mock_refund_123"}}
    }
  ],
  analytics: [
    adapter: :mock
  ]

# Logger configuration for tests
config :logger, level: :warning

# Password hashing speed (faster for tests)
config :argon2_elixir,
  t_cost: 1,
  m_cost: 8

# Reduce encryption rounds for tests
config :prismatic, Prismatic.Crypto,
  rounds: 1

# Phoenix test helpers
config :phoenix, :plug_init_mode, :runtime
```

## Production Configuration

### config/prod.exs
```elixir
import Config

# Production endpoint configuration
config :prismatic_web, PrismaticWeb.Endpoint,
  cache_static_manifest: "priv/static/cache_manifest.json",
  server: true,
  # Production optimizations
  http: [
    port: {:system, "PORT", 4000},
    compress: true,
    protocol_options: [
      max_request_line_length: 8192,
      max_header_value_length: 8192
    ]
  ],
  # HTTPS configuration
  https: [
    port: {:system, "HTTPS_PORT", 443},
    cipher_suite: :strong,
    certfile: {:system, "SSL_CERT_PATH"},
    keyfile: {:system, "SSL_KEY_PATH"},
    # Modern TLS configuration
    versions: [:"tlsv1.3", :"tlsv1.2"],
    secure_renegotiate: true,
    reuse_sessions: true,
    honor_cipher_order: true
  ],
  # Force SSL redirect
  force_ssl: [hsts: true, host: nil],
  # Production secret key base (from environment)
  secret_key_base: {:system, "SECRET_KEY_BASE"}

# Production mailer configuration
config :prismatic, Prismatic.Mailer,
  adapter: Swoosh.Adapters.SendGrid,
  api_key: {:system, "SENDGRID_API_KEY"}

# Production authentication configuration
config :prismatic, Prismatic.Auth,
  jwt_secret: {:system, "JWT_SECRET"},
  jwt_ttl: {1, :hour},
  refresh_token_ttl: {7, :day}

# Production file upload configuration
config :prismatic, Prismatic.Uploads,
  adapter: Prismatic.Uploads.S3,
  bucket: {:system, "S3_BUCKET"},
  region: {:system, "S3_REGION", "us-east-1"},
  access_key_id: {:system, "AWS_ACCESS_KEY_ID"},
  secret_access_key: {:system, "AWS_SECRET_ACCESS_KEY"},
  max_file_size: 50_000_000, # 50MB
  allowed_extensions: ~w(.jpg .jpeg .png .gif .pdf .doc .docx .zip)

# Production cache configuration
config :prismatic, Prismatic.Cache,
  adapter: Prismatic.Cache.Redis,
  url: {:system, "REDIS_URL"},
  pool_size: 10,
  timeout: 5000

# Production background job configuration
config :prismatic, Oban,
  engine: Oban.Engines.Basic,
  queues: [
    default: 25,
    mailers: 10,
    media: 5,
    analytics: 5
  ],
  repo: Prismatic.Repo,
  # Production job settings
  dispatch_cooldown: 5,
  shutdown_grace_period: 30_000

# External API configuration (production)
config :prismatic, :external_apis,
  payment_gateway: [
    adapter: :stripe,
    secret_key: {:system, "STRIPE_SECRET_KEY"},
    publishable_key: {:system, "STRIPE_PUBLISHABLE_KEY"},
    webhook_secret: {:system, "STRIPE_WEBHOOK_SECRET"}
  ],
  analytics: [
    adapter: :google_analytics,
    tracking_id: {:system, "GA_TRACKING_ID"}
  ]

# Production logger configuration
config :logger,
  level: :info,
  backends: [
    :console,
    {LoggerFileBackend, :error_log},
    {LoggerJSON, :json_log}
  ]

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id, :user_id, :organization_id]

config :logger, :error_log,
  path: "/var/log/prismatic/error.log",
  level: :error,
  format: "$time $metadata[$level] $message\n"

config :logger, :json_log,
  path: "/var/log/prismatic/app.log",
  level: :info,
  formatter: LoggerJSON.Formatters.BasicLogger

# Production SSL configuration
config :ssl, protocol_version: [:"tlsv1.3", :"tlsv1.2"]

# CORS configuration for production
config :cors_plug,
  origin: [
    "https://prismatic.example.com",
    "https://www.prismatic.example.com"
  ],
  max_age: 86400,
  methods: ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
  headers: ["Authorization", "Content-Type", "Accept", "Origin", "User-Agent", "DNT", "Cache-Control", "X-Mx-ReqToken", "Keep-Alive", "X-Requested-With", "If-Modified-Since"]

# Session configuration for production
config :prismatic_web, PrismaticWeb.Endpoint,
  session: [
    store: :cookie,
    key: "_prismatic_key",
    signing_salt: {:system, "SESSION_SIGNING_SALT"},
    encryption_salt: {:system, "SESSION_ENCRYPTION_SALT"},
    max_age: 86400, # 24 hours
    secure: true,
    http_only: true,
    same_site: "Lax"
  ]

# Do not print debug messages in production
config :logger, level: :info

# Runtime configuration loads from environment variables
# See config/runtime.exs for runtime environment variable loading
```

## Runtime Configuration

### config/runtime.exs
```elixir
import Config

# Runtime configuration - loads environment variables at runtime
if config_env() == :prod do
  # Database configuration from environment
  database_url =
    System.get_env("DATABASE_URL") ||
    raise """
    environment variable DATABASE_URL is missing.
    For example: ecto://USER:PASS@HOST/DATABASE
    """

  maybe_ipv6 = if System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []

  config :prismatic, Prismatic.Repo,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    socket_options: maybe_ipv6,
    # Production database optimizations
    queue_target: 5000,
    queue_interval: 5000,
    # SSL configuration
    ssl: true,
    ssl_opts: [
      verify: :verify_peer,
      cacerts: :public_key.cacerts_get(),
      server_name_indication: 
        System.get_env("DATABASE_SSL_SERVER_NAME") |> String.to_charlist(),
      customize_hostname_check: [
        match_fun: :public_key.pkix_verify_hostname_match_fun(:https)
      ]
    ]

  # Secret key base from environment
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
    raise """
    environment variable SECRET_KEY_BASE is missing.
    You can generate one by calling: mix phx.gen.secret
    """

  # Host configuration
  host = System.get_env("PHX_HOST") || "example.com"
  port = String.to_integer(System.get_env("PORT") || "4000")

  config :prismatic_web, PrismaticWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: port
    ],
    secret_key_base: secret_key_base

  # Email configuration
  config :prismatic, Prismatic.Mailer,
    adapter: Swoosh.Adapters.SendGrid,
    api_key: System.get_env("SENDGRID_API_KEY")

  # Redis configuration
  redis_url = System.get_env("REDIS_URL")
  if redis_url do
    config :prismatic, Prismatic.Cache,
      adapter: Prismatic.Cache.Redis,
      url: redis_url,
      pool_size: String.to_integer(System.get_env("REDIS_POOL_SIZE") || "10")
  end

  # S3 configuration for file uploads
  config :prismatic, Prismatic.Uploads,
    adapter: Prismatic.Uploads.S3,
    bucket: System.get_env("S3_BUCKET"),
    region: System.get_env("S3_REGION") || "us-east-1",
    access_key_id: System.get_env("AWS_ACCESS_KEY_ID"),
    secret_access_key: System.get_env("AWS_SECRET_ACCESS_KEY")

  # External API configurations
  if stripe_secret = System.get_env("STRIPE_SECRET_KEY") do
    config :prismatic, :external_apis,
      payment_gateway: [
        adapter: :stripe,
        secret_key: stripe_secret,
        publishable_key: System.get_env("STRIPE_PUBLISHABLE_KEY"),
        webhook_secret: System.get_env("STRIPE_WEBHOOK_SECRET")
      ]
  end

  # Monitoring and observability
  if honeybadger_api_key = System.get_env("HONEYBADGER_API_KEY") do
    config :honeybadger,
      api_key: honeybadger_api_key,
      environment_name: System.get_env("HONEYBADGER_ENV") || "production"
  end

  if new_relic_license = System.get_env("NEW_RELIC_LICENSE_KEY") do
    config :new_relic_agent,
      license_key: new_relic_license,
      app_name: System.get_env("NEW_RELIC_APP_NAME") || "Prismatic"
  end
end
```

## Docker Configuration

### Dockerfile
```dockerfile
# Build stage
FROM hexpm/elixir:1.16.0-erlang-26.2.1-alpine-3.18.4 AS build

# Install build dependencies
RUN apk add --no-cache build-base npm git python3

# Prepare build dir
WORKDIR /app

# Install hex + rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Set build ENV
ENV MIX_ENV="prod"

# Install mix dependencies
COPY mix.exs mix.lock ./
COPY apps/*/mix.exs apps/*/
RUN mix deps.get --only $MIX_ENV
RUN mkdir config

# Copy compile-time config files before we compile dependencies
COPY config/config.exs config/${MIX_ENV}.exs config/
RUN mix deps.compile

# Compile the release
COPY priv priv
COPY lib lib
COPY apps apps
RUN mix compile

# Changes to config/runtime.exs don't require recompiling the code
COPY config/runtime.exs config/

# Compile assets
COPY assets assets
COPY priv priv
RUN mix assets.deploy

# Compile the release
RUN mix release

# Application stage
FROM alpine:3.18.4 AS app

RUN apk add --no-cache openssl ncurses-libs libstdc++

WORKDIR /app

# Create app user
RUN addgroup -g 1000 -S app && \
    adduser -u 1000 -S app -G app

# Copy built application
COPY --from=build --chown=app:app /app/_build/prod/rel/prismatic ./

USER app

# Expose port
EXPOSE 4000

CMD ["bin/prismatic", "start"]
```

### docker-compose.yml
```yaml
version: '3.8'

services:
  web:
    build: .
    ports:
      - "4000:4000"
    environment:
      - DATABASE_URL=ecto://postgres:postgres@db:5432/prismatic_prod
      - SECRET_KEY_BASE=${SECRET_KEY_BASE}
      - PHX_HOST=${PHX_HOST:-localhost}
      - REDIS_URL=redis://redis:6379/0
    depends_on:
      - db
      - redis
    volumes:
      - ./uploads:/app/uploads
    restart: unless-stopped

  db:
    image: postgres:16-alpine
    environment:
      - POSTGRES_DB=prismatic_prod
      - POSTGRES_USER=postgres
      - POSTGRES_PASSWORD=postgres
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./priv/repo/init.sql:/docker-entrypoint-initdb.d/init.sql
    ports:
      - "5432:5432"
    restart: unless-stopped

  redis:
    image: redis:7-alpine
    volumes:
      - redis_data:/data
    ports:
      - "6379:6379"
    restart: unless-stopped

  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
      - ./ssl:/etc/nginx/ssl:ro
      - ./uploads:/var/www/uploads:ro
    depends_on:
      - web
    restart: unless-stopped

volumes:
  postgres_data:
  redis_data:
```

## Environment Variables Reference

### Required Environment Variables

#### Production Secrets
```bash
# Application secrets
SECRET_KEY_BASE="your_64_character_secret_key_base"
JWT_SECRET="your_jwt_signing_secret"
SESSION_SIGNING_SALT="your_session_signing_salt"
SESSION_ENCRYPTION_SALT="your_session_encryption_salt"

# Database
DATABASE_URL="ecto://username:password@hostname:port/database"
POOL_SIZE="10"

# Web server
PHX_HOST="your-domain.com"
PORT="4000"
HTTPS_PORT="443"
```

#### External Services
```bash
# Email service
SENDGRID_API_KEY="SG.your_sendgrid_api_key"

# File storage
AWS_ACCESS_KEY_ID="your_aws_access_key"
AWS_SECRET_ACCESS_KEY="your_aws_secret_key"
S3_BUCKET="your-s3-bucket-name"
S3_REGION="us-east-1"

# Cache
REDIS_URL="redis://localhost:6379/0"
REDIS_POOL_SIZE="10"

# Payment processing
STRIPE_SECRET_KEY="sk_live_your_stripe_secret"
STRIPE_PUBLISHABLE_KEY="pk_live_your_stripe_publishable"
STRIPE_WEBHOOK_SECRET="whsec_your_webhook_secret"
```

#### Monitoring and Observability
```bash
# Error tracking
HONEYBADGER_API_KEY="your_honeybadger_api_key"
HONEYBADGER_ENV="production"

# Application monitoring
NEW_RELIC_LICENSE_KEY="your_new_relic_license"
NEW_RELIC_APP_NAME="Prismatic Production"

# Analytics
GA_TRACKING_ID="UA-000000-1"
```

### Optional Environment Variables
```bash
# SSL/TLS
SSL_CERT_PATH="/path/to/cert.pem"
SSL_KEY_PATH="/path/to/key.pem"
DATABASE_SSL_SERVER_NAME="your-db-host.com"

# Feature flags
ENABLE_REGISTRATION="true"
ENABLE_SOCIAL_LOGIN="false"
MAINTENANCE_MODE="false"

# Performance tuning
ECTO_IPV6="false"
MAX_REQUEST_LINE_LENGTH="8192"
MAX_HEADER_VALUE_LENGTH="8192"

# Logging
LOG_LEVEL="info"
ENABLE_JSON_LOGGING="true"
```

## Nginx Configuration

### nginx.conf
```nginx
events {
    worker_connections 1024;
}

http {
    upstream phoenix {
        server web:4000 max_fails=5 fail_timeout=60s;
    }

    server {
        listen 80;
        server_name example.com www.example.com;
        return 301 https://$server_name$request_uri;
    }

    server {
        listen 443 ssl http2;
        server_name example.com www.example.com;

        # SSL configuration
        ssl_certificate /etc/nginx/ssl/cert.pem;
        ssl_certificate_key /etc/nginx/ssl/key.pem;
        ssl_session_timeout 1d;
        ssl_session_cache shared:MozTLS:10m;
        ssl_session_tickets off;

        # Modern TLS configuration
        ssl_protocols TLSv1.3 TLSv1.2;
        ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384;
        ssl_prefer_server_ciphers off;

        # Security headers
        add_header Strict-Transport-Security "max-age=63072000" always;
        add_header X-Frame-Options DENY;
        add_header X-Content-Type-Options nosniff;
        add_header X-XSS-Protection "1; mode=block";

        # Gzip compression
        gzip on;
        gzip_vary on;
        gzip_min_length 1024;
        gzip_types text/plain text/css text/xml text/javascript application/javascript application/xml+rss application/json;

        # File upload size
        client_max_body_size 50M;

        # Static files
        location /uploads/ {
            alias /var/www/uploads/;
            expires 1y;
            add_header Cache-Control "public, immutable";
        }

        # Phoenix LiveView WebSocket
        location /live/websocket {
            proxy_pass http://phoenix;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }

        # Main application
        location / {
            proxy_pass http://phoenix;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }
    }
}
```

## Health Check Configuration

### Health Check Endpoint
```elixir
# lib/prismatic_web/controllers/health_controller.ex
defmodule PrismaticWeb.HealthController do
  use PrismaticWeb, :controller

  def check(conn, _params) do
    checks = %{
      database: check_database(),
      cache: check_cache(),
      storage: check_storage(),
      external_apis: check_external_apis()
    }

    status = if Enum.all?(checks, fn {_k, v} -> v.status == :ok end) do
      :ok
    else
      :error
    end

    conn
    |> put_status(if status == :ok, do: 200, else: 503)
    |> json(%{
      status: status,
      checks: checks,
      version: Application.spec(:prismatic, :vsn),
      timestamp: DateTime.utc_now()
    })
  end

  defp check_database do
    try do
      Prismatic.Repo.query!("SELECT 1")
      %{status: :ok, response_time: measure_response_time(&Prismatic.Repo.query!/1, "SELECT 1")}
    rescue
      _ -> %{status: :error, error: "Database connection failed"}
    end
  end
end
```

## Monitoring Configuration

### Telemetry Configuration
```elixir
# lib/prismatic_web/telemetry.ex
defmodule PrismaticWeb.Telemetry do
  def metrics do
    [
      # Phoenix Metrics
      summary("phoenix.endpoint.stop.duration",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.router.dispatch.stop.duration",
        tags: [:route],
        unit: {:native, :millisecond}
      ),

      # Database Metrics
      summary("prismatic.repo.query.total_time",
        unit: {:native, :millisecond}
      ),
      counter("prismatic.repo.query.count"),

      # VM Metrics
      summary("vm.memory.total", unit: {:byte, :kilobyte}),
      summary("vm.total_run_queue_lengths.total"),
      summary("vm.total_run_queue_lengths.cpu"),
      summary("vm.total_run_queue_lengths.io"),

      # Custom Business Metrics
      counter("prismatic.users.registration.count"),
      counter("prismatic.posts.published.count"),
      summary("prismatic.posts.processing.duration",
        unit: {:native, :millisecond}
      )
    ]
  end
end
```

## Security Configuration Examples

### Content Security Policy
```elixir
# lib/prismatic_web/plugs/security_headers.ex
defmodule PrismaticWeb.Plugs.SecurityHeaders do
  def init(opts), do: opts

  def call(conn, _opts) do
    conn
    |> put_resp_header("content-security-policy", csp_header())
    |> put_resp_header("x-frame-options", "DENY")
    |> put_resp_header("x-content-type-options", "nosniff")
    |> put_resp_header("x-xss-protection", "1; mode=block")
    |> put_resp_header("referrer-policy", "strict-origin-when-cross-origin")
  end

  defp csp_header do
    "default-src 'self'; " <>
    "script-src 'self' 'unsafe-inline' https://js.stripe.com; " <>
    "style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; " <>
    "font-src 'self' https://fonts.gstatic.com; " <>
    "img-src 'self' data: https:; " <>
    "connect-src 'self' https://api.stripe.com; " <>
    "frame-src https://js.stripe.com https://hooks.stripe.com"
  end
end
```

## Related Documentation

- [Database Setup](../operations/database-setup.md) - Database installation and configuration
- [Deployment Procedures](../operations/deployment-procedures.md) - Production deployment configurations
- [Security Guidelines](../guides/security-guidelines.md) - Security configuration best practices
- [Performance Optimization](../guides/performance-optimization.md) - Performance-related configuration tuning
- [CI/CD Configuration](../operations/cicd-configuration.md) - Continuous integration and deployment setup
- [Monitoring Setup](../operations/monitoring-setup.md) - Application monitoring and observability configuration

---

**Configuration security is critical. Never commit sensitive values to version control. Use environment variables and secure secret management for all production deployments.**