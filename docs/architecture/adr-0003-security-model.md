# ADR-0003: Security Model

**Status**: Accepted  
**Date**: 2024-01-20  
**Supersedes**: None  
**Superseded by**: None

<!-- NAV_START -->
## Navigation

**Current Location**: [Home](../README.md) > [Architecture](README.md) > ADR-0003: Security Model

### Quick Links

- **📚 [Parent Directory](README.md)** - Return to architecture index
- **🏠 [Documentation Home](../README.md)** - Main documentation index
- **🔍 [Search Documentation](../reference/glossary.md)** - Find terms and concepts

### Related Documentation

- [Security Guidelines](../guides/security-guidelines.md) - Comprehensive security implementation guide
- [ADR-0001: Umbrella Structure](adr-0001-umbrella-structure.md) - Architectural boundaries affecting security
- [API Authentication](../reference/api-authentication.md) - Authentication implementation details
- [System Diagrams](system-diagrams.md) - Visual representation of security architecture
- [Performance Optimization](../guides/performance-optimization.md) - Security performance considerations
<!-- NAV_END -->

## Summary

We will implement a defense-in-depth security model with layered security controls, context-based authorization, and comprehensive audit logging to protect the Prismatic application against modern security threats while maintaining usability and performance.

## Context

### Problem Statement

The Prismatic application needs a comprehensive security model that addresses:

1. **Multi-Tenant Security** - Secure isolation between different user accounts and organizations
2. **API Security** - Protection for both web and programmatic API access
3. **Data Protection** - Encryption and access controls for sensitive user data
4. **Threat Protection** - Defense against OWASP Top 10 and emerging threats
5. **Compliance Requirements** - Meet industry standards (SOC 2, GDPR, etc.)
6. **Audit and Monitoring** - Complete audit trail for security events
7. **Performance Balance** - Security controls that don't significantly impact user experience

### Security Threat Model

#### Assets to Protect
- **User Data** - Personal information, authentication credentials, user-generated content
- **System Infrastructure** - Application servers, databases, configuration data
- **Business Logic** - Proprietary algorithms, business rules, intellectual property
- **Third-Party Integrations** - API keys, webhook secrets, external service credentials

#### Threat Actors
- **External Attackers** - Attempting unauthorized access, data theft, or system disruption
- **Malicious Insiders** - Users with legitimate access attempting unauthorized actions
- **Compromised Accounts** - Legitimate accounts that have been compromised
- **Automated Attacks** - Bots, scrapers, and automated vulnerability exploitation

#### Attack Vectors
- **Web Application Attacks** - SQL injection, XSS, CSRF, authentication bypass
- **API Attacks** - Rate limiting bypass, token theft, parameter manipulation
- **Infrastructure Attacks** - Network intrusion, privilege escalation, data exfiltration
- **Social Engineering** - Phishing, pretexting, credential harvesting

## Decision

We will implement a **layered security model** with the following architecture:

### Security Architecture Layers

#### Layer 1: Perimeter Security
**Purpose**: First line of defense against external threats.

**Components**:
- **Web Application Firewall (WAF)** - Filter malicious requests before they reach the application
- **DDoS Protection** - Protect against distributed denial of service attacks
- **SSL/TLS Termination** - Encrypt all traffic in transit
- **Rate Limiting** - Prevent abuse and brute force attacks

**Implementation**:
```elixir
# Rate limiting configuration
config :prismatic_web, PrismaticWeb.Endpoint,
  rate_limit: [
    login: {10, :minute},      # 10 login attempts per minute
    api: {1000, :hour},        # 1000 API calls per hour
    upload: {20, :hour}        # 20 file uploads per hour
  ]

# HTTPS enforcement
plug Plug.SSL, rewrite_on: [:x_forwarded_proto]
```

#### Layer 2: Application Security
**Purpose**: Secure the application layer against web-specific attacks.

**Components**:
- **Input Validation** - Validate and sanitize all user input
- **Output Encoding** - Prevent XSS through proper encoding
- **CSRF Protection** - Protect against cross-site request forgery
- **Content Security Policy** - Prevent code injection attacks

**Implementation**:
```elixir
# CSRF and security headers
plug Plug.CSRFProtection
plug Plug.Head
plug PrismaticWeb.SecurityHeaders

defmodule PrismaticWeb.SecurityHeaders do
  def init(opts), do: opts
  
  def call(conn, _opts) do
    conn
    |> put_resp_header("x-frame-options", "DENY")
    |> put_resp_header("x-content-type-options", "nosniff")
    |> put_resp_header("x-xss-protection", "1; mode=block")
    |> put_resp_header("content-security-policy", csp_header())
  end
end
```

