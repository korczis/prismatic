defmodule Prismatic.MixProject do
  use Mix.Project

  def project do
    [
      app: :prismatic,
      version: "0.1.1",
      elixir: "~> 1.17",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      listeners: [Phoenix.CodeReloader],

      # Dialyzer configuration
      dialyzer: [
        plt_add_apps: [:ex_unit, :mix],
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
        main: "readme", # The main page in the docs
        extras: ["README.md"],
        logo: "priv/static/images/logo.svg",
        assets: %{"priv/static/images" => "assets"},
        formatters: ["html", "epub"],
        groups_for_modules: [
          "Web": [
            PrismaticWeb,
            ~r/PrismaticWeb\..*/
          ],
          "Core": [
            Prismatic,
            ~r/Prismatic\..*/
          ]
        ],
        groups_for_extras: [
          "Guides": ~r/guides\/[^\/]+\.md/
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
      extra_applications: [:logger, :runtime_tools]
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
      {:phoenix, "~> 1.8.0-rc.0", override: true},
      {:phoenix_ecto, "~> 4.5"},
      {:ecto_sql, "~> 3.10"},
      {:postgrex, ">= 0.0.0"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 1.0"},
      {:floki, ">= 0.30.0", only: :test},
      {:phoenix_live_dashboard, "~> 0.8.3"},
      {:esbuild, "~> 0.9", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.3", runtime: Mix.env() == :dev},
      {:heroicons,
       github: "tailwindlabs/heroicons",
       tag: "v2.1.1",
       sparse: "optimized",
       app: false,
       compile: false,
       depth: 1},
      {:swoosh, "~> 1.16"},
      {:req, "~> 0.5"},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      {:gettext, "~> 0.26"},
      {:jason, "~> 1.2"},
      {:dns_cluster, "~> 0.1.1"},
      {:bandit, "~> 1.5"},
      {:ex_doc, "~> 0.31", only: :dev, runtime: false},
      {:git_ops, "~> 2.6", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false}
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
      setup: ["deps.get", "ecto.setup", "assets.setup", "assets.build"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      dialyzer_setup: ["cmd mkdir -p priv/plts", "dialyzer --build-plt"],
      dialyzer: ["dialyzer"],
      ci: ["format --check-formatted", "test", "dialyzer"],
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
