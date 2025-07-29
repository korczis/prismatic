# ADR-0001: Umbrella Application Structure

**Status**: Accepted  
**Date**: 2024-01-15  
**Supersedes**: None  
**Superseded by**: None

<!-- NAV_START -->
## Navigation

**Current Location**: [Home](../README.md) > [Architecture](README.md) > ADR-0001: Umbrella Structure

### Quick Links

- **📚 [Parent Directory](README.md)** - Return to architecture index
- **🏠 [Documentation Home](../README.md)** - Main documentation index
- **🔍 [Search Documentation](../reference/glossary.md)** - Find terms and concepts

### Related Documentation

- [Architecture Overview](../core/architecture-overview.md) - High-level system design description
- [System Diagrams](system-diagrams.md) - Visual representation of umbrella architecture
- [ADR-0003: Security Model](adr-0003-security-model.md) - Security considerations in umbrella design
- [Developer Experience](../guides/developer-experience.md) - Development workflow with umbrella structure
- [Performance Optimization](../guides/performance-optimization.md) - Performance implications of architecture choice
<!-- NAV_END -->

## Summary

We will structure the Prismatic application as a Phoenix umbrella application with clear separation between business logic and presentation concerns, enabling better modularity, testability, and team collaboration.

## Context

### Problem Statement

When building a Phoenix application, we needed to decide on the overall application architecture that would:

1. **Scale with Team Growth** - Support multiple developers working simultaneously without conflicts
2. **Maintain Clean Boundaries** - Separate business logic from presentation logic
3. **Enable Independent Testing** - Allow testing of business logic without web dependencies
4. **Support Future Evolution** - Facilitate technology upgrades and architectural changes
5. **Optimize Development Workflow** - Minimize coupling between different system concerns

### Considered Alternatives

#### Alternative 1: Single Phoenix Application
**Structure**: Traditional single Phoenix application with contexts.

**Pros**:
- Simpler initial setup and deployment
- Single configuration and dependency management
- Easier for small teams to understand
- Standard Phoenix approach familiar to most developers

**Cons**:
- Business logic tightly coupled to web framework
- Difficult to test business logic in isolation
- Limited flexibility for future architectural evolution
- Potential for mixing concerns as application grows
- Single point of failure for all application functionality

#### Alternative 2: Microservices Architecture
**Structure**: Separate applications communicating over HTTP/gRPC.

**Pros**:
- Complete independence between services
- Technology diversity possible per service
- Independent scaling and deployment
- Clear service boundaries enforced by network

**Cons**:
- Significant operational complexity
- Network latency and reliability concerns
- Distributed system challenges (consistency, debugging)
- Over-engineering for current system size
- Complex local development setup

#### Alternative 3: Phoenix Umbrella Application (Selected)
**Structure**: Multiple Phoenix applications under a single umbrella project.

**Pros**:
- Clean separation of concerns with minimal overhead
- Shared configuration and dependencies where appropriate
- Independent testing of business logic
- Gradual evolution toward microservices if needed
- Maintains Elixir/OTP benefits (shared memory, message passing)
- Simplified deployment compared to microservices

**Cons**:
- More complex than single application
- Requires discipline to maintain boundaries
- Additional configuration overhead
- Learning curve for developers unfamiliar with umbrella apps

## Decision

We will implement a **Phoenix umbrella application** with the following structure:

### Application Architecture

```
prismatic_umbrella/
├── apps/
│   ├── prismatic/           # Core Business Logic Application
│   │   ├── lib/prismatic/
│   │   │   ├── accounts/    # User management context
│   │   │   ├── content/     # Content management context
│   │   │   ├── billing/     # Payment processing context
│   │   │   ├── analytics/   # Usage tracking context
│   │   │   └── repo.ex      # Database access layer
│   │   └── test/
│   │
│   └── prismatic_web/       # Web Presentation Application
│       ├── lib/prismatic_web/
│       │   ├── controllers/ # HTTP request handling
│       │   ├── live/        # LiveView components
│       │   ├── components/  # Reusable UI components
│       │   └── templates/   # HTML templates
│       └── test/
│
├── config/                  # Shared configuration
└── mix.exs                  # Umbrella project definition
```

### Responsibility Boundaries

#### Core Application (`prismatic`)
**Purpose**: Business logic, data models, and domain rules.

**Responsibilities**:
- Data schemas and changesets
- Business rule validation
- Database queries and transactions
- Context APIs for business operations
- Background job definitions
- Integration with external services (business layer)

**Dependencies**: 
- Database (PostgreSQL via Ecto)
- External APIs and services
- No dependency on web framework

#### Web Application (`prismatic_web`)
**Purpose**: HTTP interface and user interaction.

**Responsibilities**:
- HTTP request/response handling
- Authentication and session management
- Input validation and error handling
- HTML rendering and LiveView components
- API endpoint definitions
- Asset management (CSS, JavaScript)

**Dependencies**:
- Core application for business logic
- Phoenix framework for web functionality
- No direct database access (through core app only)

### Communication Patterns

#### Inter-Application Communication
- **Web → Core**: Direct function calls through public context APIs
- **Core → Web**: Event broadcasting via Phoenix PubSub for real-time updates
- **Shared Resources**: Configuration, logging, and monitoring shared across apps

#### Context Boundaries
```elixir
# Web application calls core contexts
defmodule PrismaticWeb.UserController do
  def create(conn, params) do
    case Prismatic.Accounts.create_user(params) do
      {:ok, user} -> render_success(conn, user)
      {:error, changeset} -> render_errors(conn, changeset)
    end
  end
end

# Core context maintains business logic
defmodule Prismatic.Accounts do
  def create_user(params) do
    %User{}
    |> User.changeset(params)
    |> validate_business_rules()
    |> Repo.insert()
  end
end
```

