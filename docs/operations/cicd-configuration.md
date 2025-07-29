# CI/CD Configuration

Comprehensive guide for setting up continuous integration and continuous deployment pipelines for the Prismatic application using various CI/CD platforms.

<!-- NAV_START -->
## Navigation

**Current Location**: [Home](../README.md) > [Operations](README.md) > CI/CD Configuration

### Quick Links

- **📚 [Parent Directory](README.md)** - Return to operations index
- **🏠 [Documentation Home](../README.md)** - Main documentation index
- **🔍 [Search Documentation](../reference/glossary.md)** - Find terms and concepts

### Related Documentation

- [Git Hooks Setup](../guides/git-hooks-setup.md) - Local development automation
- [Security Guidelines](../guides/security-guidelines.md) - CI/CD security best practices
- [Deployment Procedures](deployment-procedures.md) - Manual deployment procedures
- [Database Setup](database-setup.md) - Database migration in CI/CD
- [Monitoring Setup](monitoring-setup.md) - CI/CD pipeline monitoring
<!-- NAV_END -->

## Overview

This guide provides comprehensive instructions for setting up CI/CD pipelines for the Prismatic application. It covers GitHub Actions, GitLab CI, Jenkins, and other popular CI/CD platforms, including testing, security scanning, building, and deployment automation.

## Pipeline Architecture

### CI/CD Pipeline Stages
1. **Source Control** - Code changes trigger pipeline
2. **Testing** - Unit tests, integration tests, security scans
3. **Building** - Compile application and create artifacts
4. **Security** - Vulnerability scanning and compliance checks
5. **Staging Deployment** - Deploy to staging environment
6. **Integration Testing** - End-to-end testing on staging
7. **Production Deployment** - Deploy to production with approval
8. **Post-Deployment** - Health checks and monitoring

### Environment Strategy
```
Development → Staging → Production
     ↓           ↓         ↓
  Feature     Integration  Release
   Testing      Testing    Testing
```

## GitHub Actions Configuration

### Main Workflow Configuration

#### .github/workflows/ci.yml
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
  NODE_VERSION: 20.x
  POSTGRES_VERSION: 16

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
      
      redis:
        image: redis:7-alpine
        options: >-
          --health-cmd "redis-cli ping"
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
        ports:
          - 6379:6379

    steps:
    - name: Checkout code
      uses: actions/checkout@v4

    - name: Setup Elixir
      uses: erlef/setup-beam@v1
      with:
        elixir-version: ${{ env.ELIXIR_VERSION }}
        otp-version: ${{ env.OTP_VERSION }}

    - name: Setup Node.js
      uses: actions/setup-node@v4
      with:
        node-version: ${{ env.NODE_VERSION }}
        cache: 'npm'
        cache-dependency-path: 'assets/package-lock.json'

    - name: Cache Mix dependencies
      uses: actions/cache@v3
      with:
        path: |
          deps
          _build
        key: ${{ runner.os }}-mix-${{ env.ELIXIR_VERSION }}-${{ env.OTP_VERSION }}-${{ hashFiles('**/mix.lock') }}
        restore-keys: |
          ${{ runner.os }}-mix-${{ env.ELIXIR_VERSION }}-${{ env.OTP_VERSION }}-

    - name: Install Mix dependencies
      run: |
        mix local.hex --force
        mix local.rebar --force
        mix deps.get

    - name: Install Node.js dependencies
      run: |
        cd assets
        npm ci

    - name: Check code formatting
      run: mix format --check-formatted

    - name: Run Credo (static analysis)
      run: mix credo --strict

    - name: Check for security vulnerabilities
      run: mix sobelow --config .sobelow-conf

    - name: Compile application
      run: mix compile --warnings-as-errors

    - name: Run tests
      run: mix test --cover --export-coverage default
      env:
        DATABASE_URL: postgres://postgres:postgres@localhost:5432/prismatic_test

    - name: Generate coverage report
      run: mix test.coverage

    - name: Upload coverage to Codecov
      uses: codecov/codecov-action@v3
      with:
        files: ./cover/excoveralls.json
        fail_ci_if_error: true

    - name: Run Dialyzer (type checking)
      run: mix dialyzer --format github

  assets:
    name: Assets Build and Test
    runs-on: ubuntu-latest
    
    steps:
    - name: Checkout code
      uses: actions/checkout@v4

    - name: Setup Node.js
      uses: actions/setup-node@v4
      with:
        node-version: ${{ env.NODE_VERSION }}
        cache: 'npm'
        cache-dependency-path: 'assets/package-lock.json'

    - name: Install dependencies
      run: |
        cd assets
        npm ci

    - name: Run JavaScript tests
      run: |
        cd assets
        npm test

    - name: Run ESLint
      run: |
        cd assets
        npm run lint

    - name: Build assets
      run: |
        cd assets
        npm run build

    - name: Check bundle size
      run: |
        cd assets
        npm run analyze
