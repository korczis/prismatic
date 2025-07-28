# Branch Workflow Migration Plan: master → main

## Overview

This document outlines the comprehensive plan for migrating from the current `master` branch to `main` while implementing a robust feature branch workflow with automated tagging.

## Migration Strategy

### Phase 1: Pre-Migration Setup (Week 1)

#### 1.1 Repository Preparation
```bash
# Create main branch from current master
git checkout master
git pull upstream master
git checkout -b main
git push upstream main
git push gh main
git push gl main
```

#### 1.2 Remote Configuration Update
```bash
# Update upstream remote default branch (GitHub/GitLab settings)
# - Set main as default branch in repository settings
# - Update branch protection rules
# - Configure required status checks
```

#### 1.3 Local Development Environment
```bash
# Update local git configuration
git symbolic-ref refs/remotes/upstream/HEAD refs/remotes/upstream/main
git symbolic-ref refs/remotes/gh/HEAD refs/remotes/gh/main
git symbolic-ref refs/remotes/gl/HEAD refs/remotes/gl/main

# Update tracking branch
git branch --set-upstream-to=upstream/main main
```

### Phase 2: Dual-Branch Transition (Weeks 2-3)

#### 2.1 Automatic Sync Setup
```bash
# GitHub Action for master → main sync during transition
# .github/workflows/master-main-sync.yml
name: "Master-Main Sync"
on:
  push:
    branches: [master]
jobs:
  sync:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - name: Sync master to main
        run: |
          git checkout main
          git merge master --ff-only
          git push origin main
```

#### 2.2 Team Communication
- [ ] Announce migration timeline to development team
- [ ] Share migration documentation and new workflow guidelines
- [ ] Schedule team training session on new branch workflow
- [ ] Update project README and documentation references

### Phase 3: Feature Branch Workflow Implementation (Weeks 2-4)

#### 3.1 Git Hooks Implementation
- [ ] Create pre-commit hook for branch naming validation
- [ ] Create pre-push hook to prevent direct pushes to main
- [ ] Create post-merge hook for automatic tagging
- [ ] Distribute hooks installation script to team

#### 3.2 CI/CD Pipeline Setup
- [ ] Configure GitHub Actions for branch protection
- [ ] Configure GitLab CI for redundant enforcement
- [ ] Set up automated testing on feature branches
- [ ] Implement automatic semantic versioning and tagging

#### 3.3 Mix Tasks Development
- [ ] Create `mix branch.create` for standardized branch creation
- [ ] Create `mix branch.validate` for local validation
- [ ] Create `mix version.bump` for semantic versioning
- [ ] Create `mix deploy.prepare` for deployment readiness

### Phase 4: Full Migration (Week 4)

#### 4.1 Final Cutover
```bash
# Stop dual-sync
# Remove master-main sync workflow
# Update all documentation references
# Archive master branch (don't delete - keep for history)
git push upstream :master  # Delete remote master (optional)
```

#### 4.2 Team Adoption Verification
- [ ] Verify all team members have updated local environments
- [ ] Confirm all CI/CD pipelines are using main branch
- [ ] Validate automated tagging is working correctly
- [ ] Test complete feature branch workflow end-to-end

## Branch Naming Convention

### Standardized Patterns
| Type | Pattern | Example | Description |
|------|---------|---------|-------------|
| **Feature** | `feature/<description>` | `feature/user-authentication` | New functionality |
| **Bugfix** | `bugfix/<issue-description>` | `bugfix/login-validation` | Non-critical fixes |
| **Hotfix** | `hotfix/<critical-issue>` | `hotfix/security-vulnerability` | Production emergencies |
| **Release** | `release/v<version>` | `release/v1.2.0` | Release preparation |
| **Chore** | `chore/<task>` | `chore/update-dependencies` | Maintenance tasks |
| **Docs** | `docs/<section>` | `docs/api-documentation` | Documentation updates |

