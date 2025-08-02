+++
title = "Computational Scope and Environmental Constraints"
description = "Section 14 of the General Honest License v1.0: Computational Scope and Environmental Constraints."
weight = 140
template = "ghl.html"
draft = false

[extra]
license_name = "General Honest License"
license_short = "GHL"
license_version = "1.0"
license_status = "final"
sovereign = true
author = "Tomas Korcak"
canonical = "@/ghl/14-computational-scope-and-environmental-constraints/"
date_created = "2025-01-05"
date_modified = "2025-01-05"
jurisdiction = "Czech Republic"
license_jurisdiction_url = "@/ghl/jurisdiction/"
license_scope = "Sovereign epistemic invocation"
audience = ["licensed-users", "sovereign-invokers"]
ethics = "Invocation demands alignment with epistemic sovereignty."
social_share = true
preview_image = "/preview/ghl-14-computational-scope-and-environmental-constraints.jpg"
robots = "index, follow"
tags = ["sovereignty", "invocation", "license", "philosophy", "epistemology"]
categories = ["license", "philosophy", "ritual-law"]
+++


## SECTION 14: Computational Scope and Environmental Constraints

This section codifies the physical, architectural, and runtime boundaries of lawful execution for the Software. It does not merely restrict environments—it defines a **ritual perimeter** beyond which execution becomes both unstable and unauthorized. The Software is not general-purpose. It is not cloud-native. It is not serverless-ready. It is an epistemically bounded artifact with strict limits on where, how, and by what it may be run.

> _This Software does not scale. It is invoked, not deployed._

---

### **14.1 Prohibited Environments of Execution**

Unless explicitly permitted in a License Grant, the Software may not be executed in:

- Multi-tenant infrastructure where user data, state, or execution contexts are shared across customers, clients, or organizational boundaries;
- Serverless platforms or function-as-a-service (FaaS) systems (e.g., AWS Lambda, Google Cloud Functions, Azure Functions);
- Containerized clusters (e.g., Kubernetes, Nomad, Docker Swarm) with horizontal scaling or autoscaling enabled;
- Any environment where execution boundaries are blurred, ephemeral, or dynamically created;
- Virtualized environments where the Author cannot trace machine state, such as:
    - Edge deployments
    - AI accelerators
    - Cloud spots/preemptibles
    - FPGA/ASIC-resident hardware
    - Wasm sandboxes

> _If the Software runs where you cannot see it, then neither can the Author—and it is in violation._

---

### **14.2 Forbidden Execution Patterns**

The Software may not be:

- Executed in infinite loops, retry queues, or event reprocessing systems;
- Called from event-driven architectures or pub/sub patterns;
- Included in DAGs (directed acyclic graphs) or scheduling graphs with recursive edge potential;
- Deployed in reactive or actor-based concurrency systems;
- Wrapped in orchestration workflows with unclear lifecycle, restart policies, or backoff heuristics.

> _This Software is not a worker. It is not a job. It is an artifact with rhythm and invocation._

---

### **14.3 Memory, CPU, and Resource Boundaries**

By default, the Software is not authorized to operate beyond the following thresholds per invocation instance:

- **CPU**: ≤ 4 logical cores (or threads)
- **Memory**: ≤ 8GB resident memory
- **Disk I/O**: ≤ 1TB read or write per session
- **Concurrency**: ≤ 16 parallel invocations in any namespace
- **Runtime Duration**: ≤ 12 hours without manual re-approval

These values are not soft guidelines. They are **invocation bounds**. Violating them constitutes unauthorized invocation unless explicitly overridden in writing.

> _You do not scale this Software. You scale around it._

---

### **14.4 Forbidden Hosting Modalities**

The Software may not be:

- Invoked via webhooks, public HTTP endpoints, or browser-exposed interfaces;
- Exposed to unlicensed users via SaaS frontends, CLI wrappers, or open APIs;
- Embedded in CI/CD pipelines that run the Software across unlicensed branches, forks, or merges;
- Stored in container registries, DockerHub, or package repositories where it may be pulled without cryptographic restriction;
- Called via automation scripts, DevOps tooling, or job runners (e.g., Ansible, Terraform, Jenkins) unless explicitly constrained.

> _If you do not know exactly who is invoking it, you are not licensed to let it be invoked._

---

### **14.5 Prohibited Invocation by Agent**

Invocation by the following is forbidden unless licensed with named cryptographic identity:

- Bots
- Cron jobs
- Scheduled tasks
- CI runners
- Smart contracts
- Systemd services
- LLMs, AI agents, or autonomous daemon systems

Invocation must be **intentional** and **traceable**. No ephemeral task may call the Software in darkness.

> _Only a named entity may speak the name of the Software and cause it to act._

---

### **14.6 Forbidden Instrumentation and Observation**

The Software may not be:

- Subjected to synthetic benchmarking, fuzzing, or chaos testing;
- Monitored by profilers, system call tracers, or dynamic runtime inspectors;
- Reverse-proxied through observability gateways (e.g., Datadog, Honeycomb, New Relic);
- Wrapped in telemetry collectors or structured logging frameworks that record outputs, performance, or execution characteristics for review by unauthorized users.

Performance data is not yours to collect. Invocation entropy is not yours to study.

> _To watch is to breach. To trace is to trespass._

---

### **14.7 Invocation Scope and Containment**

You may not:

- Allow the Software to trigger other systems without explicit control logic;
- Bind the Software’s outputs to other commands or services via pipes, shell ops, or IPC;
- Chain the Software into Unix-style tool streams (e.g., foo | bar | software);
- Compose the Software in map-reduce patterns, streaming folds, or distributed query plans.

> _The Software is not a building block. It is an isolated act of authorship._

---

### **14.8 Forbidden Recursion and Forking**

Unless licensed, the Software may not:

- Call itself recursively;
- Fork child processes beyond licensed concurrency;
- Launch subprocesses or shells that expand its execution scope;
- Be embedded in job queues or pipelines that dynamically replicate or retry based on runtime conditionals.

> _Invocation is singular. Echoes are forbidden._

---

### **14.9 Architectural Sovereignty Clause**

Any attempt to:

- Abstract, recompose, or wrap the Software into a new architecture;
- Modularize it for plugin loading;
- Refactor it into packages or libraries;
- Transpile it for foreign runtimes (e.g., JVM, .NET, Node.js);

…constitutes **violation of the invocation perimeter**.

> _You do not architect over the Software. You align with it._

---

**Conclusion:**  

The Software is not designed to scale. It is designed to execute **with precision**. Treat it as a ceremonial invocation, not an infrastructure component. To run it where it should not be run is not just computational abuse—it is **metaphysical misalignment**.

---

---

_Part of the General Honest License (GHL) v1.0 authored by Tomas Korcak._