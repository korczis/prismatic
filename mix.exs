defmodule Prismatic.Umbrella.MixProject do
  use Mix.Project

  def project do
    [
      # Umbrella project configuration
      apps_path: "apps",
      version: "0.1.1",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),

      # Test Coverage Configuration (umbrella-wide)
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

      # Dialyzer configuration (umbrella-wide)
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
        ]
      ],

      # ExDoc configuration (umbrella-wide documentation)
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

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type "mix help deps" for more examples and options.
  #
  # Dependencies listed here are available only for this project
  # and cannot be accessed from applications inside the apps/ folder.
  defp deps do
    [
      # Required to run "mix format" on ~H/.heex files from the umbrella root
      {:phoenix_live_view, ">= 0.0.0"},

      # Development and Quality Tools (umbrella-wide)
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.31", only: :dev, runtime: false},
      {:git_ops, "~> 2.6", only: [:dev, :test], runtime: false},

      # Testing Infrastructure (umbrella-wide)
      {:excoveralls, "~> 0.18", only: :test},
      {:stream_data, "~> 1.0", only: [:dev, :test]},
      {:mox, "~> 1.1", only: :test},

      # Configuration and Data
      {:toml, "~> 0.7"},
      {:yaml_elixir, "~> 2.11"}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  #
  # Aliases listed here are available only for this project
  # and cannot be accessed from applications inside the apps/ folder.
  defp aliases do
    [
      # Setup and Development (umbrella-wide)
      setup: ["cmd mix setup", "deps.get"],

      # Testing Infrastructure (umbrella-wide)
      test: ["cmd mix test"],
      "test.unit": ["cmd mix test.unit"],
      "test.integration": ["cmd mix test.integration"],
      "test.property": ["cmd mix test.property"],
      "test.coverage": ["cmd mix test.coverage"],
      "test.coverage.detail": ["cmd mix test.coverage.detail"],
      "test.all": ["cmd mix test.all"],

      # Code Quality (umbrella-wide)
      quality: ["format", "cmd mix quality"],
      "quality.check": ["format --check-formatted", "cmd mix quality.check"],
      dialyzer_setup: ["cmd mkdir -p priv/plts", "dialyzer --build-plt"],
      dialyzer: ["dialyzer"],

      # CI/CD Pipeline (umbrella-wide)
      ci: ["quality.check", "test.coverage", "docs"],
      "ci.full": ["deps.get", "compile --warnings-as-errors", "quality.check", "test.all", "docs"],

      # Documentation
      docs: ["docs"],
      "docs.serve": ["cmd open docs/index.html"],

      # Benchmarking
      bench: ["cmd mix bench"],
      "bench.memory": ["cmd mix bench.memory"]
    ]
  end
end
