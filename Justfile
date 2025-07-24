# Development tasks
dev-tailwind:
  ./scripts/dev_tailwind_watcher.sh

# Documentation tasks
docs:
  mix docs

docs-serve: docs
  @echo "Documentation generated in doc/ directory"
  @echo "Access documentation at http://localhost:4000/doc when Phoenix server is running"

# Changelog and version management tasks
git-ops-init:
  @echo "Initializing git_ops..."
  mix git_ops.init

changelog: git-ops-init
  @echo "Generating changelog..."
  mix git_ops.changelog

version-major: git-ops-init
  @echo "Bumping major version..."
  mix prismatic.version --major

version-minor: git-ops-init
  @echo "Bumping minor version..."
  mix prismatic.version --minor

version-patch: git-ops-init
  @echo "Bumping patch version..."
  mix prismatic.version --patch

# Release tasks
release-major: version-major changelog
  @echo "Major version release complete"

release-minor: version-minor changelog
  @echo "Minor version release complete"

release-patch: version-patch changelog
  @echo "Patch version release complete"

