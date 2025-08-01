defmodule Prismatic.MixProject do
  use Mix.Project

  def project do
    [
      app: :prismatic,
      version: "0.1.1",
      elixir: "~> 1.17",
      elixirc_paths: elixirc_paths(Mix.env()),
      elixirc_options: [warnings_as_errors: true],
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      listeners: [Phoenix.CodeReloader],

      # Test Coverage Configuration
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test,
        "coveralls.cobertura": :test,
        "test.watch": :test,
        "test.property": :test,
        "test.integration": :test
      ],

      # Dialyzer configuration
      dialyzer: [
        plt_add_apps: [:ex_unit, :mix, :stream_data, :mox],
        plt_file: {:no_warn, "priv/plts/dialyzer.plt"},
        plt_core_path: "priv/plts/",
        plt_local_path: "priv/plts/",
        ignore_warnings: ".dialyzer_ignore.exs",
        flags: [
          :error_handling,
          :underspecs,
          :unmatched_returns,
          :extra_return,
          :missing_return
        ],
        exclude_files: [
          "lib/mix/tasks/git_ops.init.ex"
        ]
      ],

      # ExDoc configuration
      name: "Prismatic",
      source_url: "https://github.com/korczis/prismatic",
      homepage_url: "https://github.com/korczis/prismatic",
      docs: [
        main: "readme",
        extras: [
          "README.md",
          "docs/architecture/README.md",
          "docs/agents/README.md",
          "docs/memory/README.md",
          "docs/applications/README.md"
        ],
        logo: "priv/static/images/logo.svg",
        assets: %{"priv/static/images" => "assets", "docs/images" => "images"},
        formatters: ["html", "epub"],
        groups_for_modules: [
          Web: [
            PrismaticWeb,
            ~r/PrismaticWeb\..*/
          ],
          "Core Protocols": [
            ~r/Prismatic\.Agent\.Protocol/,
            ~r/Prismatic\.Memory\.Protocol/,
            ~r/Prismatic\.LLM\.Backend/
          ],
          Implementations: [
            ~r/Prismatic\.Agent\.Impl/,
            ~r/Prismatic\.Memory\.Impl/,
            ~r/Prismatic\.LLM\.Impl/
          ],
          Supervision: [
            ~r/Prismatic\.Supervisor\..*/
          ],
          Testing: [
            ~r/Prismatic\.Test\..*/
          ],
          Core: [
            Prismatic,
            ~r/Prismatic\..*/
          ]
        ],
        groups_for_extras: [
          Architecture: ~r/docs\/architecture\/.*/,
          Protocols: ~r/docs\/(agents|memory|llm)\/.*/,
          Applications: ~r/docs\/applications\/.*/,
          Guides: ~r/guides\/[^\/]+\.md/
        ]
      ]
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {Prismatic.Application, []},
      extra_applications: [:logger, :runtime_tools, :mnesia]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      # Phoenix Framework
      {:phoenix, "~> 1.8.0-rc.0", override: true},
      {:phoenix_ecto, "~> 4.5"},
      {:ecto_sql, "~> 3.10"},
      {:postgrex, ">= 0.0.0"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 1.0"},
      {:phoenix_live_dashboard, "~> 0.8.3"},

      # Asset Management
      {:esbuild, "~> 0.9", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.3", runtime: Mix.env() == :dev},
      {:heroicons,
       github: "tailwindlabs/heroicons",
       tag: "v2.1.1",
       sparse: "optimized",
       app: false,
       compile: false,
       depth: 1},

      # Core Dependencies
      {:swoosh, "~> 1.16"},
      {:req, "~> 0.5"},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      {:gettext, "~> 0.26"},
      {:jason, "~> 1.2"},
      {:dns_cluster, "~> 0.1.1"},
      {:bandit, "~> 1.5"},

      # AI/LLM Dependencies
      {:uuid, "~> 1.1"},

      # Memory System Dependencies
      {:cachex, "~> 3.6"},
      {:nebulex, "~> 2.6"},
      {:shards, "~> 1.1"},
      {:decorator, "~> 1.4"},
      {:telemetry_registry, "~> 0.3"},

      # Development Tools
      {:ex_doc, "~> 0.31", only: :dev, runtime: false},
      {:git_ops, "~> 2.6", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},

      # Testing Infrastructure
      {:floki, ">= 0.30.0", only: :test},
      {:stream_data, "~> 1.0", only: [:dev, :test]},
      {:excoveralls, "~> 0.18", only: :test},
      {:ex_machina, "~> 2.7", only: [:dev, :test]},
      {:mox, "~> 1.1", only: :test},
      {:bypass, "~> 2.1", only: :test},
      {:hammox, "~> 0.7", only: :test},

      # Performance & Benchmarking
      {:benchee, "~> 1.3", only: [:dev, :test]},
      {:benchee_html, "~> 1.0", only: [:dev, :test]},

      # Monitoring & Observability
      {:telemetry, "~> 1.2"},

      # TODO: AI Should review naming of this group
      # Streaming
      # {:amqp, "~> 4.1"},
      # {:amqp_client, "~> 4.0"},
      {:gen_stage, "~> 1.3"},
      {:flow, "~> 1.2"},
      {:broadway, "~> 1.2"},
      # {:broadway_rabbitmq, "~> 0.8.2"},
      {:broadway_dashboard, "~> 0.4.1"},
      # {:off_broadway_websocket, "~> 1.0"},
      {:yaml_elixir, "~> 2.11"},
      {:toml, "~> 0.7"}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      # Setup and Development
      setup: ["deps.get", "ecto.setup", "assets.setup", "assets.build"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],

      # Testing Infrastructure
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      "test.unit": ["test --exclude integration --exclude property"],
      "test.integration": ["test --only integration"],
      "test.property": ["test --only property"],
      "test.watch": ["test.watch"],
      "test.coverage": ["coveralls.html"],
      "test.coverage.detail": ["coveralls.detail"],
      "test.all": ["test.unit", "test.integration", "test.property"],

      # Code Quality
      quality: ["format", "credo --strict", "dialyzer"],
      "quality.check": ["format --check-formatted", "credo --strict", "dialyzer"],
      dialyzer_setup: ["cmd mkdir -p priv/plts", "dialyzer --build-plt"],
      dialyzer: ["dialyzer"],

      # CI/CD Pipeline
      ci: ["quality.check", "test.coverage", "docs"],
      "ci.full": ["deps.get", "compile --warnings-as-errors", "quality.check", "test.all", "docs"],

      # Documentation
      docs: ["docs"],
      "docs.serve": ["cmd open docs/index.html"],

      # Benchmarking
      bench: ["run benchmarks/run_benchmarks.exs"],
      "bench.memory": ["run benchmarks/memory_benchmarks.exs"],

      # Assets
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["tailwind prismatic", "esbuild prismatic"],
      "assets.deploy": [
        "tailwind prismatic --minify",
        "esbuild prismatic --minify",
        "phx.digest"
      ]
    ]
  end
end
