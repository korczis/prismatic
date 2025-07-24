# Prismatic

To start your Phoenix server:

* Run `mix setup` to install and setup dependencies
* Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

Ready to run in production? Please [check our deployment guides](https://hexdocs.pm/phoenix/deployment.html).

## GitHub Actions CI/CD Pipeline

This project uses GitHub Actions for continuous integration and deployment with Phoenix releases.

### Workflow Overview

The workflow consists of three main jobs:

1. **Test**: Runs on every push and pull request to the master branch
   - Sets up Elixir 1.17.4 and Erlang 28.0.2
   - Caches dependencies
   - Runs the test suite against a Postgres database

2. **Build Release**: Runs only on pushes to the master branch
   - Compiles the application in production mode with PostgreSQL 17
   - Builds and processes assets
   - Creates a Phoenix release
   - Packages the release as a tarball artifact

3. **Deploy**: Runs after a successful build on the master branch
   - Downloads the release artifact
   - Deploys it to the production server

### Required Secrets

To use this workflow, you need to set up the following secrets in your GitHub repository:

- `SECRET_KEY_BASE`: Generate with `mix phx.gen.secret`
- `DATABASE_URL`: Your production database URL (e.g., `ecto://USER:PASS@HOST/DATABASE`)
- `PHX_HOST`: Your production host domain

For deployment:
- `SSH_PRIVATE_KEY`: SSH private key for deployment
- `SSH_HOST`: Hostname of your deployment server
- `SSH_USER`: Username for SSH connection

You can use the provided script to help generate these secrets:

```bash
./scripts/generate_github_secrets.sh
```

This script will generate a `SECRET_KEY_BASE` and provide instructions for setting up the other required secrets.

### Manual Deployment

To manually deploy a Phoenix release:

1. Build the release:
   ```bash
   MIX_ENV=prod mix release
   ```

2. Transfer the release to your server:
   ```bash
   tar -czf prismatic-release.tar.gz -C _build/prod/rel/prismatic .
   scp prismatic-release.tar.gz user@your-server:/tmp/
   ```

3. On the server, extract and run the release:
   ```bash
   mkdir -p /opt/prismatic
   tar -xzf /tmp/prismatic-release.tar.gz -C /opt/prismatic
   cd /opt/prismatic
   
   # Set required environment variables
   export SECRET_KEY_BASE=your_secret_key
   export DATABASE_URL=your_database_url
   export PHX_HOST=your_domain
   export PORT=4000
   
   # Start the application
   ./bin/prismatic start     # For foreground
   # or
   ./bin/prismatic daemon    # For background
   ```

## Documentation

This project uses [ExDoc](https://github.com/elixir-lang/ex_doc) for documentation generation. ExDoc produces HTML documentation from your code comments and Markdown files.

### Generating Documentation

There are multiple ways to generate documentation:

1. Using the mix task:

```bash
mix docs
```

2. Using the Justfile task:

```bash
just docs
```

Both methods will create HTML documentation in the `doc/` directory.

### Accessing Documentation

You can access the generated documentation in several ways:

1. Open `doc/index.html` directly in your browser
2. When the Phoenix server is running, visit `http://localhost:4000/doc/index.html` to view the documentation within your application
3. Use the Justfile task that provides information about accessing the documentation:

```bash
just docs-serve
```

### Writing Documentation

Documentation is written using module, function, and type documentation comments:

- Module documentation: `@moduledoc` at the top of a module
- Function documentation: `@doc` before a function
- Type documentation: `@typedoc` before a type

Example:

```elixir
defmodule MyModule do
  @moduledoc """
  This module provides functionality for...
  """
  
  @doc """
  Performs an operation with the given parameters.
  
  ## Examples
  
      iex> MyModule.my_function(1, 2)
      3
  """
  def my_function(a, b) do
    a + b
  end
end
```

### Documentation Best Practices

- Document all public functions
- Include examples in your documentation
- Keep documentation up-to-date with code changes
- Use Markdown formatting for better readability
- Add typespecs to functions for better documentation

## Changelog and Version Management

This project uses [git_ops](https://github.com/zachdaniel/git_ops) for semantic versioning and changelog generation based on conventional commit messages.

### Commit Message Format

Follow the [Conventional Commits](https://www.conventionalcommits.org/) specification for commit messages:

```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

Types include:
- `feat`: A new feature
- `fix`: A bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, etc.)
- `refactor`: Code changes that neither fix bugs nor add features
- `perf`: Performance improvements
- `test`: Adding or fixing tests
- `build`: Changes to build system or dependencies
- `ci`: Changes to CI configuration

### Initializing git_ops

Before using git_ops for the first time, you need to initialize it:

```bash
just git-ops-init
```

Or using mix directly:

```bash
mix git_ops.init
```

This will set up the necessary files and make an initial commit if needed.

### Generating Changelog

To generate or update the changelog based on commit messages:

```bash
just changelog
```

Or using mix directly:

```bash
mix git_ops.changelog
```

Note: This is a custom implementation that parses git commit history to generate a changelog.

Note: The `just changelog` command automatically runs initialization first.

### Version Management

To bump the version according to semantic versioning rules:

```bash
# Major version (breaking changes)
just version-major

# Minor version (new features)
just version-minor

# Patch version (bug fixes)
just version-patch
```

Or using mix directly:

```bash
# Major version (breaking changes)
mix prismatic.version --major

# Minor version (new features)
mix prismatic.version --minor

# Patch version (bug fixes)
mix prismatic.version --patch
```

Note: All version bumping commands automatically run initialization first.

### Release Process

To create a new release (bumps version and updates changelog):

```bash
# Major release
just release-major

# Minor release
just release-minor

# Patch release
just release-patch
```

## Learn more

* Official website: https://www.phoenixframework.org/
* Guides: https://hexdocs.pm/phoenix/overview.html
* Docs: https://hexdocs.pm/phoenix
* Forum: https://elixirforum.com/c/phoenix-forum
* Source: https://github.com/phoenixframework/phoenix
