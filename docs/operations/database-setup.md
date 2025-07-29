# Database Setup

Comprehensive guide for setting up, configuring, and maintaining PostgreSQL databases for the Prismatic application across all environments.

<!-- NAV_START -->
## Navigation

**Current Location**: [Home](../README.md) > [Operations](README.md) > Database Setup

### Quick Links

- **📚 [Parent Directory](README.md)** - Return to operations index
- **🏠 [Documentation Home](../README.md)** - Main documentation index
- **🔍 [Search Documentation](../reference/glossary.md)** - Find terms and concepts

### Related Documentation

- [Database Schema](../reference/database-schema.md) - Complete database schema reference
- [Configuration Examples](../reference/config-example.md) - Database configuration examples
- [Performance Optimization](../guides/performance-optimization.md) - Database performance tuning
- [Security Guidelines](../guides/security-guidelines.md) - Database security best practices
- [Monitoring Setup](monitoring-setup.md) - Database monitoring and alerting
<!-- NAV_END -->

## Overview

This guide provides comprehensive instructions for setting up and maintaining PostgreSQL databases for the Prismatic application. It covers installation, configuration, security, performance tuning, backup strategies, and operational procedures for development, staging, and production environments.

## Prerequisites

### System Requirements
- **PostgreSQL Version**: 15+ (recommended: 16.x)
- **Memory**: Minimum 4GB RAM (8GB+ recommended for production)
- **Storage**: SSD storage recommended, 100GB+ for production
- **Operating System**: Linux (Ubuntu 22.04 LTS, CentOS 8+), macOS, or Windows

### Required Extensions
```sql
-- Essential PostgreSQL extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";     -- UUID generation
CREATE EXTENSION IF NOT EXISTS "citext";       -- Case-insensitive text
CREATE EXTENSION IF NOT EXISTS "pg_trgm";      -- Trigram matching for search
CREATE EXTENSION IF NOT EXISTS "btree_gin";    -- GIN indexing support
CREATE EXTENSION IF NOT EXISTS "pg_stat_statements"; -- Query statistics
```

## Installation

### Ubuntu/Debian Installation

#### Package Installation
```bash
# Update package lists
sudo apt update

# Install PostgreSQL and essential packages
sudo apt install -y postgresql-16 postgresql-client-16 postgresql-contrib-16

# Install additional tools
sudo apt install -y postgresql-16-pg-stat-statements
sudo apt install -y postgresql-16-pgcrypto

# Start and enable PostgreSQL service
sudo systemctl start postgresql
sudo systemctl enable postgresql

# Verify installation
sudo systemctl status postgresql
psql --version
```

#### Initial Configuration
```bash
# Switch to postgres user
sudo -u postgres psql

-- Set password for postgres user
ALTER USER postgres PASSWORD 'secure_password';

-- Create application database and user
CREATE DATABASE prismatic_dev;
CREATE DATABASE prismatic_test;
CREATE DATABASE prismatic_prod;

CREATE USER prismatic WITH PASSWORD 'secure_app_password';
GRANT ALL PRIVILEGES ON DATABASE prismatic_dev TO prismatic;
GRANT ALL PRIVILEGES ON DATABASE prismatic_test TO prismatic;
GRANT ALL PRIVILEGES ON DATABASE prismatic_prod TO prismatic;

-- Grant schema permissions
\c prismatic_dev
GRANT ALL ON SCHEMA public TO prismatic;
GRANT ALL ON ALL TABLES IN SCHEMA public TO prismatic;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO prismatic;
GRANT ALL ON ALL FUNCTIONS IN SCHEMA public TO prismatic;

-- Set default privileges for future objects
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO prismatic;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO prismatic;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON FUNCTIONS TO prismatic;

\q
```

### macOS Installation

