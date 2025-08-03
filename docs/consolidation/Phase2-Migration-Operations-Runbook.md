# Phase 2: Migration Operations Runbook
## Advanced Dependency Mapping and Conflict Resolution - Execution Guide

**Document Version:** 2.0.0  
**Last Updated:** August 3, 2025  
**Classification:** OPERATIONAL - FOR MIGRATION TEAM USE  
**Status:** ✅ **PRODUCTION READY**

---

## 🎯 Operations Overview

This runbook provides step-by-step operational procedures for executing Phase 2 of the Prismatic enterprise consolidation. It covers pre-execution validation, migration execution, monitoring, troubleshooting, and rollback procedures.

### Target Audience

- **Migration Team Leads**: Overall execution coordination
- **DevOps Engineers**: Infrastructure and deployment management
- **Senior Developers**: Technical execution and validation
- **Operations Team**: Monitoring and incident response

### Prerequisites Checklist

**✅ Technical Prerequisites**
- [ ] Elixir 1.17+ installed on all migration servers
- [ ] Phoenix umbrella project structure validated
- [ ] Network access to all legacy project repositories
- [ ] Minimum 2GB free disk space for migration artifacts
- [ ] Database backup and recovery procedures tested

**✅ Access Prerequisites**
- [ ] VPN access to all required systems
- [ ] Repository access for all legacy projects
- [ ] Database admin credentials available
- [ ] Monitoring system access configured
- [ ] Emergency contact list updated

**✅ Team Prerequisites**
- [ ] Migration team trained on tooling and procedures
- [ ] Rollback procedures reviewed and understood
- [ ] Communication channels established
- [ ] Escalation procedures documented
- [ ] On-call rotation schedule confirmed

---

## 🚀 Phase 2 Execution Procedures

### Pre-Execution Validation (30 minutes)

#### Step 1: Environment Validation
```bash
# Validate Elixir environment
elixir --version
mix --version

# Validate Phoenix umbrella setup
cd /path/to/prismatic
mix deps.get
mix compile --warnings-as-errors

# Validate database connectivity
mix ecto.ping
```

#### Step 2: Repository Access Validation
```bash
# Test access to legacy projects
ls -la ../prismatic-legacy/
ls -la ../prismatic-old/

# Validate git repository access
cd ../prismatic-legacy && git status
cd ../prismatic-old && git status
```

#### Step 3: Pre-Migration System Health Check
```bash
# Run comprehensive system health check
mix prismatic.consolidation validate --pre-execution \
  --output-dir=consolidation/validation/pre-execution \
  --verbose

# Review validation results
cat consolidation/validation/pre-execution/health_check.json
```

#### Step 4: Backup Verification
```bash
# Verify backup systems are operational
# (Replace with your specific backup verification commands)
mix prismatic.consolidation backup --verify
```

**✅ Pre-Execution Sign-Off**
- [ ] All validation checks passed
- [ ] Backup systems verified
- [ ] Team ready for execution
- [ ] Rollback procedures confirmed

---

### Phase 2.1: Comprehensive Analysis (45 minutes)

#### Execute Dependency Analysis
```bash
# Run comprehensive dependency analysis
mix prismatic.consolidation analyze \
  --projects="../prismatic-legacy,../prismatic-old" \
  --format=mermaid \
  --output-dir=consolidation/phase2/analysis \
  --verbose

# Monitor progress
tail -f logs/consolidation.log
```

#### Validate Analysis Results
```bash
# Check analysis completion
ls -la consolidation/phase2/analysis/

# Review dependency graph
cat consolidation/phase2/analysis/dependency_graph.json | jq '.statistics'

# Review conflict summary
cat consolidation/phase2/analysis/conflicts_summary.json
```

**Expected Outputs:**
- `dependency_graph.json` - Complete dependency graph
- `conflicts_summary.json` - Summary of 196 conflicts
- `analysis_report.md` - Human-readable analysis report
- `dependency_visualization.mermaid` - Visual dependency diagram

**✅ Analysis Phase Sign-Off**
- [ ] Analysis completed successfully
- [ ] 196 conflicts identified and catalogued
- [ ] 1,385 modules processed
- [ ] No critical analysis errors

---

### Phase 2.2: Conflict Resolution (60 minutes)