```

### Deployment Workflow

#### .github/workflows/deploy.yml
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
  build:
    name: Build Release
    runs-on: ubuntu-latest
    outputs:
      image-tag: ${{ steps.meta.outputs.tags }}
      image-digest: ${{ steps.build.outputs.digest }}
    
    steps:
    - name: Checkout code
      uses: actions/checkout@v4

    - name: Setup Docker Buildx
      uses: docker/setup-buildx-action@v3

    - name: Login to Container Registry
      uses: docker/login-action@v3
      with:
        registry: ghcr.io
        username: ${{ github.actor }}
        password: ${{ secrets.GITHUB_TOKEN }}

    - name: Extract metadata
      id: meta
      uses: docker/metadata-action@v5
      with:
        images: ghcr.io/${{ github.repository }}
        tags: |
          type=ref,event=branch
          type=ref,event=pr
          type=semver,pattern={{version}}
          type=semver,pattern={{major}}.{{minor}}
          type=sha,prefix={{branch}}-

    - name: Build and push Docker image
      id: build
      uses: docker/build-push-action@v5
      with:
        context: .
        platforms: linux/amd64,linux/arm64
        push: true
        tags: ${{ steps.meta.outputs.tags }}
        labels: ${{ steps.meta.outputs.labels }}
        cache-from: type=gha
        cache-to: type=gha,mode=max
        build-args: |
          MIX_ENV=prod
          NODE_ENV=production

  deploy-staging:
    name: Deploy to Staging
    runs-on: ubuntu-latest
    needs: build
    environment: staging
    if: github.event.inputs.environment == 'staging' || github.event_name == 'push'
    
    steps:
    - name: Deploy to staging
      uses: appleboy/ssh-action@v1.0.0
      with:
        host: ${{ secrets.STAGING_HOST }}
        username: ${{ secrets.STAGING_USER }}
        key: ${{ secrets.STAGING_SSH_KEY }}
        script: |
          cd /opt/prismatic
          docker pull ${{ needs.build.outputs.image-tag }}
          docker-compose -f docker-compose.staging.yml up -d --no-deps app
          docker-compose -f docker-compose.staging.yml exec -T app bin/prismatic eval "Prismatic.Release.migrate()"

    - name: Run smoke tests
      run: |
        sleep 30
        curl -f https://staging.prismatic.example.com/api/health

  deploy-production:
    name: Deploy to Production
    runs-on: ubuntu-latest
    needs: [build, deploy-staging]
    environment: production
    if: github.event.inputs.environment == 'production' || github.event_name == 'release'
    
    steps:
    - name: Deploy to production
      uses: appleboy/ssh-action@v1.0.0
      with:
        host: ${{ secrets.PRODUCTION_HOST }}
        username: ${{ secrets.PRODUCTION_USER }}
        key: ${{ secrets.PRODUCTION_SSH_KEY }}
        script: |
          cd /opt/prismatic
          docker pull ${{ needs.build.outputs.image-tag }}
          docker-compose up -d --no-deps app
          docker-compose exec -T app bin/prismatic eval "Prismatic.Release.migrate()"

    - name: Run production health checks
      run: |
        sleep 60
        curl -f https://prismatic.example.com/api/health

    - name: Notify deployment
      uses: 8398a7/action-slack@v3
      with:
        status: success
        text: 'Production deployment completed successfully'
      env:
        SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}
```

### Security Scanning Workflow

