# Architecture Overview

High-level system design and architectural principles for the Prismatic application.

## System Architecture

### Umbrella Application Structure
Prismatic uses a **Phoenix umbrella application** architecture that separates concerns into distinct applications:

```
Prismatic System
├── Core App (prismatic)          # Business Logic Layer
│   ├── Contexts & Schemas        # Domain logic and data models
│   ├── Database Access          # Ecto repositories and queries
│   └── Business Rules           # Domain-specific logic
│
└── Web App (prismatic_web)       # Presentation Layer
    ├── Controllers & APIs       # HTTP request handling
    ├── LiveView Components      # Interactive UI
    └── Templates & Assets       # Static content and styling
```

**Design Rationale**: See [ADR-0001: Umbrella Structure](../architecture/adr-0001-umbrella-structure.md) for detailed decision context.

## Architectural Principles

### Separation of Concerns
- **Business Logic**: Isolated in core app contexts
- **Presentation Logic**: Contained in web app controllers and LiveView
- **Data Access**: Centralized through Ecto contexts
- **Configuration**: Shared across umbrella apps

### Context-Driven Design
Business functionality organized into bounded contexts:
```
Prismatic.Accounts    # User management and authentication
Prismatic.Content     # Content creation and publishing  
Prismatic.Billing     # Payment processing and subscriptions
Prismatic.Analytics   # Usage tracking and reporting
```

### Data Flow Pattern
```
HTTP Request → Controller → Context → Schema → Database
                    ↓
          LiveView ← Template ← View Model ← Context Response
```

## Technology Stack

### Backend Foundation
- **Runtime**: Elixir/OTP for concurrent, fault-tolerant systems
- **Web Framework**: Phoenix for HTTP handling and real-time features
- **Database**: PostgreSQL with Ecto ORM for data persistence
- **HTTP Server**: Bandit for modern HTTP/1.1 and HTTP/2 support

### Frontend Architecture  
- **Interactive UI**: Phoenix LiveView for server-rendered real-time interfaces
- **Styling**: Tailwind CSS utility-first framework
- **Assets**: esbuild for JavaScript bundling, native CSS processing
- **Icons**: Heroicons for consistent iconography

### Infrastructure Services
- **Email**: Swoosh with configurable adapters
- **HTTP Client**: Finch for external API communication
- **Monitoring**: Phoenix LiveDashboard and Telemetry
- **PubSub**: Phoenix PubSub for real-time message distribution

## Security Architecture

### Authentication & Authorization
- **User Authentication**: Session-based with secure cookie storage
- **API Authentication**: Token-based for programmatic access
- **Authorization**: Context-level permission checking
- **CSRF Protection**: Built-in Phoenix CSRF tokens

### Data Protection
- **Password Security**: Argon2 hashing with salt
- **Data Validation**: Input sanitization at context boundaries
- **SQL Injection Prevention**: Ecto parameterized queries
- **XSS Protection**: Phoenix HTML escaping by default

## Scalability Considerations

### Horizontal Scaling
- **Stateless Design**: Application servers can be load-balanced
- **Database Clustering**: PostgreSQL read replicas for query scaling
- **Asset Distribution**: CDN for static asset delivery
- **Caching Strategy**: Application-level and database query caching

### Performance Optimization
- **Database Indexing**: Strategic indexes for query performance
- **Connection Pooling**: Optimized database connection management
- **Asset Optimization**: Minification and compression in production
- **LiveView Efficiency**: Minimal DOM updates and temporary assigns

## Development Architecture

### AI-Assisted Development
- **Code Generation**: AI follows established architectural patterns
- **Documentation**: Automated cross-reference maintenance
- **Testing**: AI-generated test cases following architectural principles
- **Quality Assurance**: Automated architectural compliance checking

### Modularity Benefits
- **Independent Development**: Teams can work on different apps simultaneously
- **Testing Isolation**: Business logic tested separately from web interface
- **Deployment Flexibility**: Different deployment strategies per app
- **Technology Evolution**: Easier to upgrade or replace individual components

## Integration Patterns

### Internal Communication
- **Context APIs**: Clean interfaces between business domains
- **Event Broadcasting**: PubSub for cross-context communication
- **Shared Configuration**: Umbrella-level environment management

### External Integrations
- **HTTP APIs**: RESTful endpoints for external system integration
- **Webhooks**: Event-driven communication with third-party services
- **Background Jobs**: Asynchronous processing for heavy operations

## Related Documentation
- [Technical Stack Details](tech-stack.md) - Detailed technology information
- [Project Structure](project-structure.md) - Directory organization and conventions
- [System Diagrams](../architecture/system-diagrams.md) - Visual architecture representations
- [Performance Guidelines](../guides/performance-optimization.md) - Optimization strategies
- [Security Guidelines](../guides/security-guidelines.md) - Security implementation details