#### Execute Automated Conflict Resolution
```bash
# Run automated conflict resolution (dry-run first)
mix prismatic.consolidation resolve \
  --automation-level=full \
  --risk-tolerance=medium \
  --dry-run \
  --output-dir=consolidation/phase2/resolution \
  --verbose

# Review dry-run results
cat consolidation/phase2/resolution/resolution_plan.json | jq '.summary'
```

#### Execute Actual Conflict Resolution
```bash
# Execute actual conflict resolution
mix prismatic.consolidation resolve \
  --automation-level=full \
  --risk-tolerance=medium \
  --output-dir=consolidation/phase2/resolution \
  --verbose

# Monitor resolution progress
tail -f logs/consolidation.log | grep "RESOLUTION"
```

#### Validate Conflict Resolution
```bash
# Validate resolution results
mix prismatic.consolidation validate \
  --focus=conflicts \
  --output-dir=consolidation/phase2/validation \
  --verbose

# Check resolution success rate
cat consolidation/phase2/validation/conflict_validation.json | jq '.success_rate'
```

**Expected Outputs:**
- `resolution_plans.json` - Detailed resolution plans for all conflicts
- `automation_scripts/` - Generated resolution scripts
- `resolution_logs/` - Detailed execution logs
- `validation_results.json` - Resolution validation results

**✅ Conflict Resolution Sign-Off**
- [ ] 90%+ automation rate achieved
- [ ] All critical conflicts resolved
- [ ] Validation passes all checks
- [ ] Rollback scripts generated and tested

---

### Phase 2.3: Migration Planning (30 minutes)

#### Generate Migration Plan
```bash
# Create comprehensive migration plan
mix prismatic.consolidation plan \
  --parallel \
  --risk-tolerance=medium \
  --output-dir=consolidation/phase2/migration \
  --verbose

# Review migration phases
cat consolidation/phase2/migration/migration_plan.json | jq '.phases'
```

#### Validate Migration Plan
```bash
# Validate migration plan against target architecture
mix prismatic.consolidation validate \
  --focus=migration \
  --output-dir=consolidation/phase2/validation \
  --verbose

# Review validation results
cat consolidation/phase2/validation/migration_validation.json
```

**Expected Outputs:**
- `migration_plan.json` - Complete migration plan with phases
- `scripts/` - Automated migration scripts
- `validation_checkpoints.json` - Strategic validation points
- `rollback_procedures.json` - Comprehensive rollback plans

**✅ Migration Planning Sign-Off**
- [ ] Migration plan generated successfully
- [ ] All 6 target apps planned
- [ ] Parallel execution opportunities identified
- [ ] Rollback procedures validated

---

### Phase 2.4: Full Execution (120 minutes)

#### Pre-Execution Final Checks
```bash
# Final pre-execution validation
mix prismatic.consolidation validate \
  --comprehensive \
  --output-dir=consolidation/phase2/final-validation \
  --verbose

# Verify rollback readiness
mix prismatic.consolidation rollback --verify
```

#### Execute Migration (DRY RUN FIRST)
```bash
# CRITICAL: Always run dry-run first
mix prismatic.consolidation execute \
  --dry-run \
  --parallel \
  --automation-level=full \
  --output-dir=consolidation/phase2/execution \
  --verbose

# Review dry-run results thoroughly
cat consolidation/phase2/execution/dry_run_results.json
```

#### Execute Actual Migration
```bash
# Execute actual migration (after dry-run validation)
mix prismatic.consolidation execute \
  --parallel \
  --automation-level=full \
  --output-dir=consolidation/phase2/execution \
  --verbose

# Monitor execution in real-time
tail -f logs/migration_execution.log
```

#### Monitor Migration Progress
```bash
# Check migration status in separate terminal
watch "mix prismatic.consolidation status"

# Monitor system health
watch "mix prismatic.consolidation validate --focus=health"
```

**✅ Migration Execution Sign-Off**
- [ ] All migration phases completed successfully
- [ ] No critical errors encountered
- [ ] System health checks passing
- [ ] Target architecture validated

---

## 🔍 Monitoring and Health Checks

### Real-Time Monitoring Commands

#### System Health Monitoring
```bash
# Continuous health monitoring
watch -n 30 "mix prismatic.consolidation validate --focus=health"

# Resource utilization monitoring
watch -n 10 "ps aux | grep beam.smp"
watch -n 10 "df -h"
watch -n 10 "free -m"
```