#### .github/workflows/security.yml
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
  dependency-check:
    name: Dependency Vulnerability Check
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

    - name: Run mix audit
      run: mix deps.audit

    - name: Run npm audit
      run: |
        cd assets
        npm audit --audit-level=moderate

  code-security:
    name: Code Security Analysis
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

    - name: Run Sobelow security check
      run: mix sobelow --config .sobelow-conf --exit Low

  container-security:
    name: Container Security Scan
    runs-on: ubuntu-latest
    
    steps:
    - name: Checkout code
      uses: actions/checkout@v4

    - name: Build Docker image
      run: docker build -t prismatic:security-test .

    - name: Run Trivy vulnerability scanner
      uses: aquasecurity/trivy-action@master
      with:
        image-ref: 'prismatic:security-test'
        format: 'sarif'
        output: 'trivy-results.sarif'

    - name: Upload Trivy scan results
      uses: github/codeql-action/upload-sarif@v2
      if: always()
      with:
        sarif_file: 'trivy-results.sarif'

  secrets-scan:
    name: Secrets Detection
    runs-on: ubuntu-latest
    
    steps:
    - name: Checkout code
      uses: actions/checkout@v4
      with:
        fetch-depth: 0

    - name: Run GitLeaks
      uses: gitleaks/gitleaks-action@v2
      env:
        GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

## GitLab CI Configuration

### .gitlab-ci.yml
```yaml
stages:
  - test
  - security
  - build
  - deploy
  - post-deploy

variables:
  MIX_ENV: test
  POSTGRES_DB: prismatic_test
  POSTGRES_USER: postgres
  POSTGRES_PASSWORD: postgres
  REDIS_URL: redis://redis:6379

# Templates
.elixir-template: &elixir-template
  image: elixir:1.16.0-alpine
  services:
    - postgres:16-alpine
    - redis:7-alpine
  before_script:
    - apk add --no-cache build-base git
    - mix local.hex --force
    - mix local.rebar --force
    - mix deps.get

# Test Stage
unit-tests:
  <<: *elixir-template
  stage: test
  script:
    - mix format --check-formatted
    - mix credo --strict
    - mix compile --warnings-as-errors
    - mix test --cover
  coverage: '/\[TOTAL\]\s+(\d+\.\d+)%/'
  artifacts:
    reports:
      coverage_report:
        coverage_format: cobertura
        path: cover/cobertura.xml
    paths:
      - cover/
    expire_in: 1 week
  rules:
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"
    - if: $CI_COMMIT_BRANCH == "main"
    - if: $CI_COMMIT_BRANCH == "develop"

integration-tests:
  <<: *elixir-template
  stage: test
  script:
    - mix test test/integration --max-failures 1
  rules:
    - if: $CI_COMMIT_BRANCH == "main"
    - if: $CI_COMMIT_BRANCH == "develop"

assets-test:
  image: node:20-alpine
  stage: test
  before_script:
    - cd assets
    - npm ci
  script:
    - npm test
    - npm run lint
    - npm run build
  artifacts:
    paths:
      - priv/static/
    expire_in: 1 hour
  rules:
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"
    - if: $CI_COMMIT_BRANCH == "main"
    - if: $CI_COMMIT_BRANCH == "develop"

# Security Stage
dependency-audit:
  <<: *elixir-template
  stage: security
  script:
    - mix deps.audit
    - cd assets && npm audit --audit-level=moderate
  allow_failure: true
  rules:
    - if: $CI_COMMIT_BRANCH == "main"
    - if: $CI_COMMIT_BRANCH == "develop"

security-scan:
  <<: *elixir-template
  stage: security
  script:
    - mix sobelow --config .sobelow-conf --exit Low
  artifacts:
    reports:
      sast: sobelow-report.json
  allow_failure: true
  rules:
    - if: $CI_COMMIT_BRANCH == "main"
    - if: $CI_COMMIT_BRANCH == "develop"

container-scan:
  stage: security
  image: docker:stable
  services:
    - docker:dind
  before_script:
    - docker build -t $CI_REGISTRY_IMAGE:$CI_COMMIT_SHA .
  script:
    - docker run --rm -v /var/run/docker.sock:/var/run/docker.sock 
      -v $PWD:/tmp aquasec/trivy:latest image 
      --format template --template "@contrib/sarif.tpl" 
      -o /tmp/trivy-report.sarif 
      $CI_REGISTRY_IMAGE:$CI_COMMIT_SHA
  artifacts:
    reports:
      sast: trivy-report.sarif
  rules:
    - if: $CI_COMMIT_BRANCH == "main"

# Build Stage
docker-build:
  stage: build
  image: docker:stable
  services:
    - docker:dind
  before_script:
    - docker login -u $CI_REGISTRY_USER -p $CI_REGISTRY_PASSWORD $CI_REGISTRY
  script:
    - docker build --pull -t $CI_REGISTRY_IMAGE:$CI_COMMIT_SHA .
    - docker push $CI_REGISTRY_IMAGE:$CI_COMMIT_SHA
    - |
      if [ "$CI_COMMIT_BRANCH" == "main" ]; then
        docker tag $CI_REGISTRY_IMAGE:$CI_COMMIT_SHA $CI_REGISTRY_IMAGE:latest
        docker push $CI_REGISTRY_IMAGE:latest
      fi
  rules:
    - if: $CI_COMMIT_BRANCH == "main"
    - if: $CI_COMMIT_BRANCH == "develop"

# Deploy Stage
deploy-staging:
  stage: deploy
  image: alpine:latest
  before_script:
    - apk add --no-cache openssh-client curl
    - eval $(ssh-agent -s)
    - echo "$STAGING_PRIVATE_KEY" | tr -d '\r' | ssh-add -
    - mkdir -p ~/.ssh
    - chmod 700 ~/.ssh
    - ssh-keyscan $STAGING_HOST >> ~/.ssh/known_hosts
  script:
    - |
      ssh $STAGING_USER@$STAGING_HOST << EOF
        cd /opt/prismatic
        docker pull $CI_REGISTRY_IMAGE:$CI_COMMIT_SHA
        docker-compose -f docker-compose.staging.yml up -d --no-deps app
        docker-compose -f docker-compose.staging.yml exec -T app bin/prismatic eval "Prismatic.Release.migrate()"
      EOF
    - sleep 30
    - curl -f https://staging.prismatic.example.com/api/health
  environment:
    name: staging
    url: https://staging.prismatic.example.com
  rules:
    - if: $CI_COMMIT_BRANCH == "develop"

deploy-production:
  stage: deploy
  image: alpine:latest
  before_script:
    - apk add --no-cache openssh-client curl
    - eval $(ssh-agent -s)
    - echo "$PRODUCTION_PRIVATE_KEY" | tr -d '\r' | ssh-add -
    - mkdir -p ~/.ssh
    - chmod 700 ~/.ssh
    - ssh-keyscan $PRODUCTION_HOST >> ~/.ssh/known_hosts
  script:
    - |
      ssh $PRODUCTION_USER@$PRODUCTION_HOST << EOF
        cd /opt/prismatic
        docker pull $CI_REGISTRY_IMAGE:$CI_COMMIT_SHA
        docker-compose up -d --no-deps app
        docker-compose exec -T app bin/prismatic eval "Prismatic.Release.migrate()"
      EOF
    - sleep 60
    - curl -f https://prismatic.example.com/api/health
  environment:
    name: production
    url: https://prismatic.example.com
  when: manual
  rules:
    - if: $CI_COMMIT_BRANCH == "main"

# Post-Deploy Stage
smoke-tests:
  stage: post-deploy
  image: alpine:latest
  before_script:
    - apk add --no-cache curl jq
  script:
    - ./scripts/smoke_tests.sh $ENVIRONMENT_URL
  rules:
    - if: $CI_COMMIT_BRANCH == "main"
    - if: $CI_COMMIT_BRANCH == "develop"
  variables:
    ENVIRONMENT_URL: $CI_ENVIRONMENT_URL
```

