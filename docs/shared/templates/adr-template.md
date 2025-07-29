# ADR-NNNN: [Title]

**Status:** [Proposed | Accepted | Deprecated | Superseded]  
**Date:** YYYY-MM-DD  
**Authors:** [List of authors]  
**Reviewers:** [List of reviewers]  
**Supersedes:** [ADR-XXXX if applicable]  
**Superseded by:** [ADR-YYYY if applicable]  

<!-- NAV_START -->
## Navigation

**Current Location**: [Home](../../README.md) > [Shared](../README.md) > [Templates](README.md) > ADR Template

### Quick Links

- **📚 [Parent Directory](README.md)** - Return to templates index
- **🏠 [Documentation Home](../../README.md)** - Main documentation index
- **🏗️ [Architecture](../../architecture/README.md)** - View all ADRs

### Related Documentation

- [Architecture Decision Records](../../architecture/README.md) - All ADRs index
- [System Architecture](../../architecture/system-overview.md) - High-level system design
- [Style Guide](../../guides/style-guide.md) - Documentation standards
<!-- NAV_END -->

## Overview

Brief description of the architectural decision being documented. This should be a concise summary (1-2 sentences) that explains what is being decided upon.

## Context

### Background

Provide the technical and business context that led to this decision. Include:

- Current state of the system
- Problems or challenges being addressed
- Requirements and constraints
- Stakeholder concerns
- Timeline considerations

### Problem Statement

Clearly articulate the specific problem or challenge that requires an architectural decision. This should be:

- Specific and measurable
- Focused on technical or architectural concerns
- Independent of the solution

**Example:**
> The current monolithic architecture is becoming difficult to scale as the team grows. Deployment cycles are taking longer, and it's becoming harder to develop features independently. We need to decide on an approach that allows for better separation of concerns and independent deployments.

### Forces and Constraints

List the key factors influencing this decision:

#### Technical Forces
- Performance requirements
- Scalability needs
- Security considerations
- Integration requirements
- Technology constraints

#### Business Forces
- Budget limitations
- Timeline constraints
- Team capabilities
- Regulatory requirements
- Strategic business goals

#### Quality Attributes
- Maintainability
- Testability
- Reliability
- Usability
- Security

## Decision

### Chosen Solution

Clearly state the architectural decision being made. Be specific about:

- What will be implemented
- How it will be implemented
- When it will be implemented
- Who is responsible for implementation

**Example:**
> We will migrate from our current monolithic Phoenix application to a microservices architecture using Elixir/Phoenix services with well-defined API boundaries. Services will communicate via HTTP APIs and message queues (RabbitMQ). Each service will have its own database and deployment pipeline.

### Key Components

List the main architectural components involved in this decision:

1. **Component Name** - Brief description of purpose and responsibilities
2. **Component Name** - Brief description of purpose and responsibilities
3. **Component Name** - Brief description of purpose and responsibilities

### Integration Points

Describe how this decision affects integration with existing systems:

- API contracts and interfaces
- Data flow and synchronization
- Authentication and authorization
- Monitoring and observability
- Error handling and recovery

## Alternatives Considered

### Alternative 1: [Name]

**Description:** Brief description of the alternative approach.

**Pros:**
- Advantage 1
- Advantage 2
- Advantage 3

**Cons:**
- Disadvantage 1
- Disadvantage 2
- Disadvantage 3

**Why rejected:** Specific reason why this alternative was not chosen.

### Alternative 2: [Name]

**Description:** Brief description of the alternative approach.

**Pros:**
- Advantage 1
- Advantage 2
- Advantage 3

**Cons:**
- Disadvantage 1
- Disadvantage 2
- Disadvantage 3

**Why rejected:** Specific reason why this alternative was not chosen.

### Alternative 3: Status Quo

**Description:** Maintaining the current approach without changes.

**Pros:**
- No implementation cost
- No learning curve
- Proven and stable

**Cons:**
- Doesn't address the original problem
- Technical debt continues to accumulate
- May become more expensive to change later

**Why rejected:** Specific reason why maintaining status quo is not acceptable.

## Implementation Plan

### Phases