#### Migration Progress Monitoring
```bash
# Migration status dashboard
mix prismatic.consolidation status --dashboard

# Detailed progress tracking
tail -f logs/migration_execution.log | grep "PROGRESS"

# Error monitoring
tail -f logs/migration_execution.log | grep "ERROR\|WARN"
```

### Key Performance Indicators (KPIs)

| Metric | Target | Monitoring Command |
|--------|--------|--------------------|
| **Compilation Success** | 100% | `mix compile --warnings-as-errors` |
| **Test Success Rate** | 100% | `mix test --max-failures=1` |
| **Memory Usage** | < 80% | `free -m` |
| **Disk Usage** | < 85% | `df -h` |
| **Migration Phase Success** | 100% | `mix prismatic.consolidation status` |

### Alert Thresholds

**CRITICAL ALERTS** (Immediate Response Required):
- Compilation failures: Any failure
- Test failures: > 5% failure rate
- Memory usage: > 90%
- Disk usage: > 95%
- Migration phase failure: Any failure

**WARNING ALERTS** (Monitor Closely):
- Memory usage: > 80%
- Disk usage: > 85%
- Test failures: > 1% failure rate
- Performance degradation: > 20% slowdown

---

## 🚨 Troubleshooting Guide

### Common Issues and Solutions

#### Issue: Compilation Failures
**Symptoms:** `mix compile` exits with errors
**Diagnosis:**
```bash
mix compile --verbose --warnings-as-errors
```
**Solutions:**
1. Check for dependency conflicts: `mix deps.tree`
2. Clean and recompile: `mix clean && mix deps.get && mix compile`
3. Check Elixir version compatibility: `elixir --version`

#### Issue: Memory Exhaustion
**Symptoms:** System becomes unresponsive, OOM errors
**Diagnosis:**
```bash
free -m
ps aux | grep beam.smp | head -5
```
**Solutions:**
1. Reduce parallel execution: `--parallel=false`
2. Increase swap space: `sudo swapon -s`
3. Monitor memory usage: `watch free -m`

#### Issue: Migration Phase Failure
**Symptoms:** Migration stops at specific phase
**Diagnosis:**
```bash
mix prismatic.consolidation status --detailed
cat logs/migration_execution.log | grep "PHASE.*FAILED"
```
**Solutions:**
1. Check phase prerequisites: `mix prismatic.consolidation validate --focus=prerequisites`
2. Execute single phase: `mix prismatic.consolidation execute --phase=N`
3. Review rollback options: `mix prismatic.consolidation rollback --help`

#### Issue: Dependency Resolution Timeout
**Symptoms:** Long delays during dependency analysis
**Diagnosis:**
```bash
netstat -an | grep :443
ping hex.pm
```
**Solutions:**
1. Check network connectivity
2. Increase timeout: `--timeout=600`
3. Use local mirror if available

### Emergency Procedures

#### Emergency Stop
```bash
# Stop all consolidation processes
pkill -f "consolidation"

# Check for running processes
ps aux | grep consolidation
```

#### Emergency Rollback
```bash
# Execute emergency rollback
mix prismatic.consolidation rollback --type=emergency --force

# Verify rollback success
mix prismatic.consolidation validate --post-rollback
```

#### System Recovery
```bash
# Restore from backup
mix prismatic.consolidation restore --backup-id=pre-migration

# Validate system integrity
mix test
mix compile --warnings-as-errors
```

---

## 🔄 Rollback Procedures

### Rollback Types and When to Use

#### 1. Standard Rollback
**Use Case:** Non-critical issues, planned rollback
**Execution Time:** 15-30 minutes
```bash
mix prismatic.consolidation rollback --type=standard --phase=all
```

#### 2. Emergency Rollback
**Use Case:** Critical system failure, data corruption risk
**Execution Time:** < 15 minutes
```bash
mix prismatic.consolidation rollback --type=emergency --force
```

#### 3. Partial Rollback
**Use Case:** Specific phase issues, targeted recovery
**Execution Time:** 5-15 minutes
```bash
mix prismatic.consolidation rollback --type=partial --phases="3,4,5"
```

#### 4. Cascade Rollback
**Use Case:** Dependency-related failures
**Execution Time:** 20-45 minutes
```bash
mix prismatic.consolidation rollback --type=cascade --from-phase=3
```

