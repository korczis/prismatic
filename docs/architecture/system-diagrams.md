# System Diagrams

Visual representations of the Prismatic system architecture, including high-level system overview, data flow, deployment topology, and integration patterns.

<!-- NAV_START -->
## Navigation

**Current Location**: [Home](../README.md) > [Architecture](README.md) > System Diagrams

### Quick Links

- **📚 [Parent Directory](README.md)** - Return to architecture index
- **🏠 [Documentation Home](../README.md)** - Main documentation index
- **🔍 [Search Documentation](../reference/glossary.md)** - Find terms and concepts

### Related Documentation

- [Architecture Overview](../core/architecture-overview.md) - High-level system design description
- [ADR-0001: Umbrella Structure](adr-0001-umbrella-structure.md) - Umbrella application architecture decision
- [ADR-0003: Security Model](adr-0003-security-model.md) - Security architecture decisions
- [Performance Optimization](../guides/performance-optimization.md) - Performance considerations in system design
- [API Endpoints](../reference/api-endpoints.md) - API structure and endpoints
<!-- NAV_END -->

## Overview

This document contains visual representations of the Prismatic system architecture. These diagrams serve as a visual reference for understanding system structure, data flow, deployment topology, and integration patterns. They complement the textual architecture documentation and provide a quick visual reference for developers, architects, and operations teams.

## Diagram Standards

### Notation and Symbols
- **Rectangles** - Applications, services, and system components
- **Cylinders** - Databases and persistent storage
- **Clouds** - External services and third-party integrations
- **Arrows** - Data flow, API calls, and system interactions
- **Dotted lines** - Optional or conditional connections
- **Colors** - Consistent color coding for different system layers

### Diagram Types
- **High-Level Architecture** - Overall system structure and major components
- **Data Flow Diagrams** - How data moves through the system
- **Deployment Diagrams** - Infrastructure and deployment topology
- **Integration Diagrams** - External system connections and APIs
- **Security Diagrams** - Security boundaries and access controls

## High-Level System Architecture

### Overview Diagram

```mermaid
graph TB
    %% External Users and Systems
    Users[👥 Users] --> LB[Load Balancer]
    API[🔌 API Clients] --> LB
    Admin[👨‍💼 Administrators] --> LB
    
    %% Load Balancer and CDN
    LB --> CDN[📡 CDN]
    CDN --> Web[🌐 Phoenix Web App]
    
    %% Application Layer (Umbrella Structure)
    Web --> Core[⚙️ Prismatic Core]
    Web --> WebApp[📱 Prismatic Web]
    
    %% Data Layer
    Core --> DB[(🗄️ PostgreSQL)]
    Core --> Cache[(🚀 Redis Cache)]
    Core --> Queue[📋 Job Queue]
    
    %% External Integrations
    Core --> Email[📧 Email Service]
    Core --> Storage[💾 File Storage]
    Core --> Monitor[📊 Monitoring]
    
    %% Background Processing
    Queue --> Workers[⚡ Background Workers]
    Workers --> Core
    
    %% Styling
    classDef userClass fill:#e1f5fe
    classDef appClass fill:#f3e5f5
    classDef dataClass fill:#e8f5e8
    classDef externalClass fill:#fff3e0
    
    class Users,API,Admin userClass
    class Web,Core,WebApp,Workers appClass
    class DB,Cache,Queue dataClass
    class LB,CDN,Email,Storage,Monitor externalClass
```

### Component Relationships

```mermaid
graph LR
    %% Umbrella Application Structure
    subgraph "Prismatic Umbrella"
        subgraph "prismatic_web"
            Controller[Controllers]
            LiveView[LiveViews]
            Router[Router]
            Endpoint[Endpoint]
        end
        
        subgraph "prismatic"
            Context[Business Logic]
            Schema[Schemas]
            Repo[Repository]
            Services[Services]
        end
    end
    
    %% External Dependencies
    Database[(PostgreSQL)]
    Cache[(Redis)]
    Queue[Job Queue]
    
    %% Connections
    Controller --> Context
    LiveView --> Context
    Router --> Controller
    Router --> LiveView
    Endpoint --> Router
    
    Context --> Schema
    Context --> Repo
    Context --> Services
    Repo --> Database
    Services --> Cache
    Services --> Queue
    
    %% Styling
    classDef webLayer fill:#e3f2fd
    classDef coreLayer fill:#f1f8e9
    classDef dataLayer fill:#fce4ec
    
    class Controller,LiveView,Router,Endpoint webLayer
    class Context,Schema,Repo,Services coreLayer
    class Database,Cache,Queue dataLayer
```

## Data Flow Diagrams