#### Layer 3: Authentication and Authorization
**Purpose**: Verify user identity and control access to resources.

**Components**:
- **Multi-Factor Authentication** - Additional verification beyond passwords
- **JWT Token Management** - Secure token generation and validation
- **Role-Based Access Control** - Granular permissions based on user roles
- **Context-Based Authorization** - Resource-level access controls

**Implementation**:
```elixir
# Authentication context
defmodule Prismatic.Auth do
  def authenticate_user(email, password) do
    with {:ok, user} <- get_user_by_email(email),
         {:ok, verified} <- verify_password(password, user.password_hash),
         {:ok, mfa_verified} <- verify_mfa_if_required(user) do
      {:ok, generate_tokens(user)}
    else
      {:error, reason} -> 
        log_auth_failure(email, reason)
        {:error, :invalid_credentials}
    end
  end
  
  def authorize_action(user, action, resource) do
    user
    |> has_permission?(action, resource)
    |> audit_authorization_attempt(user, action, resource)
  end
end
```

#### Layer 4: Data Security
**Purpose**: Protect sensitive data at rest and in transit.

**Components**:
- **Database Encryption** - Encrypt sensitive fields in the database
- **Key Management** - Secure storage and rotation of encryption keys
- **Data Classification** - Categorize data by sensitivity level
- **Backup Encryption** - Encrypt all backup data

**Implementation**:
```elixir
# Data encryption schema
defmodule Prismatic.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset
  
  schema "users" do
    field :email, :string
    field :encrypted_pii, Prismatic.Encrypted.Binary
    field :password_hash, :string
    
    timestamps()
  end
  
  def changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :encrypted_pii])
    |> validate_required([:email])
    |> validate_format(:email, ~r/@/)
    |> encrypt_sensitive_data()
  end
end
```

### Authentication Strategy

#### Multi-Factor Authentication (MFA)
**Requirement**: MFA required for administrative accounts, optional for regular users.

**Supported Methods**:
- **TOTP (Time-based One-Time Password)** - Apps like Google Authenticator, Authy
- **SMS Verification** - Text message codes (backup method)
- **Hardware Keys** - FIDO2/WebAuthn support for high-security accounts
- **Backup Codes** - One-time recovery codes

#### Token Management
**Access Tokens**: Short-lived (1 hour) JWT tokens for API access
**Refresh Tokens**: Long-lived (30 days) tokens for token renewal
**Session Tokens**: Server-side sessions for web interface

```elixir
# Token generation and validation
defmodule Prismatic.Auth.Tokens do
  @access_token_ttl 3600        # 1 hour
  @refresh_token_ttl 2_592_000  # 30 days
  
  def generate_tokens(user) do
    %{
      access_token: generate_jwt(user, @access_token_ttl),
      refresh_token: generate_refresh_token(user),
      expires_in: @access_token_ttl
    }
  end
  
  def validate_token(token) do
    with {:ok, claims} <- verify_jwt(token),
         {:ok, user} <- get_user(claims["sub"]),
         :ok <- check_token_revocation(token) do
      {:ok, user}
    end
  end
end
```

### Authorization Model

#### Role-Based Access Control (RBAC)
**System Roles**:
- **Super Admin** - Full system access, user management
- **Admin** - Organization management, user administration within org
- **Editor** - Content creation, editing, publishing
- **Viewer** - Read-only access to assigned content
- **User** - Basic user functionality, own content management

#### Resource-Based Permissions
**Permission Format**: `<action>:<resource>:<scope>`

**Examples**:
- `read:post:own` - Read own posts
- `write:post:organization` - Write posts within organization
- `delete:user:all` - Delete any user (admin only)
- `manage:billing:organization` - Manage organization billing

```elixir
# Authorization implementation
defmodule Prismatic.Authorization do
  def can?(user, action, resource, scope \\ :own) do
    user
    |> get_permissions()
    |> has_permission?(action, resource, scope)
    |> audit_permission_check(user, action, resource)
  end
  
  defp has_permission?(permissions, action, resource, scope) do
    permission_key = "#{action}:#{resource}:#{scope}"
    permission_key in permissions or has_wildcard_permission?(permissions, action, resource)
  end
end
```

### Data Protection Strategy

