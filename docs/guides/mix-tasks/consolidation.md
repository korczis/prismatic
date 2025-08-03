# Phase 2: Consolidation Mix Tasks

Comprehensive documentation for the Phase 2 Advanced Dependency Mapping and Conflict Resolution Mix tasks.

## Overview

The Phase 2 consolidation provides a suite of specialized Mix tasks for enterprise-grade dependency analysis, conflict resolution, and migration planning. All tasks follow industry best practices and integrate seamlessly with the Mix help system.

## Master Orchestrator Task

### `mix prismatic.consolidation`

**Purpose**: Master orchestrator that delegates to specialized subtasks

**Usage**:
```bash
# Get help
mix help prismatic.consolidation

# Use specialized tasks (recommended)
mix prismatic.consolidation analyze
mix prismatic.consolidation resolve
mix prismatic.consolidation plan

# Or use individual tasks directly
mix prismatic.consolidation.analyze
mix prismatic.consolidation.resolve
mix prismatic.consolidation.plan
```

**Best Practice**: Use individual specialized tasks for better performance and clearer intent.

## Individual Specialized Tasks

### 1. Dependency Analysis

#### `mix prismatic.consolidation.analyze`

**Purpose**: Run comprehensive dependency analysis for Phase 2 consolidation

**Key Features**:
- Deep AST-based dependency parsing
- Transitive dependency resolution
- Conflict detection and analysis
- Visualization generation (Mermaid, DOT)
- Integration with 6-app umbrella architecture

**Usage**:
```bash
# Basic analysis
mix prismatic.consolidation.analyze

# Custom projects with visualization
mix prismatic.consolidation.analyze \
  --projects="../legacy-app,../old-system" \
  --format=mermaid \
  --output-dir=analysis/results

# Deep analysis with verbose output
mix prismatic.consolidation.analyze --max-depth=15 --verbose
```

**Output Files**:
- `dependency_graph.json` - Complete dependency graph data
- `dependency_graph.mmd` - Mermaid visualization (if requested)
- `conflicts_summary.json` - Summary of detected conflicts
- `analysis_report.md` - Human-readable analysis report

**Help**: `mix help prismatic.consolidation.analyze`

### 2. Conflict Resolution

#### `mix prismatic.consolidation.resolve`

**Purpose**: Execute automated conflict resolution for 196 dependency conflicts

**Key Features**:
- 6 intelligent resolution strategies (upgrade, downgrade, pin, fork, replace, isolate)
- 90%+ automation rate achievement
- Comprehensive rollback capabilities
- Risk-aware strategy selection
- Generated automation scripts

**Usage**:
```bash
# Full automation with default settings
mix prismatic.consolidation.resolve

# Conservative approach with dry-run
mix prismatic.consolidation.resolve \
  --automation-level=semi \
  --risk-tolerance=low \
  --dry-run

# Custom strategy preference
mix prismatic.consolidation.resolve \
  --strategy-preference="upgrade,pin,isolate"
```

**Resolution Strategies**:
- **Upgrade**: Automatically upgrade to latest compatible version
- **Downgrade**: Downgrade to stable compatible version
- **Pin**: Pin to specific working version with constraints
- **Fork**: Create custom fork for incompatible dependencies
- **Replace**: Replace with compatible alternative dependency
- **Isolate**: Isolate conflicting dependencies in separate contexts

**Help**: `mix help prismatic.consolidation.resolve`

### 3. Migration Planning

#### `mix prismatic.consolidation.plan`

**Purpose**: Generate migration plan for 6-app umbrella consolidation

**Key Features**:
- Dependency-aware sequencing
- Parallel execution identification
- Risk assessment and mitigation
- Rollback procedure generation
- Automation script creation
- Integration with target architecture

**Usage**:
```bash
# Generate basic migration plan
mix prismatic.consolidation.plan

# Conservative migration plan
mix prismatic.consolidation.plan \
  --risk-tolerance=low \
  --migration-strategy=incremental \
  --parallel=false

# Comprehensive validation
mix prismatic.consolidation.plan \
  --validation-level=comprehensive \
  --generate-scripts
```

**Migration Strategies**:
- **Incremental**: Gradual migration with validation checkpoints (recommended)
- **Big-Bang**: Complete migration in single phase (higher risk)

