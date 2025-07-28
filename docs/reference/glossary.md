# Glossary

Comprehensive terminology reference for the Prismatic project with standardized formatting and strict alphabetical organization.

## Terms and Definitions

### ADR (Architecture Decision Record)
A document that captures an important architectural decision made along with its context and consequences.

An ADR provides a structured way to document significant architectural choices, ensuring that future developers understand not just what was decided, but why it was decided and what alternatives were considered. Each ADR follows a specific template and becomes part of the permanent project history, helping maintain architectural consistency over time.

**Related Documentation:**
- [ADR Template](../shared/templates/adr-template.md)
- [Architecture Overview](../core/architecture-overview.md#architectural-principles)
- [Example ADR](../architecture/adr-0001-umbrella-structure.md)

### API (Application Programming Interface)
A set of protocols, tools, and definitions for building and integrating application software.

In the Prismatic project, APIs define how different software components communicate with each other, including HTTP endpoints for external clients, function interfaces between modules, and data contracts between the core and web applications. The project uses RESTful conventions for HTTP APIs and follows Phoenix patterns for internal module APIs.

**Related Documentation:**
- [API Documentation](api-endpoints.md)
- [Coding Standards](../guides/coding-standards.md#api-design)
- [Phoenix API Guidelines](https://hexdocs.pm/phoenix/overview.html)

### Async Testing
A testing approach where tests run concurrently to improve execution speed and efficiency.

Async testing in Elixir allows multiple test cases to execute simultaneously, significantly reducing total test suite runtime. However, async tests cannot share state or resources, requiring careful design to ensure test isolation. Tests that modify shared resources like databases must use `async: false` to prevent race conditions.

**Related Documentation:**
- [Testing Standards](../guides/coding-standards.md#testing-standards)
- [Developer Experience](../guides/developer-experience.md#testing-approach)
- [ExUnit Documentation](https://hexdocs.pm/ex_unit/ExUnit.html)

### Bandit
A modern HTTP server for Elixir applications, supporting HTTP/1.1 and HTTP/2 protocols.

Bandit serves as the HTTP server for Prismatic in production environments, replacing the traditional Cowboy server. It provides better performance, lower memory usage, and native HTTP/2 support. Bandit integrates seamlessly with Phoenix applications and supports WebSocket connections for real-time features.

**Related Documentation:**
- [Technology Stack](../core/tech-stack.md#http-server)
- [Configuration Example](../../config/config.exs#L32)
- [Bandit Documentation](https://hexdocs.pm/bandit/)

### Blue-Green Deployment
A deployment strategy that uses two identical production environments to enable zero-downtime updates.

Blue-green deployment maintains two complete production environments (blue and green), with only one serving live traffic at any time. During deployment, the new version is deployed to the inactive environment, tested, and then traffic is switched over. This approach enables instant rollbacks and eliminates downtime during deployments.

**Related Documentation:**
- [Deployment Procedures](../operations/deployment-procedures.md#blue-green-deployment-strategy)
- [Architecture Overview](../core/architecture-overview.md#scalability-considerations)

### Changeset
An Ecto data structure that encapsulates changes to be made to a database record, including validations and constraints.

Changesets provide a functional approach to data validation and transformation in Elixir applications. They allow developers to define validation rules, cast user input to appropriate types, and track changes before persisting to the database. Changesets ensure data integrity and provide detailed error information when validation fails.

**Related Documentation:**
- [Coding Standards](../guides/coding-standards.md#database-standards)
- [Schema Example](../../apps/prismatic/lib/prismatic/accounts/user.ex)
- [Ecto Changeset Documentation](https://hexdocs.pm/ecto/Ecto.Changeset.html)

### Context
A bounded area of business logic in the Prismatic application that groups related functionality together.

Contexts represent business domains and provide clear APIs for accessing domain-specific functionality. In Prismatic's umbrella architecture, contexts live in the core application and encapsulate database access, business rules, and domain logic. Examples include `Prismatic.Accounts` for user management and `Prismatic.Content` for content operations.

**Related Documentation:**
- [Architecture Overview](../core/architecture-overview.md#context-driven-design)
- [Coding Standards](../guides/coding-standards.md#context-pattern)
- [Phoenix Context Guide](https://hexdocs.pm/phoenix/contexts.html)

### CSRF (Cross-Site Request Forgery)
A type of malicious exploit where unauthorized commands are transmitted from a user that the web application trusts.

CSRF attacks trick users into executing unwanted actions on applications where they're authenticated. Phoenix provides built-in CSRF protection through tokens that must be included with state-changing requests. The framework automatically generates and validates these tokens, preventing unauthorized actions from external sites.

**Related Documentation:**
- [Security Guidelines](../guides/security-guidelines.md#csrf-protection)
- [Phoenix Security](https://hexdocs.pm/phoenix/security.html)

### Ecto
Elixir's database wrapper and query generator that provides a type-safe interface to databases.

Ecto serves as Prismatic's primary database interaction layer, offering schema definitions, query composition, migrations, and connection management. It provides compile-time guarantees about query correctness and supports advanced features like preloading, transactions, and custom data types while maintaining database-agnostic query composition.

**Related Documentation:**
- [Technology Stack](../core/tech-stack.md#database-stack)
- [Repository Implementation](../../apps/prismatic/lib/prismatic/repo.ex)
- [Ecto Documentation](https://hexdocs.pm/ecto/)

### Endpoint
A Phoenix module that defines the HTTP server configuration and request/response processing pipeline.

The endpoint serves as the entry point for HTTP requests in Phoenix applications, configuring middleware, routing, and connection handling. In Prismatic, the endpoint handles SSL termination, static asset serving, session management, and routing delegation while providing hooks for monitoring and logging.

**Related Documentation:**
- [Web Architecture](../core/architecture-overview.md#integration-patterns)
- [Endpoint Configuration](../../apps/prismatic_web/lib/prismatic_web/endpoint.ex)
- [Phoenix Endpoint Guide](https://hexdocs.pm/phoenix/Phoenix.Endpoint.html)

### GenServer
An OTP behavior for building stateful server processes with standardized message handling patterns.

GenServer provides a foundation for creating concurrent, fault-tolerant server processes in Elixir applications. It handles message queuing, state management, and process lifecycle while offering hooks for initialization, cleanup, and error handling. GenServers form the backbone of many Elixir applications' concurrent architecture.

**Related Documentation:**
- [Technology Stack](../core/tech-stack.md#core-runtime)
- [Elixir GenServer Guide](https://elixir-lang.org/getting-started/genserver.html)

### Health Check
An endpoint that verifies application and infrastructure connectivity for monitoring systems.

Health checks provide automated ways to verify that the application is running correctly and can connect to essential services like databases and external APIs. They return structured responses indicating system status and are used by load balancers, monitoring systems, and deployment tools to make routing and scaling decisions.

**Related Documentation:**
- [Deployment Procedures](../operations/deployment-procedures.md#health-checks)
- [Monitoring Setup](../operations/monitoring-setup.md)
- [Example Implementation](../../apps/prismatic_web/lib/prismatic_web/controllers/health_controller.ex)

### IEx (Interactive Elixir)
The interactive shell for Elixir that provides real-time code execution and debugging capabilities.

IEx allows developers to interact with running Elixir applications, test functions, inspect state, and debug issues in real-time. It supports hot code reloading, process inspection, and provides powerful tools for understanding application behavior during development and troubleshooting production issues.

**Related Documentation:**
- [Developer Experience](../guides/developer-experience.md#interactive-development)
- [Troubleshooting](../operations/troubleshooting.md#error-investigation-process)
- [IEx Documentation](https://hexdocs.pm/iex/)

### LiveView
Phoenix framework feature for building interactive, real-time user interfaces with server-rendered HTML.

LiveView enables rich, interactive web applications without complex JavaScript frameworks by maintaining a persistent connection between client and server. It handles DOM updates, form processing, and real-time features while providing a familiar development model similar to traditional server-rendered applications but with modern interactivity.

**Related Documentation:**
- [Technology Stack](../core/tech-stack.md#frontend-architecture)
- [Coding Standards](../guides/coding-standards.md#liveview-patterns)
- [Phoenix LiveView Documentation](https://hexdocs.pm/phoenix_live_view/)

### Migration
A version-controlled database schema change that can be applied or rolled back systematically.

Database migrations provide a systematic way to evolve database schemas over time while maintaining consistency across different environments. Each migration is a script that defines both forward changes (up) and reverse changes (down), allowing teams to coordinate database changes and roll back problematic updates if necessary.

**Related Documentation:**
- [Deployment Procedures](../operations/deployment-procedures.md#database-deployment)
- [Migration Directory](../../apps/prismatic/priv/repo/migrations/)
- [Ecto Migrations Guide](https://hexdocs.pm/ecto_sql/Ecto.Migration.html)

### N+1 Query Problem
A database performance anti-pattern where one query triggers N additional queries, causing inefficient data access.

The N+1 problem occurs when code executes one query to fetch a list of records, then executes additional queries for each record to fetch related data. This results in (N+1) total queries instead of a single optimized query. Ecto's preloading feature solves this by fetching all related data in a single or minimal number of queries.

**Related Documentation:**
- [Performance Guidelines](../guides/performance-optimization.md#database-efficiency)
- [Coding Standards](../guides/coding-standards.md#query-optimization)

### OTP (Open Telecom Platform)
Elixir's actor-based concurrency framework providing fault-tolerance, distribution, and hot code swapping.

OTP is the foundation of Elixir's concurrent programming model, offering battle-tested patterns for building distributed, fault-tolerant systems. It includes supervision trees for managing process failures, behaviors like GenServer for common patterns, and tools for building scalable, maintainable applications that can handle thousands of concurrent operations.

**Related Documentation:**
- [Architecture Overview](../core/architecture-overview.md#technology-stack)
- [Technology Stack](../core/tech-stack.md#core-runtime)
- [OTP Design Principles](https://erlang.org/doc/design_principles/users_guide.html)

### Phoenix
A web framework for Elixir that provides high-performance, real-time web applications.

Phoenix serves as Prismatic's web application framework, offering routing, controllers, views, and real-time features built on top of Elixir's concurrent, fault-tolerant foundation. It includes LiveView for interactive interfaces, Channels for real-time communication, and extensive tooling for productive web development.

**Related Documentation:**
- [Technology Stack](../core/tech-stack.md#web-framework)
- [Architecture Overview](../core/architecture-overview.md#umbrella-application-structure)
- [Phoenix Documentation](https://hexdocs.pm/phoenix/)

### Plug
A specification and set of composable modules for building web applications in Elixir.

Plugs provide a unified interface for processing HTTP requests and responses in Elixir web applications. They can be chained together to create processing pipelines, handle authentication, logging, parsing, and other cross-cutting concerns. Phoenix controllers and routers are built on top of the Plug specification.

**Related Documentation:**
- [Phoenix Architecture](https://hexdocs.pm/phoenix/plug.html)
- [Plug Documentation](https://hexdocs.pm/plug/)

### PostgreSQL
An advanced open-source relational database management system used as Prismatic's primary data store.

PostgreSQL provides ACID compliance, advanced SQL features, JSON support, and excellent performance characteristics for Prismatic's data storage needs. The project leverages PostgreSQL's advanced features like indexing, constraints, and full-text search while maintaining compatibility through Ecto's database-agnostic interface.

**Related Documentation:**
- [Technology Stack](../core/tech-stack.md#database-stack)
- [Database Configuration](../../config/dev.exs#L3-L11)
- [PostgreSQL Documentation](https://www.postgresql.org/docs/)

### Preloading
An Ecto optimization technique to load associated data in a single query instead of multiple queries.

Preloading solves the N+1 query problem by fetching all related data upfront, either through joins or separate optimized queries. This technique dramatically improves performance when accessing associated data and is essential for maintaining good database performance in production applications.

**Related Documentation:**
- [Coding Standards](../guides/coding-standards.md#query-optimization)
- [Performance Guidelines](../guides/performance-optimization.md#database-efficiency)
- [Ecto Preloading Guide](https://hexdocs.pm/ecto/Ecto.Query.html#preload/3)

### PubSub
A publish-subscribe messaging pattern used for real-time communication between application components.

Phoenix PubSub enables decoupled communication between different parts of the application, allowing processes to subscribe to topics and receive messages when events occur. This pattern supports real-time features, cross-context communication, and distributed messaging across multiple application nodes.

**Related Documentation:**
- [Architecture Overview](../core/architecture-overview.md#integration-patterns)
- [Technology Stack](../core/tech-stack.md#real-time-communication)
- [Phoenix PubSub Documentation](https://hexdocs.pm/phoenix_pubsub/)

### Repository (Repo)
An Ecto module that provides the interface between application code and the database.

The repository pattern encapsulates all database access in Prismatic, providing a consistent API for queries, inserts, updates, and deletes. It handles connection management, transaction support, and query execution while abstracting away database-specific details from the business logic layer.

**Related Documentation:**
- [Repository Implementation](../../apps/prismatic/lib/prismatic/repo.ex)
- [Architecture Overview](../core/architecture-overview.md#data-flow-pattern)
- [Ecto Repository Guide](https://hexdocs.pm/ecto/Ecto.Repo.html)

### Schema
An Ecto module that defines the structure of database tables and their relationships in Elixir code.

Schemas provide a mapping between database tables and Elixir structs, defining field types, validations, and associations. They serve as the foundation for changesets, queries, and data manipulation while ensuring type safety and providing compile-time verification of database interactions.

**Related Documentation:**
- [Coding Standards](../guides/coding-standards.md#schema-design)
- [User Schema Example](../../apps/prismatic/lib/prismatic/accounts/user.ex)
- [Ecto Schema Documentation](https://hexdocs.pm/ecto/Ecto.Schema.html)

### Tailwind CSS
A utility-first CSS framework that enables rapid UI development through composable utility classes.

Tailwind CSS provides low-level utility classes for building custom designs without writing traditional CSS. In Prismatic, it enables consistent styling, responsive design, and maintainable UI code through a systematic approach to design tokens and component composition.

**Related Documentation:**
- [Technology Stack](../core/tech-stack.md#styling-system)
- [Style Guide](../guides/style-guide.md)
- [Tailwind Configuration](../../apps/prismatic_web/assets/tailwind.config.js)
- [Tailwind CSS Documentation](https://tailwindcss.com/docs)

### Telemetry
A system for collecting and reporting application metrics and events in Elixir applications.

Telemetry provides a standardized way to instrument Elixir applications, collecting metrics about request duration, database queries, business events, and system performance. It enables observability, monitoring, and performance optimization through structured event emission and handler attachment.

**Related Documentation:**
- [Technology Stack](../core/tech-stack.md#monitoring--observability)
- [Telemetry Configuration](../../apps/prismatic_web/lib/prismatic_web/telemetry.ex)
- [Telemetry Documentation](https://hexdocs.pm/telemetry/)

### Umbrella Application
A Phoenix project structure that contains multiple sub-applications to separate concerns and enable modular development.

Umbrella applications allow large projects to be organized into smaller, focused applications that can be developed, tested, and deployed independently while sharing common dependencies and configuration. Prismatic uses this pattern to separate business logic from web presentation concerns.

**Related Documentation:**
- [Architecture Overview](../core/architecture-overview.md#umbrella-application-structure)  
- [ADR: Umbrella Structure](../architecture/adr-0001-umbrella-structure.md)
- [Phoenix Umbrella Guide](https://hexdocs.pm/phoenix/umbrella.html)

### XSS (Cross-Site Scripting)
A security vulnerability where malicious scripts are injected into trusted websites.

XSS attacks occur when applications include untrusted data in web pages without proper validation or escaping. Phoenix templates provide automatic HTML escaping by default, preventing XSS attacks by ensuring that user-provided content is treated as data rather than executable code.

**Related Documentation:**
- [Security Guidelines](../guides/security-guidelines.md#xss-prevention)
- [Phoenix Security Documentation](https://hexdocs.pm/phoenix/security.html)

## Glossary Maintenance

### Formatting Standards
- **Alphabetical Order**: All terms must be arranged alphabetically (case-insensitive)
- **Typography**: Term names as level 3 headings (###), followed by one-sentence definition
- **Structure**: One-sentence definition, detailed paragraph, related documentation links
- **Spacing**: Clear separation between entries for readability

### Update Process
1. **Addition**: New terms added in correct alphabetical position
2. **Modification**: Existing definitions updated with change tracking
3. **Validation**: Automated alphabetical order and formatting verification
4. **Review**: Technical writer approval required for all changes

### Related Documentation
- [Feature Documentation Workflow](../_meta/feature-documentation-workflow.md) - Mandatory glossary updates
- [Cross-Reference Guide](../_meta/cross-reference-guide.md) - Linking standards
- [Maintenance Process](../_meta/maintenance-process.md) - Regular review procedures