#### Phase 1: [Title] (Duration: X weeks)
**Goals:** What will be accomplished in this phase
**Deliverables:**
- Deliverable 1
- Deliverable 2
- Deliverable 3

**Success Criteria:**
- Measurable outcome 1
- Measurable outcome 2

**Risks:**
- Risk 1 and mitigation strategy
- Risk 2 and mitigation strategy

#### Phase 2: [Title] (Duration: X weeks)
**Goals:** What will be accomplished in this phase
**Deliverables:**
- Deliverable 1
- Deliverable 2
- Deliverable 3

**Success Criteria:**
- Measurable outcome 1
- Measurable outcome 2

**Risks:**
- Risk 1 and mitigation strategy
- Risk 2 and mitigation strategy

### Resource Requirements

**Team Members:**
- Role 1: Number of people, time commitment
- Role 2: Number of people, time commitment
- Role 3: Number of people, time commitment

**Infrastructure:**
- Hardware/cloud resources needed
- Software licenses required
- Third-party services

**Budget Estimate:**
- Development costs
- Infrastructure costs
- Third-party service costs
- Training costs

### Dependencies

**Technical Dependencies:**
- System A must be upgraded to version X
- API B needs to be implemented
- Database migration C must be completed

**Business Dependencies:**
- Approval from stakeholder group A
- Training completion for team B
- Budget allocation approval

**External Dependencies:**
- Third-party service availability
- Vendor deliverables
- Regulatory approvals

## Consequences

### Positive Consequences

**Technical Benefits:**
- Improved performance in area X
- Better scalability for use case Y
- Reduced complexity in component Z
- Enhanced security through mechanism A

**Business Benefits:**
- Faster feature development
- Reduced operational costs
- Improved customer satisfaction
- Better compliance with regulations

**Team Benefits:**
- Clearer separation of responsibilities
- Improved development workflow
- Better learning opportunities
- Reduced on-call burden

### Negative Consequences

**Technical Challenges:**
- Increased complexity in area X
- Performance overhead for operation Y
- Additional monitoring requirements
- New failure modes

**Business Risks:**
- Higher initial implementation cost
- Longer time to market for features
- Need for additional training
- Potential service disruptions during migration

**Team Impact:**
- Learning curve for new technologies
- Changed development processes
- Additional operational responsibilities
- Potential resistance to change

### Mitigation Strategies

For each significant negative consequence, provide a mitigation strategy:

1. **Challenge:** Description of the challenge
   **Mitigation:** Specific actions to reduce or eliminate the risk

2. **Challenge:** Description of the challenge
   **Mitigation:** Specific actions to reduce or eliminate the risk

## Success Metrics

### Key Performance Indicators (KPIs)

**Technical Metrics:**
- Response time: Target < Xms (Current: Yms)
- Throughput: Handle X requests/second (Current: Y requests/second)
- Error rate: < X% (Current: Y%)
- Availability: > X% uptime (Current: Y%)

**Business Metrics:**
- Feature delivery velocity: X features/sprint (Current: Y features/sprint)
- Deployment frequency: X deployments/week (Current: Y deployments/week)
- Lead time: X days from idea to production (Current: Y days)
- Customer satisfaction: X score (Current: Y score)

**Operational Metrics:**
- Mean time to detection (MTTD): < X minutes
- Mean time to recovery (MTTR): < X minutes
- Infrastructure costs: $X/month (Current: $Y/month)
- Developer productivity: X story points/sprint (Current: Y story points/sprint)

### Measurement Plan

**How metrics will be collected:**
- Automated monitoring dashboards
- Regular surveys and feedback
- Performance testing results
- Business intelligence reports

**Review schedule:**
- Weekly operational reviews
- Monthly business impact assessment
- Quarterly architectural health check
- Annual strategic alignment review

## Risks and Assumptions

### Assumptions

List key assumptions that underpin this decision:

1. **Assumption:** The team will have sufficient time for training
   **Validation:** Confirmed with engineering management
   **Risk if invalid:** Implementation delays, quality issues

2. **Assumption:** Third-party service will remain stable
   **Validation:** Reviewed SLA and service history
   **Risk if invalid:** Service disruptions, need for alternative

