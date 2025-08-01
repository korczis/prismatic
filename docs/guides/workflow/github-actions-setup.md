# GitHub Actions Setup Guide

Comprehensive guide for setting up and configuring GitHub Actions CI/CD workflows for the Prismatic project.

<!-- NAV_START -->
## Navigation

**Current Location**: [Home](../README.md) > [Guides](README.md) > GitHub Actions Setup

### Quick Links

- **📚 [Parent Directory](README.md)** - Return to guides index
- **🏠 [Documentation Home](../README.md)** - Main documentation index
- **🔍 [Search Documentation](../reference/glossary.md)** - Find terms and concepts

### Related Documentation

- [Git Hooks Complete](git-hooks-complete.md) - Local development automation
- [CI/CD Implementation](ci-cd-implementation.md) - Complete CI/CD workflows
- [Security Guidelines](security-guidelines.md) - CI/CD security best practices
- [Deployment Procedures](../operations/deployment-procedures.md) - Deployment automation
- [Performance Optimization](performance-optimization.md) - Performance checks in CI
<!-- NAV_END -->

## Overview

This guide covers the setup and configuration of GitHub Actions workflows for the Prismatic project, including automated testing, security scanning, building, and deployment processes.

## Basic Workflow Setup

### Prerequisites

- GitHub repository with admin access
- Repository secrets configured for deployment
- Understanding of YAML syntax
- Familiarity with GitHub Actions concepts

### Workflow File Structure

GitHub Actions workflows are defined in `.github/workflows/` directory:

```
.github/
└── workflows/
    ├── ci.yml              # Continuous integration
    ├── deploy.yml          # Deployment workflows
    ├── security.yml        # Security scanning
    └── documentation.yml   # Documentation validation
```

## Core Workflows

### Continuous Integration Workflow

Create `.github/workflows/ci.yml`:

```yaml
name: Continuous Integration

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main, develop ]

env:
  MIX_ENV: test
  ELIXIR_VERSION: 1.16.0
  OTP_VERSION: 26.2.1

jobs:
  test:
    name: Test Suite
    runs-on: ubuntu-latest
    
    services:
      postgres:
        image: postgres:16
        env:
          POSTGRES_USER: postgres
          POSTGRES_PASSWORD: postgres
          POSTGRES_DB: prismatic_test
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
        ports:
          - 5432:5432

    steps:
    - name: Checkout code
      uses: actions/checkout@v4

    - name: Setup Elixir
      uses: erlef/setup-beam@v1
      with:
        elixir-version: ${{ env.ELIXIR_VERSION }}
        otp-version: ${{ env.OTP_VERSION }}

    - name: Cache Mix dependencies
      uses: actions/cache@v3
      with:
        path: |
          deps
          _build
        key: ${{ runner.os }}-mix-${{ hashFiles('**/mix.lock') }}
        restore-keys: |
          ${{ runner.os }}-mix-

    - name: Install dependencies
      run: |
        mix local.hex --force
        mix local.rebar --force
        mix deps.get

    - name: Check formatting
      run: mix format --check-formatted

    - name: Run Credo
      run: mix credo --strict

    - name: Run tests
      run: mix test --cover
      env:
        DATABASE_URL: postgres://postgres:postgres@localhost:5432/prismatic_test
```

### Deployment Workflow

Create `.github/workflows/deploy.yml`:

```yaml
name: Deploy to Production

on:
  release:
    types: [published]
  workflow_dispatch:
    inputs:
      environment:
        description: 'Deployment environment'
        required: true
        default: 'staging'
        type: choice
        options:
        - staging
        - production

jobs:
  deploy:
    name: Deploy Application
    runs-on: ubuntu-latest
    environment: ${{ github.event.inputs.environment || 'production' }}
    
    steps:
    - name: Checkout code
      uses: actions/checkout@v4

    - name: Setup Elixir
      uses: erlef/setup-beam@v1
      with:
        elixir-version: 1.16.0
        otp-version: 26.2.1

    - name: Build release
      run: |
        mix local.hex --force
        mix local.rebar --force
        mix deps.get --only prod
        MIX_ENV=prod mix compile
        MIX_ENV=prod mix assets.deploy
        MIX_ENV=prod mix release

    - name: Deploy to server
      run: |
        echo "Deployment logic would go here"
        echo "Environment: ${{ github.event.inputs.environment || 'production' }}"
```

## Security Scanning

### Security Workflow

Create `.github/workflows/security.yml`:

```yaml
name: Security Scanning

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]
  schedule:
    - cron: '0 6 * * 1'  # Weekly on Monday

jobs:
  security-audit:
    name: Security Audit
    runs-on: ubuntu-latest
    
    steps:
    - name: Checkout code
      uses: actions/checkout@v4

    - name: Setup Elixir
      uses: erlef/setup-beam@v1
      with:
        elixir-version: 1.16.0
        otp-version: 26.2.1

    - name: Install dependencies
      run: |
        mix local.hex --force
        mix local.rebar --force
        mix deps.get

    - name: Run dependency audit
      run: mix deps.audit

    - name: Run Sobelow security check
      run: mix sobelow --config .sobelow-conf
```