### Request Processing Flow

```mermaid
sequenceDiagram
    participant User
    participant CDN
    participant LB as Load Balancer
    participant Web as Phoenix Web
    participant Core as Prismatic Core
    participant DB as Database
    participant Cache
    
    User->>CDN: HTTP Request
    CDN->>LB: Forward (if not cached)
    LB->>Web: Route Request
    Web->>Core: Business Logic Call
    
    alt Data in Cache
        Core->>Cache: Check Cache
        Cache-->>Core: Return Cached Data
    else Cache Miss
        Core->>DB: Query Database
        DB-->>Core: Return Data
        Core->>Cache: Store in Cache
    end
    
    Core-->>Web: Return Processed Data
    Web-->>LB: HTTP Response
    LB-->>CDN: Response
    CDN->>User: Final Response
```

### Background Job Processing

```mermaid
graph TD
    %% Job Creation
    WebReq[Web Request] --> CreateJob[Create Job]
    CreateJob --> Queue[(Job Queue)]
    
    %% Job Processing
    Queue --> Worker1[Worker Process 1]
    Queue --> Worker2[Worker Process 2]
    Queue --> Worker3[Worker Process N]
    
    %% Job Execution
    Worker1 --> Execute[Execute Job Logic]
    Worker2 --> Execute
    Worker3 --> Execute
    
    %% Job Results
    Execute --> Success{Success?}
    Success -->|Yes| Complete[Job Complete]
    Success -->|No| Retry[Retry Logic]
    Retry --> Queue
    
    %% External Actions
    Execute --> Email[Send Email]
    Execute --> API[External API Call]
    Execute --> FileOp[File Operations]
    
    %% Styling
    classDef queueClass fill:#fff3e0
    classDef workerClass fill:#e8f5e8
    classDef actionClass fill:#f3e5f5
    
    class Queue queueClass
    class Worker1,Worker2,Worker3,Execute workerClass
    class Email,API,FileOp actionClass
```

## Deployment Architecture

### Production Environment

```mermaid
graph TB
    %% Internet and CDN
    Internet([🌐 Internet]) --> CDN[CDN/CloudFlare]
    
    %% Load Balancer
    CDN --> ALB[Application Load Balancer]
    
    %% Application Tier
    subgraph "Application Tier"
        ALB --> App1[App Instance 1]
        ALB --> App2[App Instance 2]
        ALB --> App3[App Instance 3]
    end
    
    %% Database Tier
    subgraph "Database Tier"
        App1 --> Primary[(Primary DB)]
        App2 --> Primary
        App3 --> Primary
        
        Primary --> Replica1[(Read Replica 1)]
        Primary --> Replica2[(Read Replica 2)]
    end
    
    %% Cache and Queue
    subgraph "Cache/Queue Tier"
        App1 --> Redis[(Redis Cluster)]
        App2 --> Redis
        App3 --> Redis
        
        App1 --> JobQueue[Job Queue]
        App2 --> JobQueue
        App3 --> JobQueue
    end
    
    %% Background Workers
    subgraph "Worker Tier"
        JobQueue --> BG1[Background Worker 1]
        JobQueue --> BG2[Background Worker 2]
        JobQueue --> BGN[Background Worker N]
    end
    
    %% External Services
    subgraph "External Services"
        BG1 --> SMTP[SMTP Service]
        BG2 --> S3[File Storage]
        BGN --> Monitor[Monitoring/APM]
    end
    
    %% Styling
    classDef appClass fill:#e3f2fd
    classDef dataClass fill:#e8f5e8
    classDef workerClass fill:#fff3e0
    classDef externalClass fill:#fce4ec
    
    class App1,App2,App3 appClass
    class Primary,Replica1,Replica2,Redis,JobQueue dataClass
    class BG1,BG2,BGN workerClass
    class SMTP,S3,Monitor externalClass
```

### Development Environment

```mermaid
graph LR
    %% Developer Machine
    subgraph "Development Machine"
        Dev[👨‍💻 Developer]
        DevApp[Phoenix App]
        DevDB[(Local PostgreSQL)]
        DevRedis[(Local Redis)]
    end
    
    %% Docker Environment
    subgraph "Docker Compose"
        DockerApp[App Container]
        DockerDB[(DB Container)]
        DockerCache[(Cache Container)]
        DockerQueue[Queue Container]
    end
    
    %% CI/CD Environment
    subgraph "CI/CD Pipeline"
        GitHub[GitHub Actions]
        TestEnv[Test Environment]
        StagingEnv[Staging Environment]
    end
    
    %% Connections
    Dev --> DevApp
    DevApp --> DevDB
    DevApp --> DevRedis
    
    Dev --> DockerApp
    DockerApp --> DockerDB
    DockerApp --> DockerCache
    DockerApp --> DockerQueue
    
    Dev --> GitHub
    GitHub --> TestEnv
    TestEnv --> StagingEnv
    
    %% Styling
    classDef devClass fill:#e1f5fe
    classDef dockerClass fill:#f3e5f5
    classDef ciClass fill:#e8f5e8
    
    class Dev,DevApp,DevDB,DevRedis devClass
    class DockerApp,DockerDB,DockerCache,DockerQueue dockerClass
    class GitHub,TestEnv,StagingEnv ciClass
```