**Help**: `mix help prismatic.consolidation.plan`

### 4. Validation Framework

#### `mix prismatic.consolidation.validate`

**Purpose**: Run comprehensive validation framework for Phase 2 consolidation

**Key Features**:
- 6-category validation system
- Pre/post-execution validation
- Architecture compliance checking
- Performance benchmarking
- Security validation
- Integration health monitoring

**Usage**:
```bash
# Run complete validation suite
mix prismatic.consolidation.validate

# Focus on specific validation area
mix prismatic.consolidation.validate --focus=dependencies

# Pre-execution validation checks
mix prismatic.consolidation.validate --pre-execution --comprehensive

# Generate detailed markdown report
mix prismatic.consolidation.validate --generate-report --format=markdown
```

**Validation Categories**:
- **Dependencies**: Resolution verification, conflict elimination
- **Architecture**: 6-app umbrella compliance, bounded contexts
- **Migration**: Prerequisites assessment, execution readiness
- **Performance**: Compilation benchmarks, runtime performance
- **Security**: Vulnerability scanning, authentication flows
- **Integration**: Cross-app communication, health monitoring

**Help**: `mix help prismatic.consolidation.validate`

### 5. Status Monitoring

#### `mix prismatic.consolidation.status`

**Purpose**: Show consolidation status and progress

**Key Features**:
- Real-time progress tracking
- System health monitoring
- Detailed status information
- Multiple output formats
- Export capabilities

**Usage**:
```bash
# Basic status check
mix prismatic.consolidation.status

# Detailed status with export
mix prismatic.consolidation.status --detailed --export

# JSON output for automation
mix prismatic.consolidation.status --format=json

# Continuous monitoring
mix prismatic.consolidation.status --refresh-interval=30
```

**Status Indicators**:
- ✅ **Complete** - Task completed successfully
- 🚀 **In Progress** - Task currently executing
- ⏳ **Pending** - Task not yet started
- ⚠️ **Warning** - Task completed with issues
- ❌ **Failed** - Task failed or has critical issues

**Help**: `mix help prismatic.consolidation.status`

### 6. Report Generation

#### `mix prismatic.consolidation.report`

**Purpose**: Generate comprehensive reports for Phase 2 consolidation

**Key Features**:
- Multiple report types (executive, technical, migration, etc.)
- Multiple output formats (markdown, HTML, JSON)
- Comprehensive metrics and analysis
- Integration with monitoring systems
- Export capabilities

**Usage**:
```bash
# Generate all reports in markdown
mix prismatic.consolidation.report

# Executive summary in HTML
mix prismatic.consolidation.report --type=executive --format=html

# Comprehensive reports with diagnostics
mix prismatic.consolidation.report \
  --comprehensive \
  --include-diagnostics \
  --export-data
```

**Report Types**:
- **Executive**: High-level business-focused summary with ROI analysis
- **Technical**: Detailed technical findings and recommendations
- **Migration**: Complete migration strategy and execution plan
- **Conflicts**: Automated conflict resolution results
- **Architecture**: 6-app umbrella compliance and validation

**Help**: `mix help prismatic.consolidation.report`

## Workflow Examples

### Complete Phase 2 Workflow

```bash
# 1. Analyze dependencies
mix prismatic.consolidation.analyze \
  --projects="../prismatic-legacy,../prismatic-old" \
  --format=mermaid \
  --verbose

# 2. Resolve conflicts
mix prismatic.consolidation.resolve \
  --automation-level=full \
  --risk-tolerance=medium \
  --dry-run

# 3. Generate migration plan
mix prismatic.consolidation.plan \
  --parallel \
  --risk-tolerance=medium \
  --generate-scripts

# 4. Validate readiness
mix prismatic.consolidation.validate \
  --comprehensive \
  --generate-report

# 5. Monitor status
mix prismatic.consolidation.status --detailed

# 6. Generate reports
mix prismatic.consolidation.report \
  --comprehensive \
  --format=markdown
```

### Development and Testing Workflow