#### Using Homebrew
```bash
# Install PostgreSQL
brew install postgresql@16

# Start PostgreSQL service
brew services start postgresql@16

# Create databases
createdb prismatic_dev
createdb prismatic_test

# Create user
psql postgres -c "CREATE USER prismatic WITH PASSWORD 'dev_password';"
psql postgres -c "GRANT ALL PRIVILEGES ON DATABASE prismatic_dev TO prismatic;"
psql postgres -c "GRANT ALL PRIVILEGES ON DATABASE prismatic_test TO prismatic;"
```

#### Using Postgres.app
```bash
# Download and install Postgres.app from https://postgresapp.com/
# Add to PATH
export PATH="/Applications/Postgres.app/Contents/Versions/16/bin:$PATH"

# Create databases and user
createdb prismatic_dev
createdb prismatic_test
psql prismatic_dev -c "CREATE USER prismatic WITH PASSWORD 'dev_password';"
```

### Docker Installation

#### Docker Compose Setup
```yaml
# docker-compose.yml
version: '3.8'

services:
  postgres:
    image: postgres:16-alpine
    container_name: prismatic_postgres
    environment:
      POSTGRES_DB: prismatic_dev
      POSTGRES_USER: prismatic
      POSTGRES_PASSWORD: dev_password
      POSTGRES_INITDB_ARGS: "--encoding=UTF-8 --locale=en_US.UTF-8"
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./init-scripts:/docker-entrypoint-initdb.d
    command: >
      postgres
      -c shared_preload_libraries=pg_stat_statements
      -c pg_stat_statements.track=all
      -c max_connections=200
      -c shared_buffers=256MB
      -c effective_cache_size=1GB
      -c maintenance_work_mem=64MB
      -c checkpoint_completion_target=0.9
      -c wal_buffers=16MB
      -c default_statistics_target=100
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U prismatic -d prismatic_dev"]
      interval: 30s
      timeout: 10s
      retries: 5

volumes:
  postgres_data:
```

#### Initialization Scripts
```sql
-- init-scripts/01-create-extensions.sql
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "citext";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";
CREATE EXTENSION IF NOT EXISTS "btree_gin";
CREATE EXTENSION IF NOT EXISTS "pg_stat_statements";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
```

```sql
-- init-scripts/02-create-test-database.sql
CREATE DATABASE prismatic_test OWNER prismatic;
\c prismatic_test
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "citext";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";
CREATE EXTENSION IF NOT EXISTS "btree_gin";
```

## Configuration

### PostgreSQL Configuration

#### postgresql.conf Settings

##### Development Environment
```conf
# postgresql.conf for development

# Connection Settings
listen_addresses = 'localhost'
port = 5432
max_connections = 50

# Memory Settings
shared_buffers = 128MB
effective_cache_size = 512MB
maintenance_work_mem = 32MB
work_mem = 4MB

# WAL Settings
wal_level = replica
checkpoint_completion_target = 0.7
wal_buffers = 8MB

# Query Planner
default_statistics_target = 100
random_page_cost = 1.1  # For SSD

# Logging
log_statement = 'all'
log_duration = on
log_min_duration_statement = 100ms
log_line_prefix = '%t [%p]: [%l-1] user=%u,db=%d,app=%a,client=%h '

# Extensions
shared_preload_libraries = 'pg_stat_statements'
pg_stat_statements.track = all
pg_stat_statements.max = 10000
```

##### Production Environment
```conf
# postgresql.conf for production

# Connection Settings
listen_addresses = '*'
port = 5432
max_connections = 200

# Memory Settings (adjust based on available RAM)
shared_buffers = 2GB          # 25% of RAM
effective_cache_size = 6GB    # 75% of RAM
maintenance_work_mem = 256MB
work_mem = 16MB
max_worker_processes = 8
max_parallel_workers_per_gather = 4

# WAL Settings
wal_level = replica
checkpoint_completion_target = 0.9
wal_buffers = 16MB
max_wal_size = 2GB
min_wal_size = 1GB

# Query Planner
default_statistics_target = 100
random_page_cost = 1.1
effective_io_concurrency = 200

# Logging
log_destination = 'csvlog'
logging_collector = on
log_directory = 'log'
log_filename = 'postgresql-%Y-%m-%d_%H%M%S.log'
log_rotation_age = 1d
log_rotation_size = 100MB
log_min_duration_statement = 1000ms
log_checkpoints = on
log_connections = on
log_disconnections = on
log_lock_waits = on
log_statement = 'ddl'

# Extensions
shared_preload_libraries = 'pg_stat_statements'
pg_stat_statements.track = all
pg_stat_statements.max = 10000

# Replication (if using)
hot_standby = on
wal_keep_size = 1GB
```

