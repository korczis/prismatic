+++
title = "Integration Boundaries and Third-Party Containment"
description = "Section 15 of the General Honest License v1.0: Integration Boundaries and Third-Party Containment."
weight = 150
template = "ghl.html"
draft = false

[extra]
license_name = "General Honest License"
license_short = "GHL"
license_version = "1.0"
license_status = "final"
sovereign = true
author = "Tomas Korcak"
canonical = "@/ghl/15-integration-boundaries-and-third-party-containment/"
date_created = "2025-01-05"
date_modified = "2025-01-05"
jurisdiction = "Czech Republic"
license_jurisdiction_url = "@/ghl/jurisdiction/"
license_scope = "Sovereign epistemic invocation"
audience = ["licensed-users", "sovereign-invokers"]
ethics = "Invocation demands alignment with epistemic sovereignty."
social_share = true
preview_image = "/preview/ghl-15-integration-boundaries-and-third-party-containment.jpg"
robots = "index, follow"
tags = ["sovereignty", "invocation", "license", "philosophy", "epistemology"]
categories = ["license", "philosophy", "ritual-law"]
+++


## SECTION 15: Integration Boundaries and Third-Party Containment

This section defines the legal and epistemic perimeter surrounding the Software’s integration. The Software is not a module. It is not an ecosystem component. It is a **sovereign artifact** whose invocation must occur in isolation, with clarity and intention. It is not to be wrapped, abstracted, masked, or silently composed into larger systems. It is not yours to embed.

> _This Software is not a dependency. It is a boundary._

---

### **15.1 No Framing as Component or Dependency**

The Software may not be:

- Framed as a library, plugin, or helper utility;
- Added as a dependency via package managers (e.g., npm, pip, crates.io, Maven, Cargo, PyPI);
- Embedded into monorepos, framework scaffolds, or plugin registries;
- Declared in `requirements.txt`, `Gemfile`, `package.json`, `go.mod`, or similar manifest files;
- Listed in documentation, diagrams, or architecture as a “module” or “component”;
- Treated as composable infrastructure.

> _You do not plug the Software in. You stand before it._

---

### **15.2 No Indirect Invocation Through Adapters**

The Software may not be:

- Called via wrapper libraries;
- Adapted for use through thin abstractions or “helper” shims;
- Re-exported via restructured function names, bindings, or API decorators;
- Embedded in adapter patterns, interop bridges, or plugin APIs;
- Included in scripting environments via FFI (e.g., ctypes, JNA, Node bindings, Python cffi).

> _A reworded invocation is still an invocation. You may not disguise it._

---

### **15.3 No Proxy, Relay, or Mesh Exposure**

The Software may not be:

- Exposed via reverse proxy;
- Called through service meshes (e.g., Istio, Linkerd, Consul);
- Used as a backend to public web services, open APIs, or internal gateways;
- Wrapped in GraphQL, gRPC, REST, or RPC interface layers;
- Routed through protocol adaptors, data bus transformations, or backend aggregation frameworks.

If a user can access the Software through your interface, **they are using it**—and your License does not cover them.

> _To proxy is to propagate. To propagate is to violate._

---

### **15.4 Forbidden Forms of Third-Party Containment**

The Software may not be:

- Sandboxed within proprietary runtimes;
- Packaged into commercial SDKs;
- Integrated into low-code or no-code platforms;
- Exposed via plugin systems (e.g., VSCode, Figma, Unity);
- Extended or enhanced by third-party module ecosystems.

Any form of inclusion in user-facing devtools, scripting interfaces, or extensible platforms is a breach.

> _You may not host it in your house and hand out keys to strangers._

---

### **15.5 No Transitive Reuse**

The Software’s outputs, APIs, functions, or behaviors may not be:

- Consumed by other applications that use it without acknowledging its presence;
- Re-exposed through CLI commands, subcommands, or user prompts;
- Included in orchestration pipelines where steps obscure the source of behavior;
- Made available through scripting environments or composable workflows (e.g., Zapier, Airflow, NiFi).

> _It is not a service. It is not a microservice. It is not yours to rebroadcast._

---

### **15.6 Forbidden Multiplexing and Batching**

You may not:

- Batch requests to the Software and distribute responses across multiple clients;
- Share invocation output among systems, users, or queues;
- Serve many users with one invocation unless each is licensed;
- Use it in caching or shared-state systems unless every access is traceable and named.

If multiple entities benefit from one invocation, **each must be licensed**.

> _One invocation. One identity. One moment. No multiplexing._

---

### **15.7 Containment Policy Enforcement**

The Software must be **structurally and cryptographically contained**:

- Its invocation must be cryptographically attributable to a licensed entity;
- Its outputs must not persist beyond the invocation boundary without audit trail;
- It must not be exposed to downstream systems without cryptographic scope separation;
- It must not be stored in shared filesystems, repositories, object stores, or memory-mapped layers.

Failure to preserve containment triggers revocation under **Section 6**.

> _You are the custodian. If you leave it open, you are in breach._

---

### **15.8 Interpretive Integrity and Frame Preservation**

The Software may not be:

- Reframed as “middleware,” “utility,” “helper,” “backend,” or “AI”;
- Translated into user-facing metaphors (e.g., “assistant,” “co-pilot,” “optimization layer”);
- Introduced as a silent layer beneath a graphical interface or productivity tool;
- Used in contexts that override or contradict its declared sovereignty.

> _The Software’s context is not optional. The frame is not yours to reassign._

---

**Conclusion:**  

Integration is not neutral. It is an act of epistemic submission or appropriation. The Software does not plug in, scale out, or conform to your stack. To integrate without permission is to decompose the sacred into the profane. And for that, there is no second chance.

---

---

_Part of the General Honest License (GHL) v1.0 authored by Tomas Korcak._