## Jenkins Pipeline Configuration

### Jenkinsfile
```groovy
pipeline {
    agent any
    
    environment {
        MIX_ENV = 'test'
        ELIXIR_VERSION = '1.16.0'
        OTP_VERSION = '26.2.1'
        DOCKER_REGISTRY = 'your-registry.com'
        DOCKER_IMAGE = "${DOCKER_REGISTRY}/prismatic"
    }
    
    stages {
        stage('Checkout') {
            steps {
                checkout scm
                script {
                    env.GIT_COMMIT_SHORT = sh(
                        script: "git rev-parse --short HEAD",
                        returnStdout: true
                    ).trim()
                }
            }
        }
        
        stage('Setup') {
            parallel {
                stage('Elixir Setup') {
                    steps {
                        sh '''
                            asdf install elixir ${ELIXIR_VERSION}
                            asdf install erlang ${OTP_VERSION}
                            asdf global elixir ${ELIXIR_VERSION}
                            asdf global erlang ${OTP_VERSION}
                            mix local.hex --force
                            mix local.rebar --force
                        '''
                    }
                }
                stage('Node Setup') {
                    steps {
                        sh '''
                            cd assets
                            npm ci
                        '''
                    }
                }
            }
        }
        
        stage('Dependencies') {
            steps {
                sh 'mix deps.get'
                sh 'mix deps.compile'
            }
        }
        
        stage('Code Quality') {
            parallel {
                stage('Format Check') {
                    steps {
                        sh 'mix format --check-formatted'
                    }
                }
                stage('Credo') {
                    steps {
                        sh 'mix credo --strict'
                    }
                }
                stage('Dialyzer') {
                    steps {
                        sh 'mix dialyzer'
                    }
                }
                stage('Security Check') {
                    steps {
                        sh 'mix sobelow --config .sobelow-conf'
                    }
                }
            }
        }
        
        stage('Tests') {
            parallel {
                stage('Unit Tests') {
                    steps {
                        sh 'mix test --cover'
                    }
                    post {
                        always {
                            publishHTML([
                                allowMissing: false,
                                alwaysLinkToLastBuild: false,
                                keepAll: true,
                                reportDir: 'cover',
                                reportFiles: 'excoveralls.html',
                                reportName: 'Coverage Report'
                            ])
                        }
                    }
                }
                stage('Asset Tests') {
                    steps {
                        sh '''
                            cd assets
                            npm test
                            npm run lint
                        '''
                    }
                }
            }
        }
        
        stage('Build') {
            when {
                anyOf {
                    branch 'main'
                    branch 'develop'
                    changeRequest()
                }
            }
            steps {
                script {
                    def imageTag = "${env.DOCKER_IMAGE}:${env.GIT_COMMIT_SHORT}"
                    docker.build(imageTag)
                    
                    if (env.BRANCH_NAME == 'main') {
                        def latestTag = "${env.DOCKER_IMAGE}:latest"
                        docker.build(latestTag)
                    }
                }
            }
        }
        
        stage('Deploy to Staging') {
            when {
                branch 'develop'
            }
            steps {
                script {
                    def imageTag = "${env.DOCKER_IMAGE}:${env.GIT_COMMIT_SHORT}"
                    
                    sshagent(['staging-ssh-key']) {
                        sh """
                            ssh -o StrictHostKeyChecking=no deploy@staging.example.com '
                                cd /opt/prismatic &&
                                docker pull ${imageTag} &&
                                docker-compose -f docker-compose.staging.yml up -d --no-deps app &&
                                docker-compose -f docker-compose.staging.yml exec -T app bin/prismatic eval "Prismatic.Release.migrate()"
                            '
                        """
                    }
                    
                    // Health check
                    sleep 30
                    sh 'curl -f https://staging.prismatic.example.com/api/health'
                }
            }
        }
        
        stage('Deploy to Production') {
            when {
                branch 'main'
            }
            steps {
                input message: 'Deploy to production?', ok: 'Deploy'
                
                script {
                    def imageTag = "${env.DOCKER_IMAGE}:${env.GIT_COMMIT_SHORT}"
                    
                    sshagent(['production-ssh-key']) {
                        sh """
                            ssh -o StrictHostKeyChecking=no deploy@production.example.com '
                                cd /opt/prismatic &&
                                docker pull ${imageTag} &&
                                docker-compose up -d --no-deps app &&
                                docker-compose exec -T app bin/prismatic eval "Prismatic.Release.migrate()"
                            '
                        """
                    }
                    
                    // Health check
                    sleep 60
                    sh 'curl -f https://prismatic.example.com/api/health'
                }
            }
        }
    }
    
    post {
        always {
            publishTestResults testResultsPattern: '_build/test/lib/*/test-junit-report.xml'
            
            archiveArtifacts artifacts: '_build/prod/rel/prismatic/releases/*/prismatic.tar.gz', 
                           allowEmptyArchive: true
        }
        
        success {
            slackSend channel: '#deployments',
                     color: 'good',
                     message: "✅ Pipeline succeeded for ${env.JOB_NAME} - ${env.BUILD_NUMBER}"
        }
        
        failure {
            slackSend channel: '#alerts',
                     color: 'danger',
                     message: "❌ Pipeline failed for ${env.JOB_NAME} - ${env.BUILD_NUMBER}"
        }
    }
}
```