3. **Assumption:** Budget will remain available for full implementation
   **Validation:** Confirmed with finance team
   **Risk if invalid:** Partial implementation, technical debt

### Risks

**High-Impact Risks:**
1. **Risk:** Team lacks expertise in new technology
   **Probability:** Medium
   **Impact:** High
   **Mitigation:** Invest in training, hire experienced developers, engage consultants

2. **Risk:** Performance doesn't meet expectations
   **Probability:** Low
   **Impact:** High
   **Mitigation:** Extensive performance testing, gradual rollout, rollback plan

**Medium-Impact Risks:**
1. **Risk:** Integration challenges with existing systems
   **Probability:** Medium
   **Impact:** Medium
   **Mitigation:** Proof of concept, extensive integration testing

2. **Risk:** Vendor lock-in concerns
   **Probability:** Low
   **Impact:** Medium
   **Mitigation:** Use open standards, maintain abstraction layers

## Review and Updates

### Review Schedule

- **Initial Review:** 30 days after implementation starts
- **Progress Reviews:** Every 60 days during implementation
- **Post-Implementation Review:** 90 days after completion
- **Annual Review:** Yearly assessment of ongoing relevance

### Update Triggers

This ADR should be reviewed and potentially updated when:

- Significant changes to business requirements
- Major technology shifts in the ecosystem
- Performance metrics consistently miss targets
- New information that challenges core assumptions
- Request from architecture review board

### Success/Failure Criteria

**Success Indicators:**
- All success metrics are met within 6 months
- No major rollbacks or revisions needed
- Team adoption is smooth with minimal resistance
- Stakeholder satisfaction exceeds expectations

**Failure Indicators:**
- Success metrics consistently missed after 6 months
- Multiple rollbacks or major revisions required
- Significant team resistance or skill gaps persist
- Stakeholders request alternative approaches

If failure criteria are met, this ADR should be marked as "Failed" and a new ADR should be created to address the situation.

## References

### Documentation
- [Related ADR-XXXX: Previous Decision](adr-xxxx-previous-decision.md)
- [System Architecture Overview](../architecture/system-overview.md)
- [Technical Requirements Document](../requirements/technical-requirements.md)

### External Resources
- [Technology Documentation](https://example.com/docs)
- [Industry Best Practices](https://example.com/best-practices)
- [Research Paper or Case Study](https://example.com/research)
- [Vendor Documentation](https://vendor.com/docs)

### Tools and Utilities
- [Architecture Decision Record Tools](https://adr.github.io/)
- [Decision Making Frameworks](https://example.com/frameworks)
- [Risk Assessment Templates](https://example.com/risk-templates)

---

## Template Usage Instructions

### How to Use This Template

1. **Copy this template** to a new file named `adr-NNNN-brief-title.md` where NNNN is the next sequential number
2. **Fill in the header information** with appropriate values
3. **Replace all placeholder text** with actual content relevant to your decision
4. **Remove instructional text** (like this section) from the final ADR
5. **Review with stakeholders** before marking as "Accepted"

### ADR Numbering Convention

- Use sequential numbering: ADR-0001, ADR-0002, etc.
- Include leading zeros for proper sorting
- Never reuse numbers, even for rejected ADRs

### Status Guidelines

- **Proposed:** Initial draft, under review
- **Accepted:** Decision approved and implementation may begin
- **Deprecated:** Decision is no longer recommended but not yet replaced
- **Superseded:** Decision has been replaced by a newer ADR

### Writing Tips

- **Be specific and concrete** rather than vague or abstract
- **Use active voice** and clear, direct language
- **Include measurable criteria** wherever possible
- **Document the reasoning process** not just the conclusion
- **Consider future readers** who weren't part of the original discussion
- **Update cross-references** when creating or modifying related ADRs

### Review Process

1. **Author creates initial draft** with status "Proposed"
2. **Stakeholders review** and provide feedback
3. **Author incorporates feedback** and updates draft
4. **Architecture review board approves** decision
5. **Status updated to "Accepted"** and implementation begins
6. **Regular reviews** ensure continued relevance

---

**This template ensures consistent, comprehensive documentation of architectural decisions across the Prismatic project.**