### Validation Rules
```bash
# Branch name validation regex
^(feature|bugfix|hotfix|release|chore|docs)/[a-z0-9-]+$

# Examples of valid branch names:
✓ feature/user-dashboard
✓ bugfix/memory-leak-fix
✓ hotfix/critical-security-patch
✓ release/v2.1.0
✓ chore/dependency-updates
✓ docs/installation-guide

# Examples of invalid branch names:
✗ Feature/User-Dashboard (wrong case)
✗ fix-bug (missing type prefix)
✗ feature/user_dashboard (underscore not allowed)
✗ my-branch (no type specified)
```

## Semantic Versioning Strategy

### Version Format
```
MAJOR.MINOR.PATCH[-PRERELEASE][+BUILD]

Examples:
- v1.2.3        (stable release)
- v1.2.4-rc.1   (release candidate)
- v1.2.4-dev.5  (development snapshot)
- v1.2.3+build.123 (build metadata)
```

### Automatic Bumping Rules
| Branch Type | Version Bump | Tag Format | Example |
|-------------|--------------|------------|---------|
| `hotfix/*` | PATCH | `v{version}` | `v1.2.4` |
| `bugfix/*` | PATCH | `v{version}` | `v1.2.4` |
| `feature/*` | MINOR | `v{version}` | `v1.3.0` |
| `release/*` | Extracted from branch | `v{version}` | `v2.0.0` |

### Tagging Automation
```bash
# Automatic tagging on merge to main
# Triggered by post-merge git hook or CI/CD pipeline

1. Detect branch type from merge commit
2. Calculate next version based on type
3. Create annotated git tag with version
4. Push tag to all configured remotes
5. Trigger deployment pipeline (if applicable)
```

## Risk Mitigation

### Backup Strategy
- [ ] Full repository backup before migration
- [ ] Document rollback procedure
- [ ] Maintain master branch as backup during transition
- [ ] Test migration process on clone repository first

### Team Coordination
- [ ] Freeze major feature development during migration week
- [ ] Establish communication channels for migration issues
- [ ] Assign migration coordinator for issue resolution
- [ ] Plan weekend migration window for minimal disruption

### Validation Checkpoints
- [ ] Verify git history integrity after migration
- [ ] Confirm all remote branches are correctly updated
- [ ] Test automated workflows with new branch structure
- [ ] Validate team member access and permissions

## Success Criteria

### Technical Validation
- [x] Main branch created and synchronized across all remotes
- [ ] Feature branch workflow enforced through multiple mechanisms
- [ ] Automatic semantic versioning working correctly
- [ ] CI/CD pipelines updated and functional
- [ ] Documentation system integrated with branch workflow

### Team Adoption
- [ ] All team members successfully migrated to new workflow
- [ ] Zero direct commits to main branch after migration
- [ ] Feature branches consistently follow naming conventions
- [ ] Automated tagging functioning on all merges to main
- [ ] Documentation automatically updated with branch changes

## Timeline Summary

| Week | Phase | Key Activities | Success Metrics |
|------|-------|----------------|-----------------|
| 1 | Setup | Create main branch, configure remotes | Main branch exists on all remotes |
| 2-3 | Transition | Dual-branch sync, team training | Team familiar with new workflow |
| 4 | Implementation | Full workflow deployment | All enforcement mechanisms active |
| 5 | Validation | Testing and refinement | Zero workflow violations |

## Post-Migration Monitoring

### Metrics to Track
- Branch naming convention compliance rate
- Direct commits to main (should be zero)
- Automatic tagging success rate
- Feature branch lifecycle duration
- Documentation synchronization accuracy

### Continuous Improvement
- Monthly workflow review meetings
- Developer feedback collection and analysis
- Automation refinement based on usage patterns
- Documentation updates based on common issues

## Related Documentation
- [Feature Branch Workflow Guide](feature-branch-workflow.md)
- [Semantic Versioning Policy](semantic-versioning.md)
- [CI/CD Pipeline Configuration](../operations/cicd-configuration.md)
- [Git Hooks Installation Guide](git-hooks-setup.md)