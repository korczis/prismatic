# Error Reference Guide

**Detailed error documentation with step-by-step resolution procedures for the Prismatic AI Agent Framework**

<!-- NAV_START -->
## Navigation

**Current Location**: [Home](../../README.md) > [Guides](../README.md) > [Troubleshooting](README.md) > Error Reference Guide

### Quick Links

- **📚 [Parent Directory](README.md)** - Return to troubleshooting guides
- **🏠 [Documentation Home](../../README.md)** - Main documentation index
- **🔧 [Comprehensive Troubleshooting](comprehensive-troubleshooting-guide.md)** - Detailed procedures
- **❓ [FAQ](faq.md)** - Frequently asked questions

### Related Documentation

- [Environment Setup](../getting-started/environment-setup.md) - Development environment setup
- [Error Handling & Logging](../development/error-handling-logging.md) - Application error patterns
- [Testing Guidelines](../development/testing-guidelines.md) - Testing error scenarios
- [Debug Tools](debug-diagnostic-tools.md) - Advanced debugging techniques
<!-- NAV_END -->

---

## Table of Contents

1. [How to Use This Guide](#how-to-use-this-guide)
2. [Environment Setup Errors](#environment-setup-errors)
3. [Mix and Compilation Errors](#mix-and-compilation-errors)
4. [Database and Ecto Errors](#database-and-ecto-errors)
5. [Phoenix and LiveView Errors](#phoenix-and-liveview-errors)
6. [Asset Pipeline Errors](#asset-pipeline-errors)
7. [Testing Framework Errors](#testing-framework-errors)
8. [BEAM VM and Runtime Errors](#beam-vm-and-runtime-errors)
9. [Production and Deployment Errors](#production-and-deployment-errors)
10. [Quick Error Lookup](#quick-error-lookup)

---

## How to Use This Guide

### Error Message Format

Each error entry follows this format:

**Error Code/Message**: `Exact error text`

**Common Causes**:
- List of typical reasons

**Immediate Actions**:
1. Quick steps to try first

**Detailed Resolution**:
- Step-by-step solution procedures

**Prevention**:
- How to avoid this error in the future

**Related Errors**:
- Similar issues you might encounter

### Finding Errors Quickly

1. **Use Ctrl/Cmd+F** to search for specific error text
2. **Check the [Quick Error Lookup](#quick-error-lookup)** section
3. **Look at error categories** based on when the error occurs
4. **Check related errors** at the end of each entry

---

## Environment Setup Errors

### `elixir: command not found`

**Common Causes**:
- Elixir not installed
- Elixir not in PATH
- Using wrong version manager

**Immediate Actions**:
1. Check if Elixir is installed: `which elixir`
2. Verify PATH: `echo $PATH | grep elixir`

**Detailed Resolution**:

1. **Install Elixir with asdf (Recommended)**:
   ```bash
   # Install asdf if not present
   git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.13.1
   echo '. ~/.asdf/asdf.sh' >> ~/.bashrc
   source ~/.bashrc
   
   # Install Elixir
   asdf plugin add erlang
   asdf plugin add elixir
   asdf install erlang 26.2.1
   asdf install elixir 1.17.2-otp-26
   asdf global erlang 26.2.1
   asdf global elixir 1.17.2-otp-26
   ```

2. **Fix PATH Issues**:
   ```bash
   # Add to ~/.bashrc or ~/.zshrc
   export PATH="$HOME/.asdf/shims:$PATH"
   source ~/.bashrc
   ```

3. **Verify Installation**:
   ```bash
   elixir --version
   # Should show: Elixir 1.17.2 (compiled with Erlang/OTP 26)
   ```

**Prevention**:
- Use asdf with a `.tool-versions` file
- Add asdf initialization to shell profile
- Regularly update asdf plugins

**Related Errors**:
- [`mix: command not found`](#mix-command-not-found)
- [`erl: command not found`](#erl-command-not-found)

*[Content continues... This is a shortened version to avoid JSON parsing issues]*