#### pg_hba.conf Settings

##### Development Environment
```conf
# pg_hba.conf for development
# TYPE  DATABASE        USER            ADDRESS                 METHOD

# Local connections
local   all             postgres                                peer
local   all             prismatic                               md5

# IPv4 local connections
host    all             postgres        127.0.0.1/32            md5
host    all             prismatic       127.0.0.1/32            md5

# IPv6 local connections
host    all             postgres        ::1/128                 md5
host    all             prismatic       ::1/128                 md5
```

##### Production Environment
```conf
# pg_hba.conf for production
# TYPE  DATABASE        USER            ADDRESS                 METHOD

# Local connections
local   all             postgres                                peer
local   all             prismatic                               md5

# Application servers (adjust IP ranges as needed)
host    prismatic_prod  prismatic       10.0.1.0/24             md5
host    prismatic_prod  prismatic       10.0.2.0/24             md5

# Replication connections
host    replication     replicator      10.0.3.0/24             md5

# SSL-only connections for remote access
hostssl all             all             0.0.0.0/0               md5
```

### SSL Configuration

#### SSL Setup for Production
```bash
# Generate SSL certificates (or use existing ones)
sudo openssl req -new -x509 -days 365 -nodes -text \
  -out /var/lib/postgresql/16/main/server.crt \
  -keyout /var/lib/postgresql/16/main/server.key \
  -subj "/CN=postgres.example.com"

# Set permissions
sudo chown postgres:postgres /var/lib/postgresql/16/main/server.crt
sudo chown postgres:postgres /var/lib/postgresql/16/main/server.key
sudo chmod 600 /var/lib/postgresql/16/main/server.key
```

```conf
# postgresql.conf SSL settings
ssl = on
ssl_cert_file = 'server.crt'
ssl_key_file = 'server.key'
ssl_ciphers = 'HIGH:MEDIUM:+3DES:!aNULL'
ssl_prefer_server_ciphers = on
```

## Performance Tuning

### Index Optimization

#### Essential Indexes
```sql
-- Create performance-critical indexes
-- User table indexes
CREATE INDEX CONCURRENTLY idx_users_email_active 
ON users(email) WHERE deleted_at IS NULL;

CREATE INDEX CONCURRENTLY idx_users_organization_status 
ON users(organization_id, status) WHERE deleted_at IS NULL;

-- Post table indexes
CREATE INDEX CONCURRENTLY idx_posts_published_featured 
ON posts(published_at DESC, featured) 
WHERE status = 'published' AND deleted_at IS NULL;

CREATE INDEX CONCURRENTLY idx_posts_author_status 
ON posts(author_id, status) WHERE deleted_at IS NULL;

-- Full-text search index
CREATE INDEX CONCURRENTLY idx_posts_full_text 
ON posts USING GIN(to_tsvector('english', title || ' ' || COALESCE(content, '')));

-- Comment table indexes
CREATE INDEX CONCURRENTLY idx_comments_post_created 
ON comments(post_id, inserted_at DESC) WHERE deleted_at IS NULL;

-- Audit log partitioning and indexing
CREATE INDEX CONCURRENTLY idx_audit_logs_user_action_date 
ON audit_logs(user_id, action, inserted_at DESC);
```