## Docker Configuration

### Multi-stage Dockerfile
```dockerfile
# Build stage
FROM hexpm/elixir:1.16.0-erlang-26.2.1-alpine-3.18.4 AS build

# Install build dependencies
RUN apk add --no-cache \
    build-base \
    npm \
    git \
    python3

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
RUN mix assets.deploy

# Compile the release
RUN mix release

# Application stage
FROM alpine:3.18.4 AS app

# Install runtime dependencies
RUN apk add --no-cache \
    openssl \
    ncurses-libs \
    libstdc++

WORKDIR /app

# Create app user
RUN addgroup -g 1000 -S app && \
    adduser -u 1000 -S app -G app

# Copy built application
COPY --from=build --chown=app:app /app/_build/prod/rel/prismatic ./

USER app

# Expose port
EXPOSE 4000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:4000/api/health || exit 1

CMD ["bin/prismatic", "start"]
```

### Production Docker Compose
```yaml
# docker-compose.prod.yml
version: '3.8'

services:
  app:
    image: ${DOCKER_REGISTRY}/prismatic:${IMAGE_TAG}
    restart: unless-stopped
    ports:
      - "4000:4000"
    environment:
      - DATABASE_URL=${DATABASE_URL}
      - SECRET_KEY_BASE=${SECRET_KEY_BASE}
      - PHX_HOST=${PHX_HOST}
      - REDIS_URL=${REDIS_URL}
    depends_on:
      - db
      - redis
    volumes:
      - app_uploads:/app/uploads
    networks:
      - app_network
    deploy:
      replicas: 2
      resources:
        limits:
          cpus: '1.0'
          memory: 1G
        reservations:
          cpus: '0.5'
          memory: 512M

  db:
    image: postgres:16-alpine
    restart: unless-stopped
    environment:
      - POSTGRES_DB=${POSTGRES_DB}
      - POSTGRES_USER=${POSTGRES_USER}
      - POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    networks:
      - app_network

  redis:
    image: redis:7-alpine
    restart: unless-stopped
    volumes:
      - redis_data:/data
    networks:
      - app_network

  nginx:
    image: nginx:alpine
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
      - ./ssl:/etc/nginx/ssl:ro
      - app_uploads:/var/www/uploads:ro
    depends_on:
      - app
    networks:
      - app_network

volumes:
  postgres_data:
  redis_data:
  app_uploads:

networks:
  app_network:
    driver: bridge
```

