# Deployment Procedures

Step-by-step procedures for deploying Prismatic to different environments.

## Pre-Deployment Checklist

### Code Quality Verification
- [ ] All tests pass (`mix test`)
- [ ] Code is formatted (`mix format --check-formatted`)
- [ ] Static analysis passes (`mix credo`)
- [ ] Documentation is updated
- [ ] Database migrations are reviewed and tested

### Security Review
- [ ] No sensitive data in code or config
- [ ] Dependency security scan completed
- [ ] SSL certificates are valid and current
- [ ] Environment variables properly configured

### Performance Validation
- [ ] Load testing completed (if applicable)
- [ ] Database query performance verified
- [ ] Asset optimization confirmed
- [ ] Memory usage within acceptable limits

## Staging Deployment

### Environment Setup
1. **Verify Staging Environment**
   ```bash
   # Check staging database connectivity
   MIX_ENV=staging mix ecto.migrate
   
   # Verify environment variables
   echo $DATABASE_URL
   echo $SECRET_KEY_BASE
   ```

2. **Deploy Application**
   ```bash
   # Build release
   MIX_ENV=staging mix release
   
   # Deploy to staging server
   scp _build/staging/rel/prismatic/releases/*/prismatic.tar.gz staging-server:/opt/app/
   
   # Extract and start
   ssh staging-server "cd /opt/app && tar -xzf prismatic.tar.gz && ./bin/prismatic start"
   ```

3. **Verify Deployment**
   - [ ] Application starts without errors
   - [ ] Health check endpoint responds
   - [ ] Database migrations applied successfully
   - [ ] Static assets loading correctly

### Smoke Testing
1. **Critical Path Testing**
   - User authentication flow
   - Core business functionality
   - Payment processing (if applicable)
   - API endpoints functionality

2. **Performance Verification**
   ```bash
   # Basic load test
   ab -n 100 -c 10 https://staging.prismatic.com/
   
   # Database connection test
   curl https://staging.prismatic.com/health
   ```

## Production Deployment

### Blue-Green Deployment Strategy

1. **Prepare Green Environment**
   ```bash
   # Deploy to green environment
   MIX_ENV=prod mix release
   
   # Copy to green servers
   scp _build/prod/rel/prismatic/releases/*/prismatic.tar.gz green-server:/opt/app/
   ```

2. **Database Migration**
   ```bash
   # Run migrations on production database
   MIX_ENV=prod mix ecto.migrate
   
   # Verify migration success
   MIX_ENV=prod mix ecto.migrations
   ```

3. **Start Green Environment**
   ```bash
   ssh green-server "cd /opt/app && ./bin/prismatic start"
   
   # Wait for startup
   sleep 30
   
   # Verify health
   curl https://green.prismatic.com/health
   ```

4. **Switch Traffic**
   ```bash
   # Update load balancer to point to green
   # This step varies by infrastructure (AWS ELB, nginx, etc.)
   
   # Verify production traffic
   curl https://prismatic.com/health
   ```

5. **Monitor and Rollback Plan**
   ```bash
   # Monitor error rates and response times
   # If issues detected, switch back to blue:
   # Update load balancer to point back to blue environment
   ```

### Direct Deployment (Alternative)

**Use only for low-traffic periods or maintenance windows**

1. **Maintenance Mode**
   ```bash
   # Enable maintenance mode
   touch /opt/app/maintenance.html
   ```

2. **Deploy New Version**
   ```bash
   # Stop application
   ./bin/prismatic stop
   
   # Backup current version
   cp -r /opt/app/current /opt/app/backup-$(date +%Y%m%d-%H%M%S)
   
   # Deploy new version
   tar -xzf prismatic.tar.gz -C /opt/app/current
   
   # Run migrations
   MIX_ENV=prod ./bin/prismatic eval "Prismatic.Release.migrate"
   
   # Start application
   ./bin/prismatic start
   ```

3. **Verify and Exit Maintenance**
   ```bash
   # Verify application health
   curl localhost:4000/health
   
   # Remove maintenance mode
   rm /opt/app/maintenance.html
   ```

## Database Deployment

### Migration Strategy
1. **Development Testing**
   ```bash
   # Test migration locally
   MIX_ENV=dev mix ecto.rollback -n 1
   MIX_ENV=dev mix ecto.migrate
   
   # Test with production-like data volume
   MIX_ENV=dev mix ecto.seed
   ```

2. **Staging Validation**
   ```bash
   # Apply to staging first
   MIX_ENV=staging mix ecto.migrate
   
   # Verify data integrity
   MIX_ENV=staging mix custom.verify_data
   ```

