# Prismatic Mix Tasks Documentation

This directory contains comprehensive documentation for all Prismatic Mix tasks, organized by functionality and use case.

## Quick Navigation

### Phase 2: Advanced Dependency Mapping and Conflict Resolution

- **[Consolidation Tasks](./consolidation.md)** - Master orchestrator and specialized tasks
- **[Dependency Analysis](./dependency-analysis.md)** - Deep dependency graph analysis
- **[Conflict Resolution](./conflict-resolution.md)** - Automated conflict resolution
- **[Migration Planning](./migration-planning.md)** - 6-app umbrella migration
- **[Validation Framework](./validation.md)** - Comprehensive validation suite
- **[Status and Reporting](./status-reporting.md)** - Progress monitoring and reports

### Other Task Categories

- **[Code Analysis](./code-analysis.md)** - Code quality and analysis tasks
- **[Documentation](./documentation.md)** - Documentation generation tasks
- **[Testing](./testing.md)** - Test automation and quality tasks
- **[Deployment](./deployment.md)** - Deployment and release tasks

## Getting Started

### Prerequisites

- Elixir 1.17+
- Phoenix Umbrella project setup
- Access to legacy project repositories

### Basic Usage

```bash
# Get help for any task category
mix help prismatic

# Get help for specific tasks
mix help prismatic.consolidation.analyze
mix help prismatic.consolidation.resolve

# Run Phase 2 consolidation workflow
mix prismatic.consolidation.analyze
mix prismatic.consolidation.resolve
mix prismatic.consolidation.plan
mix prismatic.consolidation.validate
```

## Task Architecture

### Hierarchical Structure

All Prismatic Mix tasks follow a hierarchical namespace structure:

```
mix prismatic.*                    # Top-level namespace
├── consolidation.*               # Phase 2 consolidation tasks
│   ├── analyze                   # Dependency analysis
│   ├── resolve                   # Conflict resolution
│   ├── plan                      # Migration planning
│   ├── validate                  # Validation framework
│   ├── status                    # Status monitoring
│   └── report                    # Report generation
├── code.*                        # Code analysis tasks
├── docs.*                        # Documentation tasks
├── test.*                        # Testing tasks
└── deploy.*                      # Deployment tasks
```

### Design Principles

1. **Single Responsibility** - Each task has a focused, well-defined purpose
2. **Composability** - Tasks can be combined for complex workflows
3. **Consistency** - Unified interface patterns across all tasks
4. **Documentation** - Comprehensive help and examples for every task
5. **Industry Standards** - Follows Mix task best practices and conventions

## Common Patterns

### Help System Integration

All tasks provide comprehensive help through the Mix help system:

```bash
# List all Prismatic tasks
mix help | grep prismatic

# Get detailed help for specific tasks
mix help prismatic.consolidation.analyze
mix help prismatic.consolidation.resolve

# Get help for task groups
mix help prismatic.consolidation
```

### Consistent Option Patterns

Common options across tasks:

- `--output-dir, -o` - Specify output directory
- `--format, -f` - Choose output format (json, markdown, html)
- `--verbose, -v` - Enable verbose logging
- `--dry-run, -d` - Execute without making changes
- `--help, -h` - Show task-specific help

### Error Handling

All tasks implement consistent error handling:

- Clear error messages with actionable suggestions
- Appropriate exit codes for CI/CD integration
- Comprehensive logging for troubleshooting
- Graceful degradation when possible

## Integration Points

### CI/CD Integration

Tasks are designed for seamless CI/CD integration:

```yaml
# Example GitLab CI integration
validate_consolidation:
  script:
    - mix prismatic.consolidation.validate --format=json
  artifacts:
    reports:
      junit: consolidation/validation/*.xml
```

### Monitoring Integration

Tasks provide structured output for monitoring systems:

```bash
# JSON output for monitoring
mix prismatic.consolidation.status --format=json

# Export metrics for dashboards
mix prismatic.consolidation.report --export-data
```

### Development Workflow

Recommended development workflow:

1. **Analysis** - Start with dependency analysis
2. **Resolution** - Resolve identified conflicts
3. **Planning** - Generate migration plan
4. **Validation** - Validate readiness
5. **Execution** - Execute with monitoring
6. **Reporting** - Generate comprehensive reports

## Advanced Usage

### Custom Configuration

Tasks support extensive configuration through options and environment variables:

```bash
# Custom project paths
export PRISMATIC_LEGACY_PROJECTS="../app1,../app2,../app3"

# Custom output directories
export PRISMATIC_OUTPUT_DIR="./custom-output"

# Risk tolerance settings
export PRISMATIC_RISK_TOLERANCE="low"
```

### Parallel Execution

Many tasks support parallel execution for improved performance:

```bash
# Enable parallel processing
mix prismatic.consolidation.analyze --parallel

# Parallel conflict resolution
mix prismatic.consolidation.resolve --parallel --automation-level=full
```

### Automation Scripts

Tasks generate automation scripts for repeatable execution:

```bash
# Generate scripts during planning
mix prismatic.consolidation.plan --generate-scripts

# Execute generated scripts
./consolidation/phase2/migration/scripts/master_migration.sh
```

## Troubleshooting

### Common Issues

1. **Task Not Found**
   ```bash
   # Ensure proper compilation
   mix compile
   
   # Check task availability
   mix help | grep prismatic
   ```

2. **Permission Errors**
   ```bash
   # Check file permissions
   ls -la consolidation/
   
   # Fix permissions if needed
   chmod -R 755 consolidation/
   ```

3. **Memory Issues**
   ```bash
   # Increase memory limits
   export ERL_MAX_PORTS=32768
   export ERL_MAX_ETS_TABLES=32768
   ```

### Getting Help

1. **Task-Specific Help** - Use `mix help [task_name]`
2. **Verbose Logging** - Add `--verbose` to any task
3. **Log Files** - Check `logs/consolidation.log`
4. **Documentation** - Review task-specific documentation
5. **Examples** - Check `examples/` directory for working examples

## Contributing

### Adding New Tasks

When adding new Mix tasks:

1. Follow the hierarchical namespace pattern
2. Include comprehensive `@moduledoc` documentation
3. Add concise `@shortdoc` descriptions
4. Implement consistent option patterns
5. Include working examples
6. Add appropriate error handling
7. Update this documentation

### Testing Tasks

All tasks should include:

- Unit tests for core functionality
- Integration tests for workflows
- Documentation tests for examples
- Performance tests for large datasets

### Documentation Standards

- Use clear, actionable language
- Include working examples
- Document all options and flags
- Explain integration points
- Provide troubleshooting guidance

---

For specific task documentation, see the individual guide files in this directory.