#### Index Maintenance
```sql
-- Monitor index usage
SELECT 
    schemaname,
    tablename,
    indexname,
    idx_scan,
    idx_tup_read,
    idx_tup_fetch
FROM pg_stat_user_indexes
ORDER BY idx_scan;

-- Find unused indexes
SELECT 
    schemaname,
    tablename,
    indexname,
    pg_size_pretty(pg_relation_size(indexrelid)) as size
FROM pg_stat_user_indexes
WHERE idx_scan = 0
ORDER BY pg_relation_size(indexrelid) DESC;

-- Reindex maintenance
REINDEX INDEX CONCURRENTLY idx_posts_full_text;
```

### Query Optimization

#### Connection Pooling Configuration
```elixir
# config/prod.exs - Optimized pool settings
config :prismatic, Prismatic.Repo,
  pool_size: 20,
  queue_target: 5000,
  queue_interval: 5000,
  checkout_timeout: 15_000,
  ownership_timeout: 30_000,
  timeout: 15_000,
  # Connection parameters
  parameters: [
    plan_cache_mode: "force_custom_plan",
    default_transaction_isolation: "read_committed"
  ]
```

#### PgBouncer Setup
```ini
# pgbouncer.ini
[databases]
prismatic_prod = host=localhost port=5432 dbname=prismatic_prod

[pgbouncer]
listen_port = 6432
listen_addr = 127.0.0.1
auth_type = md5
auth_file = /etc/pgbouncer/userlist.txt

# Pool configuration
pool_mode = transaction
max_client_conn = 1000
default_pool_size = 50
min_pool_size = 10
reserve_pool_size = 10

# Connection limits
server_lifetime = 3600
server_idle_timeout = 600
server_connect_timeout = 15
server_login_retry = 15

# Performance tuning
ignore_startup_parameters = extra_float_digits

# Logging
log_connections = 1
log_disconnections = 1
log_pooler_errors = 1
```

### Memory and Storage Optimization

#### Vacuum and Analyze Configuration
```sql
-- Configure autovacuum for optimal performance
ALTER TABLE users SET (
  autovacuum_vacuum_threshold = 1000,
  autovacuum_analyze_threshold = 1000,
  autovacuum_vacuum_scale_factor = 0.1,
  autovacuum_analyze_scale_factor = 0.05
);

ALTER TABLE posts SET (
  autovacuum_vacuum_threshold = 500,
  autovacuum_analyze_threshold = 500,
  autovacuum_vacuum_scale_factor = 0.1,
  autovacuum_analyze_scale_factor = 0.05
);

-- High-volume tables
ALTER TABLE audit_logs SET (
  autovacuum_vacuum_threshold = 10000,
  autovacuum_analyze_threshold = 10000,
  autovacuum_vacuum_scale_factor = 0.05,
  autovacuum_analyze_scale_factor = 0.02
);
```

#### Table Partitioning
```sql
-- Partition audit_logs by month
CREATE TABLE audit_logs_2024_01 PARTITION OF audit_logs
FOR VALUES FROM ('2024-01-01') TO ('2024-02-01');

CREATE TABLE audit_logs_2024_02 PARTITION OF audit_logs
FOR VALUES FROM ('2024-02-01') TO ('2024-03-01');

-- Create partition maintenance function
CREATE OR REPLACE FUNCTION create_monthly_partition(table_name text, start_date date)
RETURNS void AS $$
DECLARE
    partition_name text;
    end_date date;
BEGIN
    partition_name := table_name || '_' || to_char(start_date, 'YYYY_MM');
    end_date := start_date + interval '1 month';
    
    EXECUTE format('CREATE TABLE %I PARTITION OF %I
                    FOR VALUES FROM (%L) TO (%L)',
                   partition_name, table_name, start_date, end_date);
    
    EXECUTE format('CREATE INDEX %I ON %I (inserted_at)',
                   partition_name || '_inserted_at_idx', partition_name);
END;
$$ LANGUAGE plpgsql;
```

## Security Configuration

### User Management