## Integration Architecture

### API Integration Patterns

```mermaid
graph TB
    %% External API Clients
    Mobile[📱 Mobile App] --> Gateway[API Gateway]
    SPA[🖥️ SPA Frontend] --> Gateway
    ThirdParty[🔌 Third-party Apps] --> Gateway
    
    %% API Gateway
    Gateway --> Auth[Authentication]
    Gateway --> RateLimit[Rate Limiting]
    Gateway --> Logging[Request Logging]
    
    %% Phoenix Application
    Auth --> Phoenix[Phoenix Application]
    RateLimit --> Phoenix
    Logging --> Phoenix
    
    %% Internal Services
    Phoenix --> UserService[User Service]
    Phoenix --> OrderService[Order Service]
    Phoenix --> PaymentService[Payment Service]
    
    %% External Integrations
    PaymentService --> Stripe[💳 Stripe API]
    Phoenix --> SendGrid[📧 SendGrid API]
    Phoenix --> AWS[☁️ AWS Services]
    
    %% Database
    UserService --> Database[(Database)]
    OrderService --> Database
    PaymentService --> Database
    
    %% Styling
    classDef clientClass fill:#e1f5fe
    classDef gatewayClass fill:#fff3e0
    classDef appClass fill:#e3f2fd
    classDef serviceClass fill:#f1f8e9
    classDef externalClass fill:#fce4ec
    
    class Mobile,SPA,ThirdParty clientClass
    class Gateway,Auth,RateLimit,Logging gatewayClass
    class Phoenix appClass
    class UserService,OrderService,PaymentService serviceClass
    class Stripe,SendGrid,AWS,Database externalClass
```

### Message Flow Architecture

```mermaid
graph LR
    %% Message Sources
    WebHook[Webhooks] --> Queue[Message Queue]
    ScheduledJob[Scheduled Jobs] --> Queue
    UserAction[User Actions] --> Queue
    
    %% Message Processing
    Queue --> Router[Message Router]
    
    %% Message Handlers
    Router --> EmailHandler[Email Handler]
    Router --> NotificationHandler[Notification Handler]
    Router --> ReportHandler[Report Handler]
    Router --> SyncHandler[Sync Handler]
    
    %% External Actions
    EmailHandler --> SMTP[SMTP Server]
    NotificationHandler --> Push[Push Service]
    ReportHandler --> S3[File Storage]
    SyncHandler --> ExternalAPI[External APIs]
    
    %% Results
    SMTP --> AuditLog[(Audit Log)]
    Push --> AuditLog
    S3 --> AuditLog
    ExternalAPI --> AuditLog
    
    %% Styling
    classDef sourceClass fill:#e1f5fe
    classDef queueClass fill:#fff3e0
    classDef handlerClass fill:#f1f8e9
    classDef externalClass fill:#fce4ec
    
    class WebHook,ScheduledJob,UserAction sourceClass
    class Queue,Router queueClass
    class EmailHandler,NotificationHandler,ReportHandler,SyncHandler handlerClass
    class SMTP,Push,S3,ExternalAPI,AuditLog externalClass
```

## Security Architecture

### Security Boundaries

