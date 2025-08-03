#!/bin/bash
# Quality Gates for Consolidation

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$PROJECT_ROOT"

echo "🔍 Running quality gates..."

# Code formatting
echo "📝 Checking code formatting..."
if mix format --check-formatted; then
    echo "✅ Code formatting passed"
else
    echo "❌ Code formatting failed"
    exit 1
fi

# Credo checks
echo "🔍 Running Credo analysis..."
if mix credo --strict; then
    echo "✅ Credo analysis passed"
else
    echo "❌ Credo analysis failed"
    exit 1
fi

# Dialyzer (if configured)
if mix dialyzer --quiet; then
    echo "✅ Dialyzer analysis passed"
else
    echo "⚠️  Dialyzer analysis failed (continuing)"
fi

# Tests
echo "🧪 Running test suite..."
if mix test; then
    echo "✅ Test suite passed"
else
    echo "❌ Test suite failed"
    exit 1
fi

echo "✅ All quality gates passed"
