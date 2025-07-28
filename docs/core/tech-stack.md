# Technology Stack

Detailed breakdown of technologies, libraries, and tools used in the Prismatic project.

## Backend Technologies

### Core Runtime
**Elixir 1.14+**
- **Purpose**: Primary programming language
- **Benefits**: Fault tolerance, concurrency, functional programming
- **Usage**: All business logic and web server implementation
- **Documentation**: [Elixir Guides](https://elixir-lang.org/getting-started/introduction.html)

**OTP (Open Telecom Platform)**
- **Purpose**: Actor-based concurrency and fault tolerance
- **Benefits**: Supervision trees, hot code reloading, distribution
- **Usage**: Application supervision, GenServer processes, PubSub
- **Key Concepts**: See [glossary](../reference/glossary.md#otp-open-telecom-platform)

### Web Framework
**Phoenix 1.7.21**
- **Purpose**: Web application framework
- **Benefits**: Real-time features, productivity, performance
- **Usage**: HTTP handling, routing, controllers, LiveView
- **Configuration**: [`apps/prismatic_web/mix.exs`](../../apps/prismatic_web/mix.exs)

**Phoenix LiveView**
- **Purpose**: Interactive, real-time web interfaces
- **Benefits**: Server-rendered, minimal JavaScript, real-time updates
- **Usage**: Dynamic UI components, forms, real-time dashboards
- **Examples**: User management interfaces, content editing

### Database Stack
**PostgreSQL 12+**
- **Purpose**: Primary data store
- **Benefits**: ACID compliance, advanced features, performance
- **Usage**: Application data, user sessions, business records
- **Configuration**: [`config/dev.exs`](../../config/dev.exs#L3-L11)

**Ecto 3.10+**
- **Purpose**: Database wrapper and query builder
- **Benefits**: Type safety, migrations, associations
- **Usage**: All database operations, schema definitions, queries
- **Repository**: [`apps/prismatic/lib/prismatic/repo.ex`](../../apps/prismatic/lib/prismatic/repo.ex)

### HTTP Server
**Bandit 1.5+**
- **Purpose**: HTTP/1.1 and HTTP/2 server
- **Benefits**: Modern protocol support, performance, WebSocket support
- **Usage**: Production HTTP server (replaces Cowboy)
- **Configuration**: [`config/config.exs`](../../config/config.exs#L32)

## Frontend Technologies

### UI Framework
**Phoenix LiveView**
- **Purpose**: Server-rendered interactive interfaces
- **Benefits**: Real-time updates, form handling, no complex JavaScript
- **Usage**: All user interfaces, forms, dashboards
- **Templates**: HEEx (HTML with Elixir expressions)

### Styling System
**Tailwind CSS 3.4.3**
- **Purpose**: Utility-first CSS framework
- **Benefits**: Rapid development, consistent design, small bundle size
- **Usage**: All application styling
- **Configuration**: [`apps/prismatic_web/assets/tailwind.config.js`](../../apps/prismatic_web/assets/tailwind.config.js)

**Heroicons**
- **Purpose**: SVG icon library
- **Benefits**: Consistent iconography, optimized SVGs, Tailwind integration
- **Usage**: UI icons throughout the application
- **Implementation**: Phoenix component integration

### Asset Pipeline
**esbuild 0.17.11**
- **Purpose**: JavaScript bundling and transpilation
- **Benefits**: Fast builds, ES2017+ support, tree shaking
- **Usage**: JavaScript compilation and bundling
- **Configuration**: [`config/config.exs`](../../config/config.exs#L40-L48)

**Native CSS Processing**
- **Purpose**: CSS compilation and optimization
- **Benefits**: Fast processing, PostCSS compatibility, Tailwind integration
- **Usage**: Stylesheet processing and optimization

## Communication & Integration

### Email System
**Swoosh 1.5+**
- **Purpose**: Email composition and delivery
- **Benefits**: Multiple adapter support, testing capabilities, templates
- **Usage**: User notifications, system emails, marketing emails
- **Configuration**: Local adapter for development, SMTP for production

**Finch 0.13+**
- **Purpose**: HTTP client for external API calls
- **Benefits**: Connection pooling, HTTP/2 support, telemetry integration
- **Usage**: External service integration, webhook delivery
- **Implementation**: Supervised pool configuration

### Real-time Communication
**Phoenix PubSub**
- **Purpose**: Process-to-process messaging and broadcasting
- **Benefits**: Real-time updates, scalable messaging, LiveView integration
- **Usage**: Live updates, notifications, cross-context communication
- **Implementation**: Redis adapter for distributed systems

**Phoenix Channels (WebSocket)**
- **Purpose**: Bidirectional real-time communication
- **Benefits**: Low-latency updates, connection management, presence tracking
- **Usage**: Live features, real-time collaboration, notifications

## Development Tools

### Code Quality
**ExUnit**
- **Purpose**: Built-in testing framework
- **Benefits**: Concurrent testing, comprehensive assertions, doctests
- **Usage**: All application testing
- **Configuration**: [`apps/prismatic/test/test_helper.exs`](../../apps/prismatic/test/test_helper.exs)

**Credo (Optional)**
- **Purpose**: Static code analysis
- **Benefits**: Code quality checks, consistency enforcement, best practices
- **Usage**: CI/CD pipeline, development workflow
- **Configuration**: `.credo.exs` (when configured)

**Dialyzer (Optional)**
- **Purpose**: Static type analysis
- **Benefits**: Type error detection, contract verification, bug finding
- **Usage**: Pre-deployment checks, type safety validation
- **Implementation**: PLT (Persistent Lookup Table) based

### Asset Development
**Tailwind CSS Standalone**
- **Purpose**: CSS utility generation
- **Benefits**: No Node.js dependency, fast compilation, JIT mode
- **Usage**: Development and production CSS generation
- **Watch Mode**: Automatic recompilation during development

**Live Reload**
- **Purpose**: Automatic browser refresh during development
- **Benefits**: Rapid feedback, seamless development experience
- **Usage**: File change detection and browser updates
- **Configuration**: [`config/dev.exs`](../../config/dev.exs#L55-L63)

## Monitoring & Observability

### Application Monitoring
**Phoenix LiveDashboard**
- **Purpose**: Real-time application metrics and monitoring
- **Benefits**: Performance insights, process monitoring, system health
- **Usage**: Development debugging, production monitoring
- **Access**: [`/dev/dashboard`](http://localhost:4000/dev/dashboard) in development

**Telemetry**
- **Purpose**: Application metrics collection and reporting
- **Benefits**: Performance monitoring, custom metrics, integration support
- **Usage**: Response time tracking, business metrics, error rates
- **Implementation**: Event-based metrics collection

### Development Monitoring
**Phoenix Code Reloader**
- **Purpose**: Automatic code reloading during development  
- **Benefits**: Faster development cycle, preserved application state
- **Usage**: Development environment only
- **Integration**: Built into Phoenix development server

**Ecto SQL Logging**
- **Purpose**: Database query logging and analysis
- **Benefits**: Performance debugging, N+1 query detection, optimization
- **Usage**: Development debugging, performance analysis
- **Configuration**: Logger level configuration

## External Services

### DNS & Clustering
**DNS Cluster**
- **Purpose**: Service discovery for distributed systems
- **Benefits**: Automatic node discovery, scalability, fault tolerance
- **Usage**: Multi-node deployments, load balancing
- **Configuration**: Environment-based query configuration

### Security
**Built-in Phoenix Security**
- **CSRF Protection**: Automatic token generation and validation
- **XSS Prevention**: Template escaping by default
- **Session Security**: Signed and encrypted cookies
- **Header Security**: Configurable security headers

## Data Processing

### JSON Handling
**Jason 1.2+**
- **Purpose**: JSON encoding and decoding
- **Benefits**: Performance, standards compliance, Phoenix integration
- **Usage**: API responses, configuration parsing, data serialization
- **Configuration**: Default Phoenix JSON library

### Background Processing
**Task/GenServer (Built-in)**
- **Purpose**: Asynchronous task processing
- **Benefits**: Fault tolerance, supervision, concurrency
- **Usage**: Email sending, data processing, scheduled tasks
- **Implementation**: OTP supervision trees

## Development Dependencies

### Database Extensions
**Ecto PSQL Extras**
- **Purpose**: PostgreSQL performance insights
- **Benefits**: Query analysis, index usage, performance monitoring
- **Usage**: Database optimization, performance debugging
- **Integration**: LiveDashboard integration

### Testing Support
**Floki (Test Environment)**
- **Purpose**: HTML parsing and manipulation for tests
- **Benefits**: Integration testing, HTML validation, content verification
- **Usage**: LiveView testing, HTML content assertions
- **Scope**: Test environment only

## Version Management

### Language Versions
- **Elixir**: ~> 1.14 (specified in `.tool-versions`)
- **Erlang/OTP**: Compatible with Elixir version
- **Node.js**: 16+ for asset compilation
- **PostgreSQL**: 12+ for database features

### Dependency Management
- **Hex Package Manager**: Elixir dependency management
- **Mix**: Build tool and task runner
- **Lock File**: [`mix.lock`](../../mix.lock) for reproducible builds

## Related Documentation
- [Architecture Overview](architecture-overview.md) - How technologies work together
- [Developer Experience](../guides/developer-experience.md) - Development workflow with these tools  
- [Deployment Procedures](../operations/deployment-procedures.md) - Production technology configuration
- [Troubleshooting](../operations/troubleshooting.md) - Technology-specific issue resolution