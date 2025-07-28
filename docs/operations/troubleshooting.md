# Troubleshooting

Common development and production issues with step-by-step solutions.

## Development Environment Issues

### Application Won't Start

**Symptom**: `mix phx.server` fails or application crashes on startup

**Common Causes & Solutions**:

1. **Port Already in Use**
   ```bash
   # Find process using port 4000
   lsof -i :4000
   
   # Kill the process
   kill -9 <PID>
   
   # Or change port in config/dev.exs
   config :prismatic_web, PrismaticWeb.Endpoint,
     http: [ip: {127, 0, 0, 1}, port: 4001]
   ```

2. **Database Connection Failed**
   ```bash
   # Check PostgreSQL is running
   brew services list | grep postgres
   
   # Start PostgreSQL
   brew services start postgresql
   
   # Verify database exists
   psql -l | grep prismatic_dev
   
   # Create database if missing
   mix ecto.create
   ```

3. **Missing Dependencies**
   ```bash
   # Clean and reinstall dependencies
   rm -rf _build deps
   mix deps.get
   mix compile
   ```

### Asset Compilation Errors

**Symptom**: CSS/JavaScript assets not loading or compilation failures

**Solutions**:
1. **Clear Asset Cache**
   ```bash
   rm -rf priv/static/assets
   mix assets.build
   ```

2. **Node.js Dependencies**
   ```bash
   cd apps/prismatic_web/assets
   npm install
   cd ../../..
   mix assets.build
   ```

3. **Tailwind Configuration Issues**
   - Check `apps/prismatic_web/assets/tailwind.config.js`
   - Verify paths in `config/config.exs` tailwind configuration
   - Ensure `@tailwind` directives are in `app.css`

### Database Migration Issues

**Symptom**: Migration fails or database schema inconsistencies

**Solutions**:
1. **Migration Conflicts**
   ```bash
   # Check migration status
   mix ecto.migrations
   
   # Rollback specific migration
   mix ecto.rollback -n 1
   
   # Reset database (development only)
   mix ecto.reset
   ```

2. **Schema Compilation Errors**
   ```bash
   # Drop and recreate database
   mix ecto.drop
   mix ecto.create
   mix ecto.migrate
   ```

## LiveView Common Issues

### Mount Errors

**Symptom**: LiveView fails to mount or crashes during mount

**Debugging Steps**:
1. **Check Mount Function**
   ```elixir
   def mount(params, session, socket) do
     # Add debugging
     IO.inspect(params, label: "Mount params")
     IO.inspect(session, label: "Mount session")
     
     {:ok, socket}
   end
   ```

2. **Verify Session Data**
   - Ensure required session keys exist
   - Check authentication state
   - Validate user permissions

3. **Database Connection Issues**
   ```elixir
   def mount(_params, _session, socket) do
     try do
       data = MyContext.get_data()
       {:ok, assign(socket, :data, data)}
     rescue
       Ecto.NoResultsError ->
         {:ok, assign(socket, :data, [])}
     end
   end
   ```

### Real-time Update Problems

**Symptom**: LiveView doesn't update when data changes

**Solutions**:
1. **PubSub Subscription Issues**
   ```elixir
   def mount(_params, _session, socket) do
     if connected?(socket) do
       Phoenix.PubSub.subscribe(Prismatic.PubSub, "topic")
     end
     {:ok, socket}
   end
   ```

2. **Handle Info Implementation**
   ```elixir
   def handle_info({:data_updated, data}, socket) do
     {:noreply, stream_insert(socket, :items, data)}
   end
   ```

## Testing Issues

### Test Database Problems

**Symptom**: Tests fail due to database issues

**Solutions**:
1. **Test Database Setup**
   ```bash
   MIX_ENV=test mix ecto.create
   MIX_ENV=test mix ecto.migrate
   ```

2. **Async Test Conflicts**
   ```elixir
   # Disable async for tests using shared state
   use Prismatic.DataCase, async: false
   ```

3. **Factory/Fixture Issues**
   ```elixir
   # Ensure test data is properly isolated
   setup do
     :ok = Ecto.Adapters.SQL.Sandbox.checkout(Prismatic.Repo)
   end
   ```

### Flaky Tests

**Symptom**: Tests pass sometimes but fail randomly

**Common Causes**:
1. **Race Conditions**
   - Add proper `Process.sleep/1` or better synchronization
   - Use `eventually/2` helpers for async operations

2. **Shared State**
   - Ensure tests clean up after themselves
   - Use `ExUnit.Case, async: false` when necessary