```bash
# Development cycle with dry-runs
mix prismatic.consolidation.analyze --verbose
mix prismatic.consolidation.resolve --dry-run --verbose
mix prismatic.consolidation.plan --dry-run --verbose
mix prismatic.consolidation.validate --focus=dependencies

# Testing and validation
mix prismatic.consolidation.validate --comprehensive
mix prismatic.consolidation.status --format=json
```

### CI/CD Integration

```yaml
# .gitlab-ci.yml example
consolidation_validation:
  script:
    - mix prismatic.consolidation.validate --format=json
    - mix prismatic.consolidation.status --format=json --export
  artifacts:
    reports:
      junit: consolidation/validation/*.xml
    paths:
      - consolidation/
```

## Configuration and Environment

### Environment Variables

```bash
# Custom project paths
export PRISMATIC_LEGACY_PROJECTS="../app1,../app2,../app3"

# Output directories
export PRISMATIC_OUTPUT_DIR="./custom-output"

# Default settings
export PRISMATIC_RISK_TOLERANCE="medium"
export PRISMATIC_AUTOMATION_LEVEL="full"
```

### Configuration Files

Tasks support configuration through:
- Command-line options (highest priority)
- Environment variables
- Project configuration files
- Default values (lowest priority)

## Integration Points

### 6-App Umbrella Architecture

All tasks integrate with the target architecture:

- **prismatic_core** - Agent management, cognitive modeling, knowledge systems
- **prismatic_web** - Phoenix controllers, LiveView components, API endpoints  
- **prismatic_auth** - User management, session handling, RBAC system
- **prismatic_data** - Ecto repositories, schema management, database clustering
- **prismatic_distributed** - Node clustering, distributed PubSub, caching
- **prismatic_monitoring** - Prometheus metrics, distributed tracing, health checks

### External Systems

- **Monitoring Systems** - JSON output for dashboard integration
- **CI/CD Pipelines** - Structured exit codes and artifact generation
- **Documentation Systems** - Markdown and HTML report generation
- **Project Management** - Progress tracking and milestone reporting

## Troubleshooting

### Common Issues

1. **Task Not Found**
   ```bash
   # Solution: Compile project first
   mix compile
   mix help | grep prismatic
   ```

2. **Permission Errors**
   ```bash
   # Solution: Check and fix permissions
   ls -la consolidation/
   chmod -R 755 consolidation/
   ```

3. **Memory Issues**
   ```bash
   # Solution: Increase limits
   export ERL_MAX_PORTS=32768
   ```

4. **Dependency Resolution Timeout**
   ```bash
   # Solution: Increase timeout
   mix prismatic.consolidation.resolve --timeout=600
   ```

### Debug Mode

Enable verbose logging for any task:

```bash
mix prismatic.consolidation.analyze --verbose
mix prismatic.consolidation.resolve --verbose --dry-run
```

### Log Files

Check detailed logs:
- `logs/consolidation.log` - Main consolidation log
- `consolidation/phase2/*/logs/` - Task-specific logs

## Best Practices

### Performance Optimization

1. **Use Parallel Execution** when safe:
   ```bash
   mix prismatic.consolidation.analyze --parallel
   ```

2. **Limit Scope** for faster iteration:
   ```bash
   mix prismatic.consolidation.validate --focus=dependencies
   ```

3. **Use Dry-Run** for testing:
   ```bash
   mix prismatic.consolidation.resolve --dry-run
   ```

### Error Handling

1. **Check Status** before proceeding:
   ```bash
   mix prismatic.consolidation.status
   ```

2. **Validate Prerequisites**:
   ```bash
   mix prismatic.consolidation.validate --pre-execution
   ```

3. **Use Incremental Approach**:
   ```bash
   mix prismatic.consolidation.plan --migration-strategy=incremental
   ```

### Production Deployment

1. **Always Use Dry-Run First**:
   ```bash
   mix prismatic.consolidation.resolve --dry-run
   ```

2. **Comprehensive Validation**:
   ```bash
   mix prismatic.consolidation.validate --comprehensive
   ```

3. **Monitor Progress**:
   ```bash
   mix prismatic.consolidation.status --refresh-interval=30
   ```

4. **Generate Documentation**:
   ```bash
   mix prismatic.consolidation.report --comprehensive
   ```

---

For additional help, use `mix help prismatic.consolidation.[task]` for any specific task.