### Post-Rollback Validation

#### Immediate Validation (5 minutes)
```bash
# Verify system returns to previous state
mix compile --warnings-as-errors
mix test --max-failures=1

# Check data integrity
mix ecto.check_migrations
```

#### Comprehensive Validation (15 minutes)
```bash
# Full system validation
mix prismatic.consolidation validate --comprehensive \
  --output-dir=consolidation/post-rollback-validation

# Performance validation
mix test --cover
```

---

## 📊 Post-Execution Procedures

### Success Validation (30 minutes)

#### Technical Validation
```bash
# Compile entire umbrella project
mix compile --warnings-as-errors

# Run full test suite
mix test --cover --max-failures=5

# Validate target architecture
mix prismatic.consolidation validate --focus=architecture
```

#### Business Validation
```bash
# Generate success metrics report
mix prismatic.consolidation report --format=json \
  --output-dir=consolidation/reports/success-metrics

# Validate business requirements
# (Custom validation scripts based on business requirements)
```

### Documentation and Reporting

#### Generate Final Reports
```bash
# Generate comprehensive execution report
mix prismatic.consolidation report --comprehensive \
  --format=markdown \
  --output-dir=consolidation/reports/final

# Archive execution artifacts
tar -czf consolidation-phase2-$(date +%Y%m%d).tar.gz consolidation/
```

#### Knowledge Transfer
- [ ] Update operational documentation
- [ ] Conduct post-execution review meeting
- [ ] Document lessons learned
- [ ] Update troubleshooting guides
- [ ] Train support team on new architecture

---

## 🎯 Success Criteria Validation

### Technical Success Criteria

**✅ System Health**
- [ ] All applications compile without warnings
- [ ] Test suite passes with 100% success rate
- [ ] No memory leaks or performance degradation
- [ ] Database integrity maintained

**✅ Architecture Compliance**
- [ ] 6-app umbrella structure implemented
- [ ] Bounded contexts properly separated
- [ ] Dependency conflicts resolved (196/196)
- [ ] Cross-app communication patterns established

**✅ Operational Excellence**
- [ ] Monitoring and alerting functional
- [ ] Rollback procedures tested and ready
- [ ] Documentation complete and accurate
- [ ] Team trained on new architecture

### Business Success Criteria

**✅ Migration Objectives**
- [ ] Zero downtime achieved during migration
- [ ] All 1,385 modules successfully processed
- [ ] 90%+ automation rate achieved
- [ ] Migration completed within timeline

**✅ Risk Management**
- [ ] All identified risks mitigated
- [ ] Comprehensive rollback capability confirmed
- [ ] Business continuity maintained
- [ ] Security and compliance requirements met

---

## 📞 Support and Escalation

### Contact Information

**Migration Team Lead**
- Primary: [Team Lead Name] - [phone] - [email]
- Secondary: [Backup Lead] - [phone] - [email]

**Technical Escalation**
- Level 1: Migration Team
- Level 2: Senior Engineering Team
- Level 3: Architecture Team
- Level 4: CTO Office

**Business Escalation**
- Level 1: Project Manager
- Level 2: Engineering Director
- Level 3: VP Engineering
- Level 4: CTO

### Emergency Contacts

**24/7 Emergency Hotline:** [Emergency Number]
**Incident Response Team:** [Team Contact]
**Database Administrator:** [DBA Contact]
**Infrastructure Team:** [Ops Contact]

---

## 📝 Operational Checklist

### Pre-Execution Checklist
- [ ] All prerequisites validated
- [ ] Team briefed and ready
- [ ] Backup systems verified
- [ ] Rollback procedures reviewed
- [ ] Communication channels established

### During Execution Checklist
- [ ] Real-time monitoring active
- [ ] Progress tracking updated
- [ ] Health checks passing
- [ ] Team communication maintained
- [ ] Incident response ready

### Post-Execution Checklist
- [ ] Success criteria validated
- [ ] Final reports generated
- [ ] Knowledge transfer completed
- [ ] Post-mortem scheduled
- [ ] Next phase planning initiated

---

**Operations Runbook Status**: ✅ **PRODUCTION READY**  
**Last Validated**: August 3, 2025  
**Next Review Date**: August 17, 2025  
**Document Owner**: Migration Operations Team

*This runbook is a living document and should be updated based on operational experience and lessons learned.*