3. **Time-Dependent Logic**
   ```elixir
   # Mock time-dependent functions
   defp now, do: DateTime.utc_now()
   
   # In tests
   test "time-sensitive operation" do
     with_mock DateTime, [utc_now: fn -> ~U[2023-01-01 00:00:00Z] end] do
       # Test implementation
     end
   end
   ```

## Production Issues

### Application Performance

**Symptom**: Slow response times or high resource usage

**Diagnosis Steps**:
1. **Check LiveDashboard Metrics**
   - Visit `/dev/dashboard` in development
   - Monitor response times, memory usage, process counts

2. **Database Query Analysis**
   ```elixir
   # Enable query logging in config
   config :logger, level: :debug
   
   # Look for N+1 queries in logs
   # Add preloading where needed
   ```

3. **Memory Leaks**
   ```bash
   # Monitor memory usage
   :observer.start()
   
   # Check for growing processes
   Process.list() |> Enum.map(&Process.info/1)
   ```

### Database Connection Issues

**Symptom**: Database connection errors in production

**Solutions**:
1. **Connection Pool Configuration**
   ```elixir
   config :prismatic, Prismatic.Repo,
     pool_size: 15,
     queue_target: 50,
     queue_interval: 1000
   ```

2. **Connection Timeout Issues**
   ```elixir
   config :prismatic, Prismatic.Repo,
     timeout: 15_000,
     pool_timeout: 5_000
   ```

### SSL/HTTPS Problems

**Symptom**: SSL certificate errors or HTTPS not working

**Debugging**:
1. **Certificate Validation**
   ```bash
   # Check certificate expiration
   openssl s_client -connect yourdomain.com:443 -servername yourdomain.com
   ```

2. **Phoenix HTTPS Configuration**
   ```elixir
   config :prismatic_web, PrismaticWeb.Endpoint,
     https: [
       port: 443,
       cipher_suite: :strong,
       otp_app: :prismatic_web,
       keyfile: "priv/cert/privkey.pem",
       certfile: "priv/cert/fullchain.pem"
     ]
   ```

## Error Investigation Process

### Systematic Debugging
1. **Reproduce the Issue**
   - Document exact steps to reproduce
   - Note environment conditions (development, staging, production)
   - Collect error messages and stack traces

2. **Check Recent Changes**
   ```bash
   # Review recent commits
   git log --oneline -10
   
   # Check what changed in specific files
   git show HEAD~1..HEAD -- path/to/file
   ```

3. **Examine Logs**
   ```bash
   # Development logs
   tail -f log/dev.log
   
   # Production logs (varies by deployment)
   heroku logs --tail  # For Heroku
   kubectl logs -f pod-name  # For Kubernetes
   ```

4. **Use IEx for Live Debugging**
   ```elixir
   # Add to code for investigation
   require IEx; IEx.pry()
   
   # Remote console (production)
   # Varies by deployment method
   ```

### Performance Investigation
1. **Identify Bottlenecks**
   - Use Phoenix LiveDashboard
   - Check database query performance
   - Monitor process mailbox sizes

2. **Memory Analysis**
   ```elixir
   # Check memory usage
   :erlang.memory()
   
   # Process memory
   Process.info(self(), :memory)
   ```

3. **Database Query Optimization**
   ```sql
   -- Check slow queries (PostgreSQL)
   SELECT query, mean_time, calls 
   FROM pg_stat_statements 
   ORDER BY mean_time DESC LIMIT 10;
   ```

## Getting Help

### Internal Resources
- Review [architecture overview](../core/architecture-overview.md) for system understanding
- Check [coding standards](../guides/coding-standards.md) for best practices
- Consult [deployment procedures](deployment-procedures.md) for production issues

### External Resources
- [Phoenix Guides](https://hexdocs.pm/phoenix/overview.html)
- [Elixir Forum](https://elixirforum.com/) for community support  
- [Phoenix Discord](https://discord.gg/elixir) for real-time help

### Emergency Escalation
1. **Development Issues**: Contact tech lead or senior developer
2. **Production Outages**: Follow incident response procedure
3. **Security Issues**: Immediately contact security team

## Prevention Strategies

### Code Quality
- Run full test suite before deploying
- Use static analysis tools (`mix credo`, `mix dialyzer`)
- Implement proper error handling and logging

### Monitoring
- Set up application performance monitoring
- Configure alerting for error rates and response times
- Monitor resource usage trends

### Documentation
- Document known issues and solutions
- Update troubleshooting guide when resolving new problems
- Share solutions with team through knowledge base

## Related Documentation
- [Developer Experience](../guides/developer-experience.md) - Development workflow and common tasks
- [Deployment Procedures](deployment-procedures.md) - Production deployment process
- [Performance Optimization](../guides/performance-optimization.md) - Performance best practices
- [Architecture Overview](../core/architecture-overview.md) - System design for context