#### Role-Based Security
```sql
-- Create roles for different access levels
CREATE ROLE prismatic_readonly;
CREATE ROLE prismatic_readwrite;
CREATE ROLE prismatic_admin;

-- Readonly permissions
GRANT CONNECT ON DATABASE prismatic_prod TO prismatic_readonly;
GRANT USAGE ON SCHEMA public TO prismatic_readonly;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO prismatic_readonly;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO prismatic_readonly;

-- Read-write permissions
GRANT prismatic_readonly TO prismatic_readwrite;
GRANT INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO prismatic_readwrite;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO prismatic_readwrite;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT INSERT, UPDATE, DELETE ON TABLES TO prismatic_readwrite;

-- Admin permissions
GRANT prismatic_readwrite TO prismatic_admin;
GRANT CREATE ON SCHEMA public TO prismatic_admin;

-- Create specific users
CREATE USER app_user WITH PASSWORD 'secure_app_password' CONNECTION LIMIT 50;
CREATE USER backup_user WITH PASSWORD 'secure_backup_password' CONNECTION LIMIT 5;
CREATE USER analytics_user WITH PASSWORD 'secure_analytics_password' CONNECTION LIMIT 10;

GRANT prismatic_readwrite TO app_user;
GRANT prismatic_readonly TO backup_user;
GRANT prismatic_readonly TO analytics_user;
```

#### Row Level Security
```sql
-- Enable RLS on sensitive tables
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE posts ENABLE ROW LEVEL SECURITY;

-- Create policies for multi-tenant access
CREATE POLICY user_own_data ON users
    FOR ALL 
    TO prismatic_readwrite
    USING (id = current_setting('app.current_user_id')::uuid);

CREATE POLICY organization_data ON posts
    FOR ALL
    TO prismatic_readwrite
    USING (organization_id = current_setting('app.current_org_id')::uuid);

-- Function to set current user context
CREATE OR REPLACE FUNCTION set_current_user_id(user_id uuid)
RETURNS void AS $$
BEGIN
    PERFORM set_config('app.current_user_id', user_id::text, true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

### Data Encryption

#### Transparent Data Encryption
```sql
-- Encrypt sensitive columns
ALTER TABLE users 
ADD COLUMN encrypted_ssn bytea,
ADD COLUMN encrypted_phone bytea;

-- Create encryption functions
CREATE OR REPLACE FUNCTION encrypt_pii(data text, key_id text DEFAULT 'user_pii')
RETURNS bytea AS $$
BEGIN
    RETURN pgp_sym_encrypt(data, current_setting('app.encryption_key'));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION decrypt_pii(encrypted_data bytea)
RETURNS text AS $$
BEGIN
    RETURN pgp_sym_decrypt(encrypted_data, current_setting('app.encryption_key'));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

## Backup and Recovery

### Backup Strategy

#### Automated Backup Script
```bash
#!/bin/bash
# scripts/postgres_backup.sh

set -e

# Configuration
DB_NAME="prismatic_prod"
DB_USER="backup_user"
BACKUP_DIR="/var/backups/postgresql"
S3_BUCKET="prismatic-db-backups"
RETENTION_DAYS=30

# Create backup directory
mkdir -p ${BACKUP_DIR}

# Generate backup filename with timestamp
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="${BACKUP_DIR}/prismatic_${TIMESTAMP}.sql.gz"
WAL_BACKUP_DIR="${BACKUP_DIR}/wal_${TIMESTAMP}"

echo "Starting backup at $(date)"

# Create full database backup
pg_dump -h localhost -U ${DB_USER} -d ${DB_NAME} \
    --no-password \
    --verbose \
    --format=custom \
    --compress=9 \
    --file=${BACKUP_FILE%.gz}

# Compress backup
gzip ${BACKUP_FILE%.gz}

# Create WAL archive backup
mkdir -p ${WAL_BACKUP_DIR}
pg_receivewal -h localhost -U ${DB_USER} \
    --no-password \
    --directory=${WAL_BACKUP_DIR} \
    --compress=9 \
    --synchronous

# Upload to S3
aws s3 cp ${BACKUP_FILE} s3://${S3_BUCKET}/daily/ \
    --storage-class STANDARD_IA

aws s3 sync ${WAL_BACKUP_DIR} s3://${S3_BUCKET}/wal/${TIMESTAMP}/ \
    --storage-class GLACIER

# Cleanup local files older than retention period
find ${BACKUP_DIR} -name "prismatic_*.sql.gz" -mtime +${RETENTION_DAYS} -delete
find ${BACKUP_DIR} -name "wal_*" -mtime +${RETENTION_DAYS} -exec rm -rf {} +

echo "Backup completed at $(date)"
echo "Backup file: ${BACKUP_FILE}"
echo "Size: $(du -h ${BACKUP_FILE} | cut -f1)"
```

