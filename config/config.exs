# This file is responsible for configuring your umbrella
# and **all applications** and their dependencies with the
# help of the Config module.
#
# Note that all applications in your umbrella share the
# same configuration and dependencies, which is why they
# all use the same configuration file. If you want different
# configurations or dependencies per app, it is best to
# move said applications out of the umbrella.
import Config

# Configure Mix tasks and generators
config :prismatic,
  ecto_repos: [Prismatic.Repo],
  generators: [timestamp_type: :utc_datetime]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :prismatic, Prismatic.Mailer, adapter: Swoosh.Adapters.Local

# Configure umbrella web app
config :prismatic_web,
  ecto_repos: [Prismatic.Repo],
  generators: [context_app: :prismatic, binary_id: true]

# Configures the endpoint
config :prismatic_web, PrismaticWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: PrismaticWeb.ErrorHTML, json: PrismaticWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Prismatic.PubSub,
  live_view: [signing_salt: "9r2xFm6e"]

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.17.11",
  prismatic_web: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../apps/prismatic_web/assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.0.9",
  prismatic_web: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../apps/prismatic_web/assets", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Configure git_ops for changelog generation and version management
config :git_ops,
  mix_project: Prismatic.Umbrella.MixProject,
  changelog_file: "CHANGELOG.md",
  repository_url: "https://github.com/korczis/prismatic",
  # Manage the version numbers in mix.exs
  version_tag_prefix: "v",
  # Using conventional commit format
  types: [
    # Changes that affect the build system or external dependencies
    build: [
      "build",
      "ci",
      "chore"
    ],
    # Documentation only changes
    docs: [
      "docs",
      "doc"
    ],
    # A new feature
    feat: [
      "feat",
      "feature"
    ],
    # A bug fix
    fix: [
      "fix"
    ],
    # Performance improvements
    perf: [
      "perf",
      "performance"
    ],
    # Code refactoring without functionality changes
    refactor: [
      "refactor"
    ],
    # Changes that do not affect the meaning of the code
    style: [
      "style"
    ],
    # Adding missing tests or correcting existing tests
    test: [
      "test"
    ]
  ],
  # The format of the changelog entries
  changelog_sections: [
    feat: "New Features",
    fix: "Bug Fixes",
    perf: "Performance Improvements",
    refactor: "Code Refactoring",
    docs: "Documentation Updates",
    build: "Build System",
    test: "Tests",
    style: "Styling"
  ]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
