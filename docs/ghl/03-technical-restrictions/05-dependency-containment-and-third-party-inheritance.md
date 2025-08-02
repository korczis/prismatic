+++
title = "Dependency Containment and Third-Party Inheritance"
description = "Section 17 of the General Honest License v1.0: Dependency Containment and Third-Party Inheritance."
weight = 170
template = "ghl.html"
draft = false

[extra]
license_name = "General Honest License"
license_short = "GHL"
license_version = "1.0"
license_status = "final"
sovereign = true
author = "Tomas Korcak"
canonical = "@/ghl/17-dependency-containment-and-third-party-inheritance/"
date_created = "2025-01-05"
date_modified = "2025-01-05"
jurisdiction = "Czech Republic"
license_jurisdiction_url = "@/ghl/jurisdiction/"
license_scope = "Sovereign epistemic invocation"
audience = ["licensed-users", "sovereign-invokers"]
ethics = "Invocation demands alignment with epistemic sovereignty."
social_share = true
preview_image = "/preview/ghl-17-dependency-containment-and-third-party-inheritance.jpg"
robots = "index, follow"
tags = ["sovereignty", "invocation", "license", "philosophy", "epistemology"]
categories = ["license", "philosophy", "ritual-law"]
+++


## SECTION 17: Dependency Containment and Third-Party Inheritance

This section establishes the non-porous boundary between the Software and all third-party code, packages, dependencies, and runtime libraries. It affirms that while the Software may internally link to or require third-party components, those relationships are **not reciprocal**, **not shared**, and **not derivational**. The Software inherits nothing. It transmits nothing. It is not open by association.

> _Dependencies may pass through the Software. But they never pass into it._

---

### **17.1 Non-Inheritance of External Licenses**

The Software shall not be presumed to inherit the properties, rights, privileges, or open-source status of any third-party component it interacts with, statically links to, dynamically loads, or runs alongside. Specifically:

- The presence of MIT-, Apache-, BSD-, GPL-, or LGPL-licensed code in the dependency graph does **not** alter the Software’s license terms;
- The Software does not become “open,” “shareable,” or “forkable” by virtue of proximity to permissively licensed packages;
- No compatibility matrix, SPDX tag, or community license parser may override this isolation.

> _If the Software touches the open, it remains closed._

---

### **17.2 Forbidden Inference of Joint Attribution**

The User shall not:

- Declare the Software “based on” or “including” third-party systems unless specifically authorized;
- Include the Software in “powered by” badges, architecture diagrams, or branding alongside external projects;
- Suggest that the Software participates in the ideology, governance, or ethics of any dependency it uses or loads;
- Claim that open-source license features (e.g. redistribution, remixing, modification rights) extend to the Software through transitivity.

> _Linkage is not lineage. Inference is not invitation._

---

### **17.3 Prohibition on Dependency Injection and Override**

You may not:

- Override, patch, or replace dependencies used by the Software without written permission;
- Force the Software to load different versions of libraries via `LD_PRELOAD`, `PYTHONPATH`, `NODE_PATH`, or environment variable hacks;
- Use vendored versions of dependencies to inject functionality not shipped with the original Software;
- Alter dependency graphs in `Cargo.lock`, `package-lock.json`, or other lockfiles to bend the Software into new behavior.

> _You cannot twist the Software by twisting the ground beneath it._

---

### **17.4 No Elevation of Dependencies**

You may not:

- Extract, repackage, or separately distribute parts of the Software’s dependencies under your own license;
- Represent any part of the dependency graph as a “fork” of the Software;
- Build standalone projects from transitive dependencies shipped inside the Software;
- Claim derivative rights over embedded libraries, internal shims, or glue code written by the Author to interact with third-party tools.

> _What lives in the Software remains in its boundary. Extraction is violation._

---

### **17.5 Forking of Dependency Graph is Breach**

You may not:

- Duplicate the Software’s dependency tree and create a “clean rewrite”;
- Start a new project by mimicking the dependency selections, API surface, or invocation pattern of the Software;
- Use `diff`, `static analysis`, or AST tools to extract dependency-specific deltas and rebuild “equivalent” logic;
- Construct a “compatibility shim” to use Software-adjacent packages in place of the Software itself.

> _A Software’s shape includes its scaffolding. You may not borrow its shadow._

---

### **17.6 Enforcement via Dependency Isolation**

The Author reserves the right to:

- Modify, encrypt, or obscure dependency declarations to prevent tampering;
- Validate checksum graphs of runtime dependencies and revoke licenses when graphs drift;
- Maintain a canonical list of acceptable dependency versions and known-bad overrides;
- Monitor execution for altered library behavior and disable invocation via internal kill switches.

> _The Software knows what it depends on. So does the Author._

---

### **17.7 Philosophical Statement on Containment**

The Software is not a platform. It is not a starter kit. It is not a framework to be extended by injection. It is a closed object with sealed epistemic context.

- If it loads something, it does so silently;
- If it depends on something, it does so under ritual;
- If it integrates, it remains sovereign.

You may not use third-party openness as a crowbar against this License.

> _The Software inherits no openness. And it confers none._

---

**Conclusion:**  

This section exists to block all attempts at subverting the Software’s license through its dependencies. Composition is not permission. Shared context is not shared authorship. You cannot inject freedom into what was built to stand alone.

---

---

_Part of the General Honest License (GHL) v1.0 authored by Tomas Korcak._