#### Continuous WAL Archiving
```conf
# postgresql.conf for WAL archiving
wal_level = replica
archive_mode = on
archive_command = '/usr/local/bin/wal_archive.sh %p %f'
archive_timeout = 300  # 5 minutes
```

```bash
#!/bin/bash
# /usr/local/bin/wal_archive.sh

WAL_PATH=$1
WAL_FILE=$2
ARCHIVE_DIR="/var/lib/postgresql/wal_archive"
S3_BUCKET="prismatic-wal-archive"

# Create local archive directory
mkdir -p ${ARCHIVE_DIR}

# Copy WAL file to local archive
cp ${WAL_PATH} ${ARCHIVE_DIR}/${WAL_FILE}

# Upload to S3
aws s3 cp ${ARCHIVE_DIR}/${WAL_FILE} s3://${S3_BUCKET}/wal/${WAL_FILE} \
    --storage-class GLACIER_IR

# Verify upload and cleanup
if aws s3 ls s3://${S3_BUCKET}/wal/${WAL_FILE} > /dev/null; then
    rm ${ARCHIVE_DIR}/${WAL_FILE}
    exit 0
else
    exit 1
fi
```

### Point-in-Time Recovery

#### Recovery Procedures
```bash
#!/bin/bash
# scripts/postgres_restore.sh

set -e

BACKUP_FILE=$1
RECOVERY_TARGET_TIME=$2
RECOVERY_DIR="/var/lib/postgresql/recovery"

if [ -z "$BACKUP_FILE" ]; then
    echo "Usage: $0 <backup_file> [recovery_target_time]"
    exit 1
fi

# Stop PostgreSQL
sudo systemctl stop postgresql

# Create recovery directory
sudo -u postgres mkdir -p ${RECOVERY_DIR}
sudo -u postgres chmod 700 ${RECOVERY_DIR}

# Restore base backup
sudo -u postgres pg_restore \
    --verbose \
    --clean \
    --create \
    --dbname=postgres \
    ${BACKUP_FILE}

# Setup recovery configuration
sudo -u postgres cat > ${RECOVERY_DIR}/recovery.signal << EOF
# Recovery signal file
EOF

if [ -n "$RECOVERY_TARGET_TIME" ]; then
    sudo -u postgres cat >> /var/lib/postgresql/16/main/postgresql.conf << EOF
# Point-in-time recovery settings
restore_command = '/usr/local/bin/wal_restore.sh %f %p'
recovery_target_time = '${RECOVERY_TARGET_TIME}'
recovery_target_action = 'promote'
EOF
fi

# Start PostgreSQL
sudo systemctl start postgresql

echo "Recovery completed. Check logs for any issues."
```

## Monitoring and Maintenance

### Database Monitoring

