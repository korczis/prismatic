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

## Learn more

* Official website: https://www.phoenixframework.org/
* Guides: https://hexdocs.pm/phoenix/overview.html
* Docs: https://hexdocs.pm/phoenix
* Forum: https://elixirforum.com/c/phoenix-forum
* Source: https://github.com/phoenixframework/phoenix
