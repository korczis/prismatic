<!-- NAV_START -->
<div align="center">
  <strong>🚀 New Contributor Quick-Start Guide</strong><br>
  <em>Get productive in 5 minutes - from zero to first contribution</em><br><br>
  
  <a href="../../README.md">🏠 Home</a> | 
  <a href="../README.md">📖 All Guides</a> | 
  <a href="README.md">🚀 Getting Started</a><br>
  
  <strong>Quick Links:</strong>
  <a href="first-time-setup.md">Detailed Setup</a> |
  <a href="contribution-workflow.md">Contribution Workflow</a> |
  <a href="project-orientation.md">Project Orientation</a>
</div>

### Related Documentation
- [First-Time Setup Guide](first-time-setup.md) - Detailed environment setup with verification
- [Contribution Workflow Guide](contribution-workflow.md) - Complete contribution process
- [Project Orientation Guide](project-orientation.md) - Understanding the codebase
- [Development Guide](../development/README.md) - Comprehensive development practices
<!-- NAV_END -->

# New Contributor Quick-Start Guide

> **⚡ 5-Minute Productivity Goal**  
> This guide gets you from zero to making your first contribution in under 5 minutes. For detailed setup, see the [First-Time Setup Guide](first-time-setup.md).

## Prerequisites Check (30 seconds)

Quickly verify you have the essentials:

```bash
# Check if you have the required tools
elixir --version    # Need 1.17+
node --version      # Need 18+
psql --version      # Need PostgreSQL 14+
git --version       # Need 2.30+
```

❌ **Missing tools?** → Go to [First-Time Setup Guide](first-time-setup.md)  
✅ **All good?** → Continue below!

## Lightning Setup (2 minutes)

### 1. Clone and Enter (15 seconds)
```bash
git clone https://github.com/korczis/prismatic.git
cd prismatic
```

### 2. Quick Install (60 seconds)
```bash
# Install dependencies
mix deps.get

# Setup database (will create and migrate)
mix ecto.setup

# Install frontend assets
cd apps/prismatic_web/assets && npm install && cd ../../../
```

### 3. Verify Everything Works (45 seconds)
```bash
# Compile project
mix compile

# Run quick test
mix test --max-failures=1

# Start server (Ctrl+C to stop)
mix phx.server
```

**✅ Success Check:** Visit [`http://localhost:4000`](http://localhost:4000) - you should see the Prismatic interface!

## First Contribution (2 minutes)

### Quick Win: Fix a Typo or Update Documentation

```bash
# 1. Create your feature branch
git checkout -b fix/improve-documentation

# 2. Make a small change (example)
echo "\n## My First Contribution\nI'm learning the Prismatic codebase!" >> docs/guides/getting-started/README.md

# 3. Commit with conventional format
git add .
git commit -m "docs: add first contribution note to getting started"

# 4. Push and create PR
git push origin fix/improve-documentation
```

**🎉 You're Done!** Create a Pull Request on GitHub and tag a maintainer for review.

## What's Next? (Choose Your Path)

### 🔧 Want to Code?
```bash
# Find good first issues
gh issue list --label "good first issue"

# Or explore the codebase
find apps/prismatic/lib -name "*.ex" | head -10
```
→ **Next:** [Project Orientation Guide](project-orientation.md)

### 📖 Want to Understand More?
```bash
# Generate and view documentation
mix docs
open doc/index.html
```
→ **Next:** [Contribution Workflow Guide](contribution-workflow.md)

### 🛠️ Want Robust Setup?
```bash
# Run full quality checks
mix credo
mix dialyzer
```
→ **Next:** [First-Time Setup Guide](first-time-setup.md)

## Common 5-Minute Issues

### ❌ Database Connection Error
```bash
# Quick fix - ensure PostgreSQL is running
brew services start postgresql  # macOS
sudo systemctl start postgresql # Linux

# Or use Docker
docker run --name postgres -e POSTGRES_PASSWORD=postgres -p 5432:5432 -d postgres:14
```

### ❌ Node/NPM Issues
```bash
# Reset node modules
cd apps/prismatic_web/assets
rm -rf node_modules package-lock.json
npm install
cd ../../../
```

### ❌ Mix Compilation Issues
```bash
# Clean and retry
mix deps.clean --all
mix deps.get
mix compile
```

### ❌ Port 4000 Already in Use
```bash
# Use different port
PORT=4001 mix phx.server
# Then visit http://localhost:4001
```

## Development Commands Cheatsheet

```bash
# Essential commands for daily development
mix phx.server                 # Start development server
mix test                       # Run tests
mix test --stale               # Run only changed tests
mix credo                      # Code quality check
mix format                     # Format code
mix deps.get                   # Install dependencies
mix ecto.migrate               # Run database migrations

# Prismatic-specific commands
mix prismatic.todo.scan        # Scan for TODOs
mix prismatic.docs.generate    # Generate documentation
mix prismatic.beam.inspect     # BEAM VM introspection
```

## Getting Help Fast

### 🆘 Immediate Help
- **Stuck in setup?** → [First-Time Setup Guide](first-time-setup.md) has detailed troubleshooting
- **Don't understand the code?** → [Project Orientation Guide](project-orientation.md)
- **Need to make changes?** → [Contribution Workflow Guide](contribution-workflow.md)

### 🤝 Community Support
- **GitHub Issues** - [Report bugs or ask questions](https://github.com/korczis/prismatic/issues)
- **GitHub Discussions** - [General questions and ideas](https://github.com/korczis/prismatic/discussions)
- **Code Reviews** - Learn by reviewing others' PRs

### 📚 Learn More
- [Architecture Overview](../../architecture/README.md) - Understand system design
- [Development Guide](../development/README.md) - Comprehensive development practices
- [Workflow Guide](../workflow/README.md) - Advanced workflow and automation

## Success Metrics

After following this guide, you should be able to:

- ✅ **Clone and run Prismatic locally** in under 3 minutes
- ✅ **Make your first contribution** in under 5 minutes total
- ✅ **Navigate the codebase** and understand basic structure
- ✅ **Run tests and quality checks** confidently
- ✅ **Know where to get help** when you need it

---

**💡 Pro Tip**: Don't try to understand everything at once! Start with small contributions and gradually build your knowledge through code reviews and exploration.

**🎯 Goal Achieved**: You've gone from zero to productive contributor! Your next contribution will be even faster.