```mermaid
graph TB
    %% Internet and DMZ
    Internet([🌐 Internet]) --> Firewall1[Perimeter Firewall]
    
    %% DMZ Zone
    subgraph "DMZ Zone"
        Firewall1 --> CDN[CDN/WAF]
        CDN --> LoadBalancer[Load Balancer]
    end
    
    %% Application Zone
    subgraph "Application Zone"
        LoadBalancer --> AppFirewall[Application Firewall]
        AppFirewall --> App1[App Instance 1]
        AppFirewall --> App2[App Instance 2]
    end
    
    %% Database Zone
    subgraph "Database Zone"
        App1 --> DBFirewall[Database Firewall]
        App2 --> DBFirewall
        DBFirewall --> Primary[(Primary DB)]
        DBFirewall --> Replica[(Read Replica)]
    end
    
    %% Management Zone
    subgraph "Management Zone"
        VPN[VPN Gateway] --> Management[Management Tools]
        Management --> Monitor[Monitoring]
        Management --> Backup[Backup Services]
    end
    
    %% Security Controls
    Firewall1 -.-> IDS[Intrusion Detection]
    AppFirewall -.-> WAF[Web Application Firewall]
    DBFirewall -.-> Audit[Database Audit]
    
    %% Styling
    classDef dmzClass fill:#ffebee
    classDef appClass fill:#e8f5e8
    classDef dataClass fill:#e3f2fd
    classDef mgmtClass fill:#fff3e0
    classDef securityClass fill:#fce4ec
    
    class CDN,LoadBalancer dmzClass
    class App1,App2 appClass
    class Primary,Replica dataClass
    class VPN,Management,Monitor,Backup mgmtClass
    class Firewall1,AppFirewall,DBFirewall,IDS,WAF,Audit securityClass
```

### Authentication and Authorization Flow

```mermaid
sequenceDiagram
    participant User
    participant Frontend
    participant Gateway as API Gateway
    participant Auth as Auth Service
    participant App as Application
    participant DB as Database
    
    User->>Frontend: Login Request
    Frontend->>Gateway: Authentication Request
    Gateway->>Auth: Validate Credentials
    Auth->>DB: Check User Data
    DB-->>Auth: User Information
    Auth->>Auth: Generate JWT Token
    Auth-->>Gateway: Return Token
    Gateway-->>Frontend: Authentication Response
    Frontend-->>User: Login Success
    
    Note over User,DB: Subsequent API Requests
    
    User->>Frontend: API Request
    Frontend->>Gateway: Request + JWT Token
    Gateway->>Auth: Validate Token
    Auth-->>Gateway: Token Valid + User Context
    Gateway->>App: Authorized Request
    App->>DB: Data Operation
    DB-->>App: Query Results
    App-->>Gateway: Response Data
    Gateway-->>Frontend: API Response
    Frontend-->>User: Display Data
```

## Monitoring and Observability

### Monitoring Architecture

```mermaid
graph TB
    %% Application Layer
    subgraph "Application Layer"
        App1[App Instance 1]
        App2[App Instance 2]
        App3[App Instance 3]
    end
    
    %% Metrics Collection
    App1 --> Prometheus[Prometheus Metrics]
    App2 --> Prometheus
    App3 --> Prometheus
    
    %% Logging Pipeline
    App1 --> Fluentd[Log Aggregation]
    App2 --> Fluentd
    App3 --> Fluentd
    
    %% Tracing
    App1 --> Jaeger[Distributed Tracing]
    App2 --> Jaeger
    App3 --> Jaeger
    
    %% Storage and Analysis
    Prometheus --> Grafana[Grafana Dashboards]
    Fluentd --> Elasticsearch[(Elasticsearch)]
    Elasticsearch --> Kibana[Kibana Dashboards]
    Jaeger --> JaegerUI[Jaeger UI]
    
    %% Alerting
    Prometheus --> AlertManager[Alert Manager]
    AlertManager --> PagerDuty[PagerDuty]
    AlertManager --> Slack[Slack Notifications]
    
    %% APM Integration
    App1 --> APM[APM Service]
    App2 --> APM
    App3 --> APM
    APM --> NewRelic[New Relic/DataDog]
    
    %% Styling
    classDef appClass fill:#e3f2fd
    classDef collectionClass fill:#f1f8e9
    classDef storageClass fill:#fff3e0
    classDef alertClass fill:#ffebee
    classDef apmClass fill:#fce4ec
    
    class App1,App2,App3 appClass
    class Prometheus,Fluentd,Jaeger collectionClass
    class Grafana,Elasticsearch,Kibana,JaegerUI storageClass
    class AlertManager,PagerDuty,Slack alertClass
    class APM,NewRelic apmClass
```

## Performance and Scaling

### Scaling Strategy