## Testing in CI/CD

### Test Configuration

#### Test Database Setup
```elixir
# config/test.exs
config :prismatic, Prismatic.Repo,
  username: System.get_env("POSTGRES_USER", "postgres"),
  password: System.get_env("POSTGRES_PASSWORD", "postgres"),
  hostname: System.get_env("POSTGRES_HOST", "localhost"),
  database: "prismatic_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: String.to_integer(System.get_env("POOL_SIZE", "10"))
```

#### Parallel Testing Setup
```bash
# Run tests in parallel
export MIX_TEST_PARTITION=1
mix test --partitions 4

# In CI with dynamic partitioning
for i in $(seq 1 $CI_NODE_TOTAL); do
  MIX_TEST_PARTITION=$i mix test --partitions $CI_NODE_TOTAL &
done
wait
```

### Integration Testing

#### End-to-End Test Script
```bash
#!/bin/bash
# scripts/e2e_tests.sh

set -e

ENVIRONMENT_URL=${1:-"http://localhost:4000"}

echo "Running E2E tests against $ENVIRONMENT_URL"

# Health check
curl -f "$ENVIRONMENT_URL/api/health"

# API functionality tests
curl -f -X POST "$ENVIRONMENT_URL/api/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"testpass123"}'

# Database connectivity
curl -f "$ENVIRONMENT_URL/api/users" \
  -H "Authorization: Bearer $AUTH_TOKEN"

# Static assets
curl -f "$ENVIRONMENT_URL/assets/app.js"
curl -f "$ENVIRONMENT_URL/assets/app.css"

echo "All E2E tests passed!"
```

## Security in CI/CD

### Secrets Management

#### GitHub Actions Secrets
```yaml
# Using environment secrets
- name: Deploy to production
  env:
    DATABASE_URL: ${{ secrets.DATABASE_URL }}
    SECRET_KEY_BASE: ${{ secrets.SECRET_KEY_BASE }}
    STRIPE_SECRET_KEY: ${{ secrets.STRIPE_SECRET_KEY }}
  run: |
    echo "Deploying with secure environment variables"
```

