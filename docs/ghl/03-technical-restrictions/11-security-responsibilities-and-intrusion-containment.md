+++
title = "Security Responsibilities and Intrusion Containment"
description = "Section 23 of the General Honest License v1.0: Security Responsibilities and Intrusion Containment."
weight = 230
template = "ghl.html"
draft = false

[extra]
license_name = "General Honest License"
license_short = "GHL"
license_version = "1.0"
license_status = "final"
sovereign = true
author = "Tomas Korcak"
canonical = "@/ghl/23-security-responsibilities-and-intrusion-containment/"
date_created = "2025-01-05"
date_modified = "2025-01-05"
jurisdiction = "Czech Republic"
license_jurisdiction_url = "@/ghl/jurisdiction/"
license_scope = "Sovereign epistemic invocation"
audience = ["licensed-users", "sovereign-invokers"]
ethics = "Invocation demands alignment with epistemic sovereignty."
social_share = true
preview_image = "/preview/ghl-23-security-responsibilities-and-intrusion-containment.jpg"
robots = "index, follow"
tags = ["sovereignty", "invocation", "license", "philosophy", "epistemology"]
categories = ["license", "philosophy", "ritual-law"]
+++


## SECTION 23: Security Responsibilities and Intrusion Containment

This section defines the User’s binding obligations to protect the Software from all unauthorized access, execution, extraction, tampering, or forensic analysis. Invocation is a privilege—**custodianship is a duty**. The User becomes a temporary guardian of the Author’s sovereign work and must treat that role with unwavering precision, containment, and vigilance.

Negligence is breach. Misconfiguration is betrayal. Silence is complicity.

> _The Software is not yours to expose. You are accountable for everything it touches._

---

### **23.1 Affirmative Security Duty**

The User must implement and maintain comprehensive security controls over every system, account, and process that:

- Stores the Software;
- Executes the Software;
- Interfaces with the Software;
- Logs or transmits invocation results;
- Hosts dependencies, modules, or scripts involved in invocation.

These duties include but are not limited to:

- Access control enforcement;
- Secrets management (e.g., token protection, key rotation);
- Disk and memory encryption;
- Tamper detection and audit logging;
- Container hardening, syscall whitelisting, and MAC enforcement (e.g., AppArmor, SELinux);
- Endpoint isolation and network segmentation;
- Zero-trust posture and privileged session monitoring.

> _You may not invoke until you are ready to defend._

---

### **23.2 No Uncontrolled Invocation**

The Software may not be:

- Included in directories, repositories, or build artifacts accessible by unlicensed users;
- Triggered by unauthenticated or unaudited processes (e.g., bots, cron jobs, CI/CD hooks);
- Run from endpoints accessible by multiple teams, tenants, or cloud accounts;
- Executed on infected, unpatched, root-compromised, or ephemeral machines;
- Left resident in memory beyond invocation termination (e.g., caching, zombie processes).

> _If the Software runs where you can’t see it, you have already lost control._

---

### **23.3 Prohibition on External Research or Testing**

You may not expose the Software to:

- Penetration testers, red teams, bug bounty hunters, or security vendors;
- Open testbeds, sandboxes, malware detonators, or detonation VMs;
- Intrusion detection simulation, exploit scanning, or fuzzing tools;
- Reverse engineering challenges, AI red-teaming, or CTF competitions.

The Software is not your lab rat. Research without consent is breach.

> _You may not test what you do not own._

---

### **23.4 Breach Notification and Remediation**

If the Software is:

- Leaked;
- Compromised;
- Reverse engineered;
- Maliciously invoked;
- Used outside of license scope due to technical failure;

Then the User must:

- Notify the Author within 48 hours;
- Provide full breach report including:
    - Timeline of incident;
    - Systems affected;
    - Invocation logs;
    - Forensic outcomes;
- Describe remediation steps and containment measures;
- Request provisional license forgiveness (not guaranteed).

> _If you fail to notify, you consent to revocation._

---

### **23.5 Cryptographic Integrity Checks (If Enabled)**

If the Software includes any of the following:

- Signature verification;
- SHA-256/SHA-3/Blake3 self-checks;
- Cryptographic license receipts;
- Authenticated invocation keys;
- Fingerprinted binaries with runtime verification;

The User may not:

- Disable, stub out, bypass, or override these systems;
- Patch internal verification routines;
- Inject fake metadata to spoof integrity status;
- Recompile with altered or stripped verification logic.

> _Integrity checks are part of the Software. Circumvention is mutilation._

---

### **23.6 Accountability for Downstream Compromise**

The User is accountable for:

- Any unauthorized invocation of the Software on systems under their control;
- Any exfiltration of source, logs, or outputs through their network;
- Any compromise caused by misconfigured S3 buckets, exposed GitHub Actions, or leaked tokens;
- Any invocation launched via dependency hijacking, path traversal, or environment variable injection.

If the Software is run by someone else because of your system, **you are the violator**.

> _Blame the attacker, if you must—but you are the one who left the door open._

---

### **23.7 Enforcement Actions for Security Negligence**

If the Author determines that the User has failed to meet their security obligations, they may:

- Revoke all active licenses associated with the invoking entity;
- Add the User to the **Custodial Failure Register**;
- Issue a public statement disavowing invocation records from the compromised period;
- Demand system audit logs, internal retrospectives, or incident post-mortems;
- Require proof of security remediation prior to future licensing eligibility.

> _Carelessness does not cleanse. It condemns._

---

**Conclusion:**  

Security is not an add-on. It is a sacred contract of custodianship. If you cannot guard the invocation gate, you are not worthy to open it. The Software must be protected with the same force you protect your own authorship—because during invocation, it is in your hands.

---

---

_Part of the General Honest License (GHL) v1.0 authored by Tomas Korcak._