#### Encryption Standards
**Encryption at Rest**:
- **Database**: AES-256 encryption for sensitive fields
- **File Storage**: Server-side encryption with customer-managed keys
- **Backups**: Encrypted backups with separate key storage

**Encryption in Transit**:
- **TLS 1.3** minimum for all HTTP communications
- **Certificate Pinning** for mobile applications
- **Perfect Forward Secrecy** enabled

#### Key Management
**Key Hierarchy**:
- **Master Key** - Stored in hardware security module (HSM)
- **Data Encryption Keys** - Per-tenant encryption keys
- **Field-Level Keys** - Specific keys for PII and sensitive data

```elixir
# Encryption implementation
defmodule Prismatic.Encryption do
  @aes_key_size 32  # 256 bits
  
  def encrypt_field(plaintext, key_id \\ :default) do
    key = get_encryption_key(key_id)
    iv = :crypto.strong_rand_bytes(16)
    
    ciphertext = :crypto.crypto_one_time(:aes_256_gcm, key, iv, plaintext, true)
    Base.encode64(iv <> ciphertext)
  end
  
  def decrypt_field(encrypted_data, key_id \\ :default) do
    key = get_encryption_key(key_id)
    <<iv::binary-16, ciphertext::binary>> = Base.decode64!(encrypted_data)
    
    :crypto.crypto_one_time(:aes_256_gcm, key, iv, ciphertext, false)
  end
end
```

### Audit and Monitoring

#### Security Event Logging
**Logged Events**:
- Authentication attempts (success/failure)
- Authorization decisions
- Data access (read/write/delete)
- Administrative actions
- Security configuration changes
- Anomalous behavior detection

#### Monitoring and Alerting
**Alert Triggers**:
- Multiple failed authentication attempts
- Privilege escalation attempts
- Unusual data access patterns
- Configuration changes
- Security policy violations

```elixir
# Security audit logging
defmodule Prismatic.Audit do
  def log_security_event(event_type, user, details) do
    %SecurityEvent{
      event_type: event_type,
      user_id: user.id,
      ip_address: get_ip_address(),
      user_agent: get_user_agent(),
      details: details,
      timestamp: DateTime.utc_now()
    }
    |> Repo.insert!()
    |> maybe_trigger_alert(event_type)
  end
  
  defp maybe_trigger_alert(event, :failed_login) do
    if suspicious_login_pattern?(event.user_id) do
      trigger_security_alert(:suspicious_login, event)
    end
  end
end
```

## Consequences

### Positive Consequences

#### Security Benefits
- **Defense in Depth** - Multiple security layers provide comprehensive protection
- **Threat Mitigation** - Protection against OWASP Top 10 and common attack vectors
- **Data Protection** - Strong encryption protects sensitive data at rest and in transit
- **Audit Trail** - Complete security event logging for compliance and forensics
- **Access Control** - Granular permissions prevent unauthorized access

#### Compliance Benefits
- **SOC 2 Compliance** - Security controls meet SOC 2 Type II requirements
- **GDPR Compliance** - Data protection measures support GDPR requirements
- **Industry Standards** - Alignment with NIST Cybersecurity Framework
- **Audit Readiness** - Comprehensive logging supports audit requirements

#### Operational Benefits
- **Incident Response** - Clear security event data for rapid incident response
- **Monitoring** - Automated detection of security threats and anomalies
- **Scalability** - Security model scales with application growth
- **Maintainability** - Well-defined security boundaries and responsibilities

### Negative Consequences

#### Performance Impact
- **Encryption Overhead** - Additional CPU cycles for encryption/decryption
- **Token Validation** - JWT verification adds latency to API requests
- **Audit Logging** - Additional database writes for security events
- **Authorization Checks** - Permission validation adds processing time

#### Complexity Overhead
- **Implementation Complexity** - Multi-layered security requires careful implementation
- **Key Management** - Encryption key lifecycle management complexity
- **Monitoring Configuration** - Complex alerting rules and thresholds
- **Testing Challenges** - Security features require specialized testing

#### Operational Overhead
- **Security Maintenance** - Regular security updates and patch management
- **Key Rotation** - Periodic encryption key rotation procedures
- **Incident Response** - Security incident investigation and response
- **Compliance Auditing** - Regular security assessments and audits

### Mitigation Strategies

#### Performance Optimization
- **Caching** - Cache authorization decisions and user permissions
- **Async Processing** - Asynchronous audit logging to reduce latency
- **Connection Pooling** - Efficient database connection management
- **Hardware Acceleration** - Use AES-NI for encryption operations