3. **Production Migration**
   ```bash
   # Backup database first
   pg_dump prismatic_prod > backup-$(date +%Y%m%d-%H%M%S).sql
   
   # Apply migration
   MIX_ENV=prod mix ecto.migrate
   
   # Verify success
   MIX_ENV=prod mix ecto.migrations
   ```

### Rollback Procedures
```bash
# Rollback specific number of migrations
MIX_ENV=prod mix ecto.rollback -n 2

# Restore from backup (emergency only)
psql prismatic_prod < backup-20231201-120000.sql
```

## Environment Configuration

### Environment Variables
**Required for all environments:**
```bash
# Application
SECRET_KEY_BASE=64-character-secret
PHX_HOST=your-domain.com
PORT=4000

# Database
DATABASE_URL=postgresql://user:pass@host:5432/database

# External Services
SMTP_HOST=smtp.example.com
SMTP_USERNAME=user
SMTP_PASSWORD=pass

# Monitoring
SENTRY_DSN=https://key@sentry.io/project
```

### Configuration Validation
```bash
# Verify all required environment variables
mix release.init
mix release

# Test configuration parsing
MIX_ENV=prod mix eval "Application.get_all_env(:prismatic)"
```

## Monitoring and Alerts

### Health Checks
Implement health check endpoint:
```elixir
defmodule PrismaticWeb.HealthController do
  use PrismaticWeb, :controller
  
  def check(conn, _params) do
    # Verify database connectivity
    case Prismatic.Repo.query("SELECT 1") do
      {:ok, _} -> 
        json(conn, %{status: "healthy", timestamp: DateTime.utc_now()})
      {:error, _} -> 
        conn
        |> put_status(:service_unavailable)
        |> json(%{status: "unhealthy", error: "database"})
    end
  end
end
```

### Deployment Monitoring
```bash
# Monitor application logs during deployment
tail -f /var/log/prismatic/application.log

# Check system resources
htop
df -h
free -m

# Monitor database performance
psql -c "SELECT * FROM pg_stat_activity WHERE state = 'active';"
```

## Rollback Procedures

### Application Rollback
1. **Blue-Green Rollback**
   ```bash
   # Switch load balancer back to previous version
   # Update DNS or load balancer configuration
   ```

2. **Direct Deployment Rollback**
   ```bash
   # Stop current application
   ./bin/prismatic stop
   
   # Restore previous version
   rm -rf /opt/app/current
   cp -r /opt/app/backup-latest /opt/app/current
   
   # Start previous version
   ./bin/prismatic start
   ```

### Database Rollback
```bash
# Rollback migrations (if safe)
MIX_ENV=prod mix ecto.rollback -n 1

# Full database restore (emergency only)
pg_restore -d prismatic_prod backup-file.dump
```

## Post-Deployment Verification

### Automated Verification
```bash
#!/bin/bash
# post-deploy-verification.sh

echo "Starting post-deployment verification..."

# Health check
if curl -f https://prismatic.com/health; then
  echo "✓ Health check passed"
else
  echo "✗ Health check failed"
  exit 1
fi

# Critical functionality test
if curl -f https://prismatic.com/api/status; then
  echo "✓ API status check passed"
else
  echo "✗ API status check failed"
  exit 1
fi

echo "All verification checks passed!"
```

### Manual Verification
- [ ] User login/logout functionality
- [ ] Critical business workflows
- [ ] Payment processing (if applicable)
- [ ] Email delivery
- [ ] Real-time features (LiveView)

## Incident Response

### Deployment Issues
1. **Immediate Response**
   - Stop deployment process
   - Assess impact and affected users
   - Communicate status to stakeholders

2. **Rollback Decision**
   - If critical functionality broken: immediate rollback
   - If minor issues: assess fix vs. rollback time

3. **Post-Incident**
   - Document what went wrong
   - Update deployment procedures
   - Conduct retrospective

### Emergency Procedures
```bash
# Emergency application stop
sudo systemctl stop prismatic
# or
./bin/prismatic stop

# Emergency database maintenance mode
# Update load balancer to show maintenance page

# Emergency rollback
# Follow rollback procedures above
```

## Related Documentation
- [Troubleshooting](troubleshooting.md) - Common deployment issues and solutions
- [Architecture Overview](../core/architecture-overview.md) - System design context
- [Performance Optimization](../guides/performance-optimization.md) - Performance considerations
- [Security Guidelines](../guides/security-guidelines.md) - Security deployment requirements