## Environment Configuration

### Repository Secrets

Configure the following secrets in your GitHub repository:

#### Production Secrets
- `DATABASE_URL` - Production database connection string
- `SECRET_KEY_BASE` - Phoenix secret key base
- `DEPLOYMENT_SSH_KEY` - SSH key for deployment server access
- `DEPLOYMENT_HOST` - Production server hostname
- `DEPLOYMENT_USER` - Deployment user account

#### Optional Secrets
- `SLACK_WEBHOOK_URL` - For deployment notifications
- `CODECOV_TOKEN` - For code coverage reporting
- `HONEYBADGER_API_KEY` - For error monitoring

### Environment Variables

Set environment variables for different deployment targets:

```yaml
# Production environment
DATABASE_URL: ${{ secrets.DATABASE_URL }}
SECRET_KEY_BASE: ${{ secrets.SECRET_KEY_BASE }}
PHX_HOST: your-domain.com
MIX_ENV: prod
```

## Advanced Features

### Matrix Testing

Test against multiple Elixir/OTP versions:

```yaml
strategy:
  matrix:
    elixir: ['1.15.7', '1.16.0']
    otp: ['25.3', '26.2']
    include:
      - elixir: '1.16.0'
        otp: '26.2'
        coverage: true
```

### Conditional Execution

Run jobs based on conditions:

```yaml
- name: Deploy to production
  if: github.ref == 'refs/heads/main' && github.event_name == 'push'
  run: echo "Deploying to production"
```

### Artifact Management

Store build artifacts:

```yaml
- name: Upload build artifacts
  uses: actions/upload-artifact@v3
  with:
    name: release-artifacts
    path: _build/prod/rel/prismatic/releases/*/prismatic.tar.gz
```

## Monitoring and Notifications

### Slack Integration

Add Slack notifications:

```yaml
- name: Notify Slack on failure
  if: failure()
  uses: 8398a7/action-slack@v3
  with:
    status: failure
    channel: '#alerts'
    text: 'GitHub Actions workflow failed!'
  env:
    SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}
```

### Status Badges

Add status badges to README:

```markdown
[![CI](https://github.com/username/prismatic/workflows/CI/badge.svg)](https://github.com/username/prismatic/actions)
[![Deploy](https://github.com/username/prismatic/workflows/Deploy/badge.svg)](https://github.com/username/prismatic/actions)
```

## Troubleshooting

### Common Issues

#### Dependency Caching Problems
```yaml
# Clear cache by updating the cache key
key: ${{ runner.os }}-mix-v2-${{ hashFiles('**/mix.lock') }}
```

#### Database Connection Issues
```yaml
# Wait for services to be ready
- name: Wait for PostgreSQL
  run: |
    until pg_isready -h localhost -p 5432 -U postgres; do
      echo "Waiting for PostgreSQL..."
      sleep 2
    done
```

#### Permission Errors
```bash
# Fix file permissions
chmod +x scripts/deploy.sh
```

### Debugging Workflows

Enable debug logging:

```yaml
env:
  ACTIONS_STEP_DEBUG: true
  ACTIONS_RUNNER_DEBUG: true
```

## Best Practices

### Security Best Practices

1. **Never commit secrets** - Use GitHub secrets for sensitive data
2. **Limit permissions** - Use least privilege principle
3. **Pin action versions** - Use specific versions instead of `@main`
4. **Validate inputs** - Sanitize workflow inputs
5. **Use environment protection** - Require reviews for production deployments

### Performance Optimization

1. **Cache dependencies** - Cache Mix and npm dependencies
2. **Parallel execution** - Run independent jobs in parallel
3. **Conditional workflows** - Skip unnecessary steps
4. **Optimize Docker layers** - Use multi-stage builds efficiently

### Maintenance

1. **Regular updates** - Keep actions and dependencies updated
2. **Monitor usage** - Track GitHub Actions usage and costs
3. **Clean up artifacts** - Set appropriate retention policies
4. **Review workflows** - Regularly audit workflow configurations

## Related Documentation

- [Git Hooks Complete](git-hooks-complete.md) - Local development automation that complements GitHub Actions
- [CI/CD Implementation](ci-cd-implementation.md) - Complete CI/CD pipeline documentation including other platforms
- [Security Guidelines](security-guidelines.md) - Security best practices for CI/CD pipelines
- [Deployment Procedures](../operations/deployment-procedures.md) - Manual deployment procedures and rollback strategies
- [Performance Optimization](performance-optimization.md) - Performance testing and optimization in CI/CD

---

**GitHub Actions provides powerful automation capabilities for the Prismatic project. Regular maintenance and monitoring ensure reliable and efficient CI/CD processes.**