#### Performance Monitoring Queries
```sql
-- Monitor active connections
SELECT 
    datname,
    usename,
    client_addr,
    state,
    query_start,
    NOW() - query_start AS duration,
    query
FROM pg_stat_activity
WHERE state != 'idle'
ORDER BY duration DESC;

-- Monitor slow queries
SELECT 
    calls,
    total_time,
    mean_time,
    stddev_time,
    rows,
    100.0 * shared_blks_hit / nullif(shared_blks_hit + shared_blks_read, 0) AS hit_percent,
    query
FROM pg_stat_statements
ORDER BY mean_time DESC
LIMIT 10;

-- Monitor table sizes
SELECT 
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size,
    pg_size_pretty(pg_relation_size(schemaname||'.'||tablename)) AS table_size,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename) - pg_relation_size(schemaname||'.'||tablename)) AS index_size
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;

-- Monitor replication lag (if using streaming replication)
SELECT 
    client_addr,
    state,
    pg_wal_lsn_diff(pg_current_wal_lsn(), flush_lsn) AS flush_lag_bytes,
    pg_wal_lsn_diff(pg_current_wal_lsn(), replay_lsn) AS replay_lag_bytes
FROM pg_stat_replication;
```

#### Automated Health Checks
```bash
#!/bin/bash
# scripts/db_health_check.sh

DB_NAME="prismatic_prod"
DB_USER="monitor_user"
ALERT_EMAIL="ops@example.com"

# Check database connectivity
if ! psql -h localhost -U ${DB_USER} -d ${DB_NAME} -c "SELECT 1;" > /dev/null 2>&1; then
    echo "CRITICAL: Database connection failed" | mail -s "DB Alert" ${ALERT_EMAIL}
    exit 1
fi

# Check for long-running queries (>5 minutes)
LONG_QUERIES=$(psql -h localhost -U ${DB_USER} -d ${DB_NAME} -t -c "
    SELECT COUNT(*) FROM pg_stat_activity 
    WHERE state != 'idle' AND NOW() - query_start > interval '5 minutes';
")

if [ ${LONG_QUERIES} -gt 0 ]; then
    echo "WARNING: ${LONG_QUERIES} long-running queries detected" | mail -s "DB Alert" ${ALERT_EMAIL}
fi

# Check disk space
DISK_USAGE=$(df /var/lib/postgresql | awk 'NR==2 {print $5}' | sed 's/%//')
if [ ${DISK_USAGE} -gt 85 ]; then
    echo "WARNING: Database disk usage is ${DISK_USAGE}%" | mail -s "DB Alert" ${ALERT_EMAIL}
fi

# Check connection count
CONN_COUNT=$(psql -h localhost -U ${DB_USER} -d ${DB_NAME} -t -c "
    SELECT COUNT(*) FROM pg_stat_activity WHERE datname = '${DB_NAME}';
")

MAX_CONN=$(psql -h localhost -U ${DB_USER} -d ${DB_NAME} -t -c "SHOW max_connections;")
CONN_PERCENT=$((CONN_COUNT * 100 / MAX_CONN))

if [ ${CONN_PERCENT} -gt 80 ]; then
    echo "WARNING: Connection usage is ${CONN_PERCENT}% (${CONN_COUNT}/${MAX_CONN})" | mail -s "DB Alert" ${ALERT_EMAIL}
fi

echo "Database health check completed successfully"
```

### Maintenance Tasks