```mermaid
graph TB
    %% Load Balancer
    LB[Load Balancer]
    
    %% Auto Scaling Group
    subgraph "Auto Scaling Group"
        direction TB
        App1[App Instance 1]
        App2[App Instance 2]
        App3[App Instance 3]
        AppN[App Instance N]
    end
    
    %% Database Scaling
    subgraph "Database Tier"
        Primary[(Primary DB)]
        ReadReplica1[(Read Replica 1)]
        ReadReplica2[(Read Replica 2)]
        ReadReplicaN[(Read Replica N)]
    end
    
    %% Cache Scaling
    subgraph "Cache Tier"
        Redis1[(Redis Cluster Node 1)]
        Redis2[(Redis Cluster Node 2)]
        Redis3[(Redis Cluster Node N)]
    end
    
    %% Connections
    LB --> App1
    LB --> App2
    LB --> App3
    LB --> AppN
    
    App1 --> Primary
    App2 --> ReadReplica1
    App3 --> ReadReplica2
    AppN --> ReadReplicaN
    
    App1 --> Redis1
    App2 --> Redis2
    App3 --> Redis3
    AppN --> Redis1
    
    %% Auto Scaling Triggers
    CloudWatch[CloudWatch Metrics] --> AutoScaling[Auto Scaling Policy]
    AutoScaling -.-> App1
    AutoScaling -.-> App2
    AutoScaling -.-> App3
    AutoScaling -.-> AppN
    
    %% Styling
    classDef appClass fill:#e3f2fd
    classDef dataClass fill:#e8f5e8
    classDef cacheClass fill:#fff3e0
    classDef scalingClass fill:#fce4ec
    
    class App1,App2,App3,AppN appClass
    class Primary,ReadReplica1,ReadReplica2,ReadReplicaN dataClass
    class Redis1,Redis2,Redis3 cacheClass
    class CloudWatch,AutoScaling scalingClass
```

## Disaster Recovery Architecture

### Backup and Recovery Flow

```mermaid
graph LR
    %% Primary Environment
    subgraph "Primary Region"
        PrimaryApp[Primary Application]
        PrimaryDB[(Primary Database)]
        PrimaryFiles[File Storage]
    end
    
    %% Backup Processes
    PrimaryDB --> DBBackup[Database Backup]
    PrimaryFiles --> FileBackup[File Backup]
    PrimaryApp --> ConfigBackup[Configuration Backup]
    
    %% Backup Storage
    DBBackup --> S3Primary[S3 Primary Region]
    FileBackup --> S3Primary
    ConfigBackup --> S3Primary
    
    %% Cross-Region Replication
    S3Primary --> S3Secondary[S3 Secondary Region]
    PrimaryDB --> SecondaryDB[(Secondary Database)]
    
    %% Disaster Recovery Environment
    subgraph "DR Region"
        S3Secondary --> DRApp[DR Application]
        SecondaryDB --> DRApp
        DRApp --> DRLiveCheck[Health Check]
    end
    
    %% Monitoring and Alerts
    DRLiveCheck --> Monitoring[DR Monitoring]
    Monitoring --> Alerts[DR Alerts]
    
    %% Styling
    classDef primaryClass fill:#e3f2fd
    classDef backupClass fill:#f1f8e9
    classDef storageClass fill:#fff3e0
    classDef drClass fill:#ffebee
    
    class PrimaryApp,PrimaryDB,PrimaryFiles primaryClass
    class DBBackup,FileBackup,ConfigBackup backupClass
    class S3Primary,S3Secondary storageClass
    class DRApp,SecondaryDB,DRLiveCheck,Monitoring,Alerts drClass
```

## Diagram Maintenance

### Updating Diagrams
- **Architecture Changes** - Update diagrams when system architecture changes
- **New Components** - Add new components and their relationships
- **Integration Updates** - Reflect changes in external integrations
- **Performance Modifications** - Update scaling and performance diagrams

### Diagram Validation
- **Consistency Checks** - Ensure diagrams match actual system implementation
- **Cross-Reference Validation** - Verify diagrams align with architecture documentation
- **Stakeholder Review** - Regular review with architecture and development teams
- **Version Control** - Maintain diagram versions alongside code changes

### Tools and Standards
- **Mermaid Syntax** - Use Mermaid for maintainable, version-controlled diagrams
- **Consistent Styling** - Apply consistent colors, shapes, and notation
- **Clear Labels** - Use descriptive labels and legends
- **Accessibility** - Ensure diagrams are accessible and well-documented

## Related Documentation

- [Architecture Overview](../core/architecture-overview.md) - Detailed textual description of system architecture
- [ADR-0001: Umbrella Structure](adr-0001-umbrella-structure.md) - Decision record for umbrella application architecture
- [ADR-0003: Security Model](adr-0003-security-model.md) - Security architecture decisions and implementation
- [Performance Optimization](../guides/performance-optimization.md) - Performance considerations reflected in system design
- [API Endpoints](../reference/api-endpoints.md) - API structure and endpoint documentation
- [Monitoring Setup](../operations/monitoring-setup.md) - Implementation details for monitoring architecture
- [Deployment Procedures](../operations/deployment-procedures.md) - Deployment processes for architecture shown in diagrams

---

**These diagrams are living documents that should be updated as the system evolves. They serve as both design communication tools and implementation reference materials.**