#### HashiCorp Vault Integration
```yaml
# Using Vault for secrets
- name: Import secrets from Vault
  uses: hashicorp/vault-action@v2.7.3
  with:
    url: https://vault.example.com:8200
    method: jwt
    role: ci-cd-role
    secrets: |
      secret/data/prismatic/prod database_url | DATABASE_URL ;
      secret/data/prismatic/prod secret_key_base | SECRET_KEY_BASE
```

### SAST/DAST Integration

#### Static Application Security Testing
```yaml
- name: Run CodeQL Analysis
  uses: github/codeql-action/init@v2
  with:
    languages: javascript

- name: Run SAST with Semgrep
  uses: returntocorp/semgrep-action@v1
  with:
    config: >-
      p/security-audit
      p/secrets
      p/owasp-top-ten
```

#### Dynamic Application Security Testing
```yaml
- name: DAST with OWASP ZAP
  uses: zaproxy/action-full-scan@v0.4.0
  with:
    target: 'https://staging.prismatic.example.com'
    rules_file_name: '.zap/rules.tsv'
    cmd_options: '-a'
```

## Monitoring and Alerting

### Pipeline Monitoring

#### Metrics Collection
```yaml
- name: Collect pipeline metrics
  run: |
    echo "pipeline_duration_seconds $(($SECONDS - $START_TIME))" >> metrics.txt
    echo "test_count $(grep -c 'test' test_results.xml)" >> metrics.txt
    echo "coverage_percentage $COVERAGE" >> metrics.txt

- name: Send metrics to monitoring
  run: |
    curl -X POST https://metrics.example.com/api/metrics \
      -H "Authorization: Bearer $METRICS_TOKEN" \
      -d @metrics.txt
```

#### Notification Setup
```yaml
- name: Notify deployment success
  uses: 8398a7/action-slack@v3
  if: success()
  with:
    status: success
    channel: '#deployments'
    text: |
      🚀 Deployment to ${{ github.event.inputs.environment }} completed successfully!
      
      **Commit:** ${{ github.sha }}
      **Author:** ${{ github.actor }}
      **Duration:** ${{ steps.deploy.outputs.duration }}
  env:
    SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}

- name: Notify deployment failure
  uses: 8398a7/action-slack@v3
  if: failure()
  with:
    status: failure
    channel: '#alerts'
    text: |
      ❌ Deployment to ${{ github.event.inputs.environment }} failed!
      
      **Error:** Check the pipeline logs for details
      **Commit:** ${{ github.sha }}
      **Author:** ${{ github.actor }}
```

## Performance and Optimization

### Cache Strategies

#### Dependency Caching
```yaml
# GitHub Actions caching
- name: Cache Mix dependencies
  uses: actions/cache@v3
  with:
    path: |
      deps
      _build
    key: ${{ runner.os }}-mix-${{ hashFiles('**/mix.lock') }}
    restore-keys: |
      ${{ runner.os }}-mix-

# Docker layer caching
- name: Build with cache
  uses: docker/build-push-action@v5
  with:
    cache-from: type=gha
    cache-to: type=gha,mode=max
```

#### Build Optimization
```dockerfile
# Multi-stage build with dependency caching
FROM elixir:1.16.0-alpine AS deps

COPY mix.exs mix.lock ./
COPY apps/*/mix.exs apps/*/
RUN mix deps.get --only prod

FROM deps AS build
COPY . .
RUN mix compile && mix release
```

### Parallel Execution

#### Matrix Builds
```yaml
strategy:
  matrix:
    elixir: ['1.15.0', '1.16.0']
    otp: ['25.3', '26.2']
    include:
      - elixir: '1.16.0'
        otp: '26.2'
        coverage: true
```

## Related Documentation

- [Git Hooks Setup](../guides/git-hooks-setup.md) - Local development automation that complements CI/CD
- [Security Guidelines](../guides/security-guidelines.md) - Security best practices for CI/CD pipelines
- [Deployment Procedures](deployment-procedures.md) - Manual deployment procedures and rollback strategies
- [Database Setup](database-setup.md) - Database configuration and migration in CI/CD
- [Monitoring Setup](monitoring-setup.md) - Monitoring and alerting for CI/CD pipelines and deployments
- [Performance Optimization](../guides/performance-optimization.md) - Performance considerations in automated deployments

---

**Effective CI/CD pipelines are crucial for maintaining code quality, security, and deployment reliability. Regular review and optimization of pipeline configurations ensures continued effectiveness as the project evolves.**