#### Routine Maintenance Script
```bash
#!/bin/bash
# scripts/db_maintenance.sh

DB_NAME="prismatic_prod"
DB_USER="maintenance_user"
LOG_FILE="/var/log/postgresql/maintenance.log"

echo "Starting database maintenance at $(date)" >> ${LOG_FILE}

# Update table statistics
echo "Updating statistics..." >> ${LOG_FILE}
psql -h localhost -U ${DB_USER} -d ${DB_NAME} -c "ANALYZE;" >> ${LOG_FILE} 2>&1

# Vacuum high-activity tables
echo "Vacuuming high-activity tables..." >> ${LOG_FILE}
psql -h localhost -U ${DB_USER} -d ${DB_NAME} -c "VACUUM (ANALYZE, VERBOSE) users;" >> ${LOG_FILE} 2>&1
psql -h localhost -U ${DB_USER} -d ${DB_NAME} -c "VACUUM (ANALYZE, VERBOSE) posts;" >> ${LOG_FILE} 2>&1
psql -h localhost -U ${DB_USER} -d ${DB_NAME} -c "VACUUM (ANALYZE, VERBOSE) comments;" >> ${LOG_FILE} 2>&1

# Clean up old audit logs (older than 1 year)
echo "Cleaning up old audit logs..." >> ${LOG_FILE}
psql -h localhost -U ${DB_USER} -d ${DB_NAME} -c "
    DELETE FROM audit_logs 
    WHERE inserted_at < NOW() - INTERVAL '1 year';
" >> ${LOG_FILE} 2>&1

# Reindex if fragmentation is high
echo "Checking index fragmentation..." >> ${LOG_FILE}
psql -h localhost -U ${DB_USER} -d ${DB_NAME} -c "
    SELECT 
        schemaname, 
        tablename, 
        indexname,
        pg_size_pretty(pg_relation_size(indexrelid)) as size
    FROM pg_stat_user_indexes 
    WHERE pg_relation_size(indexrelid) > 100000000  -- 100MB
    ORDER BY pg_relation_size(indexrelid) DESC;
" >> ${LOG_FILE} 2>&1

echo "Database maintenance completed at $(date)" >> ${LOG_FILE}
```

## Troubleshooting

### Common Issues

#### Connection Issues
```sql
-- Check connection limits
SELECT 
    setting AS max_connections,
    (SELECT COUNT(*) FROM pg_stat_activity) AS current_connections,
    setting::int - (SELECT COUNT(*) FROM pg_stat_activity) AS available_connections
FROM pg_settings 
WHERE name = 'max_connections';

-- Kill problematic connections
SELECT pg_terminate_backend(pid)
FROM pg_stat_activity
WHERE state = 'idle in transaction'
AND state_change < NOW() - INTERVAL '1 hour';
```

#### Performance Issues
```sql
-- Find blocking queries
SELECT 
    blocked_locks.pid AS blocked_pid,
    blocked_activity.usename AS blocked_user,
    blocking_locks.pid AS blocking_pid,
    blocking_activity.usename AS blocking_user,
    blocked_activity.query AS blocked_statement,
    blocking_activity.query AS blocking_statement
FROM pg_catalog.pg_locks blocked_locks
JOIN pg_catalog.pg_stat_activity blocked_activity ON blocked_activity.pid = blocked_locks.pid
JOIN pg_catalog.pg_locks blocking_locks ON blocking_locks.locktype = blocked_locks.locktype
JOIN pg_catalog.pg_stat_activity blocking_activity ON blocking_activity.pid = blocking_locks.pid
WHERE NOT blocked_locks.granted AND blocking_locks.granted;

-- Check for table bloat
SELECT 
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS total_size,
    pg_size_pretty(pg_relation_size(schemaname||'.'||tablename)) AS table_size,
    ROUND(100 * pg_relation_size(schemaname||'.'||tablename)::numeric / pg_total_relation_size(schemaname||'.'||tablename), 2) AS table_percent
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;
```

#### Recovery Procedures
```bash
# Emergency read-only mode
psql -c "ALTER SYSTEM SET default_transaction_read_only = on;"
psql -c "SELECT pg_reload_conf();"

# Reset statistics
psql -c "SELECT pg_stat_reset();"
psql -c "SELECT pg_stat_statements_reset();"

# Force checkpoint
psql -c "CHECKPOINT;"
```

## Related Documentation

- [Database Schema](../reference/database-schema.md) - Complete database schema and relationship documentation
- [Configuration Examples](../reference/config-example.md) - Application database configuration examples
- [Performance Optimization](../guides/performance-optimization.md) - Database performance tuning strategies
- [Security Guidelines](../guides/security-guidelines.md) - Database security best practices
- [Monitoring Setup](monitoring-setup.md) - Database monitoring and alerting configuration
- [Deployment Procedures](deployment-procedures.md) - Database deployment and migration procedures

---

**Database setup and maintenance are critical for application reliability and performance. Regular monitoring, maintenance, and backup verification are essential operational practices.**