## Consequences

### Positive Consequences

#### Development Benefits
- **Clear Separation of Concerns**: Business logic isolated from presentation logic
- **Independent Testing**: Core business logic can be tested without web dependencies
- **Team Scalability**: Multiple developers can work on different apps simultaneously
- **Technology Evolution**: Web layer can be replaced/upgraded independently

#### Architectural Benefits
- **Maintainability**: Easier to locate and modify functionality within clear boundaries
- **Reusability**: Core business logic can be reused by multiple interfaces (web, API, CLI)
- **Modularity**: Clean interfaces between applications reduce coupling
- **Debugging**: Easier to isolate issues to specific application layers

#### Operational Benefits
- **Deployment Flexibility**: Can deploy as single unit or migrate to separate services
- **Resource Optimization**: Can profile and optimize applications independently
- **Monitoring**: Separate metrics and logging per application when needed

### Negative Consequences

#### Complexity Overhead
- **Initial Setup**: More complex project structure than single application
- **Learning Curve**: Developers need to understand umbrella app concepts
- **Configuration Management**: Multiple application configurations to maintain

#### Development Considerations
- **Boundary Discipline**: Requires team discipline to maintain proper boundaries
- **Circular Dependency Risk**: Must carefully manage dependencies between apps
- **Additional Abstractions**: More layers to understand and navigate

#### Operational Considerations
- **Deployment Complexity**: More complex than single app deployment initially
- **Debugging Across Apps**: Stack traces may span multiple applications
- **Documentation Overhead**: Need to document inter-app communication patterns

### Mitigation Strategies

#### Addressing Complexity
- **Clear Documentation**: Maintain comprehensive architecture documentation
- **Development Guidelines**: Establish clear patterns for inter-app communication
- **Code Reviews**: Enforce boundary discipline through review process
- **Training**: Ensure team understands umbrella application patterns

#### Managing Dependencies
- **Dependency Graphs**: Regular review of application dependency relationships
- **Interface Contracts**: Well-defined APIs between applications
- **Testing Strategies**: Integration tests to verify inter-app communication

## Implementation Guidelines

### Development Workflow
1. **Business Logic First**: Implement core functionality in the `prismatic` app
2. **Test Core Logic**: Ensure business rules work independently of web interface
3. **Web Interface**: Build web controllers and views that consume core APIs
4. **Integration Testing**: Test complete user workflows across both applications

### Code Organization Principles
- **Context-Driven Design**: Organize core app by business domains (accounts, content, etc.)
- **Thin Controllers**: Web controllers should primarily orchestrate core app calls
- **Shared Utilities**: Common utilities can be shared between apps when appropriate
- **Configuration Management**: Use umbrella-level configuration for shared concerns

### Testing Strategy
```elixir
# Core app tests (no web dependencies)
defmodule Prismatic.AccountsTest do
  test "creates user with valid data" do
    assert {:ok, user} = Accounts.create_user(@valid_attrs)
    assert user.email == @valid_attrs.email
  end
end

# Web app tests (integration with core)
defmodule PrismaticWeb.UserControllerTest do
  test "creates user via web interface" do
    conn = post(conn, "/users", user: @valid_attrs)
    assert redirected_to(conn) == user_path(conn, :show, user.id)
  end
end
```

## Future Considerations

### Evolution Path
- **Service Extraction**: Well-bounded contexts can be extracted to separate services if needed
- **API Applications**: Additional umbrella apps can be added for different interfaces (GraphQL, mobile API)
- **Shared Libraries**: Common functionality can be extracted to shared libraries

### Monitoring and Observability
- **Per-App Metrics**: Application-level metrics and monitoring
- **Distributed Tracing**: Trace requests across umbrella applications
- **Performance Profiling**: Independent performance analysis per application

### Security Considerations
- **Authentication Boundaries**: Clear authentication/authorization responsibilities
- **Input Validation**: Validation at both web and core app boundaries
- **Audit Logging**: Track actions across application boundaries

## Related Decisions

### Influences
- **Technology Choice**: Decision to use Elixir/Phoenix influenced umbrella choice
- **Team Structure**: Development team size and skill set considered
- **Scalability Requirements**: Future scaling needs influenced architecture choice

### Influenced Decisions
- [ADR-0003: Security Model](adr-0003-security-model.md) - Security boundaries align with app boundaries
- [Database Design](../reference/database-schema.md) - Schema design reflects app boundaries
- [API Design](../reference/api-endpoints.md) - API structure follows app organization

## Review and Updates

### Review Schedule
- **Quarterly**: Review effectiveness of umbrella structure
- **Major Features**: Assess boundary decisions when adding significant functionality
- **Team Growth**: Re-evaluate as team size and structure changes

### Success Metrics
- **Development Velocity**: Time to implement new features
- **Bug Isolation**: Ability to isolate and fix issues quickly
- **Testing Coverage**: Percentage of business logic covered by isolated tests
- **Team Satisfaction**: Developer experience and productivity metrics

### Update Triggers
- **Boundary Violations**: Frequent violations of app boundaries
- **Performance Issues**: Architecture-related performance problems
- **Team Friction**: Architecture causing development workflow problems
- **Scaling Challenges**: Issues scaling the current structure

---

**This ADR documents a foundational architectural decision that influences all subsequent development work. It should be reviewed and updated as the system and team evolve.**