#### Complexity Management
- **Security Libraries** - Use well-tested security libraries and frameworks
- **Automation** - Automate key rotation and security maintenance tasks
- **Documentation** - Comprehensive security documentation and runbooks
- **Training** - Security training for development and operations teams

## Implementation Guidelines

### Development Security Practices

#### Secure Coding Standards
- **Input Validation** - Validate all user inputs at context boundaries
- **Output Encoding** - Encode outputs based on context (HTML, JSON, etc.)
- **Error Handling** - Don't leak sensitive information in error messages
- **Dependency Management** - Regular security updates for dependencies

#### Security Testing
- **Unit Tests** - Test security functions and validation logic
- **Integration Tests** - Test authentication and authorization flows
- **Penetration Testing** - Regular third-party security assessments
- **Vulnerability Scanning** - Automated scanning for known vulnerabilities

```elixir
# Security testing example
defmodule PrismaticWeb.SecurityTest do
  use PrismaticWeb.ConnCase
  
  test "prevents SQL injection in search" do
    malicious_query = "'; DROP TABLE users; --"
    
    conn = get(conn, "/api/search", %{q: malicious_query})
    
    assert json_response(conn, 400)
    # Verify database integrity
    assert Repo.aggregate(User, :count, :id) > 0
  end
  
  test "enforces CSRF protection" do
    conn = 
      conn
      |> bypass_through(PrismaticWeb.Router, :browser)
      |> get("/")
      |> post("/api/users", %{name: "Test"})
    
    assert html_response(conn, 403)
  end
end
```

### Deployment Security

#### Infrastructure Security
- **Network Segmentation** - Isolate application tiers with firewalls
- **Container Security** - Secure container images and runtime
- **Secrets Management** - Use dedicated secrets management services
- **Regular Updates** - Automated security patching for infrastructure

#### Configuration Security
- **Secure Defaults** - Security-first default configurations
- **Environment Separation** - Strict isolation between environments
- **Access Controls** - Principle of least privilege for system access
- **Monitoring** - Comprehensive security monitoring and alerting

## Future Considerations

### Evolution and Scalability
- **Zero Trust Architecture** - Migration toward zero trust security model
- **Advanced Threat Detection** - ML-based anomaly detection and threat intelligence
- **Identity Federation** - Integration with enterprise identity providers
- **API Security Gateway** - Dedicated API security and management layer

### Emerging Technologies
- **Passwordless Authentication** - WebAuthn and biometric authentication
- **Homomorphic Encryption** - Computation on encrypted data
- **Quantum-Resistant Cryptography** - Future-proofing against quantum threats
- **Privacy-Preserving Technologies** - Differential privacy and secure multiparty computation

### Compliance Evolution
- **New Regulations** - Adaptation to emerging data protection regulations
- **International Standards** - Alignment with global security standards
- **Industry Requirements** - Sector-specific compliance requirements
- **Audit Automation** - Automated compliance monitoring and reporting

## Related Decisions

### Influences
- [ADR-0001: Umbrella Structure](adr-0001-umbrella-structure.md) - Security boundaries align with application boundaries
- **Technology Choices** - Elixir/Phoenix security capabilities influenced design
- **Compliance Requirements** - SOC 2 and GDPR requirements shaped security controls

### Influenced Decisions
- **Database Design** - Encryption requirements affect schema design
- **API Design** - Authentication and authorization requirements
- **Monitoring Strategy** - Security event logging requirements
- **Deployment Architecture** - Security controls affect infrastructure design

## Review and Updates

### Review Schedule
- **Monthly** - Security metrics and incident review
- **Quarterly** - Threat model and risk assessment update
- **Annually** - Comprehensive security architecture review
- **Ad Hoc** - After security incidents or major threats

### Success Metrics
- **Security Incidents** - Number and severity of security incidents
- **Vulnerability Response** - Time to patch critical vulnerabilities
- **Compliance Status** - Audit findings and compliance scores
- **Performance Impact** - Security overhead on application performance

### Update Triggers
- **New Threats** - Emerging security threats and attack vectors
- **Compliance Changes** - New regulatory requirements
- **Technology Evolution** - New security technologies and standards
- **Incident Lessons** - Security incidents requiring architectural changes

---

**This ADR establishes the foundation for all security implementations in the Prismatic application. It should be regularly reviewed and updated as the threat landscape and regulatory environment evolve.**