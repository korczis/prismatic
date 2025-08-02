+++
title = "Cryptographic Restrictions"
description = "Section 13 of the General Honest License v1.0: Cryptographic Restrictions."
weight = 130
template = "ghl.html"
draft = false

[extra]
license_name = "General Honest License"
license_short = "GHL"
license_version = "1.0"
license_status = "final"
sovereign = true
author = "Tomas Korcak"
canonical = "@/ghl/13-cryptographic-restrictions/"
date_created = "2025-01-05"
date_modified = "2025-01-05"
jurisdiction = "Czech Republic"
license_jurisdiction_url = "@/ghl/jurisdiction/"
license_scope = "Sovereign epistemic invocation"
audience = ["licensed-users", "sovereign-invokers"]
ethics = "Invocation demands alignment with epistemic sovereignty."
social_share = true
preview_image = "/preview/ghl-13-cryptographic-restrictions.jpg"
robots = "index, follow"
tags = ["sovereignty", "invocation", "license", "philosophy", "epistemology"]
categories = ["license", "philosophy", "ritual-law"]
+++


## SECTION 13: Cryptographic Restrictions

This section defines the User’s obligations regarding all cryptographic, security-related, or mathematically obfuscated features embedded in, invoked by, or facilitated through the Software. Cryptography is not an implementation detail—it is a **controlled technology**. Even when invisible, it carries weight. Even when indirect, it carries liability.

The Software may include cryptographic operations—whether explicit or incidental—that trigger legal, ethical, and regulatory scrutiny. By using the Software, the User accepts the **full burden of legal interpretation, compliance, and consequence**.

> _You may use cryptography. You may not deny the responsibility of doing so._

---

### **13.1 No Guarantees of Cryptographic Correctness or Fitness**

The Author does not claim and shall never be assumed to provide:

- Correctness of cryptographic implementations;
- Conformance with national or international standards (e.g., FIPS, NIST, RFC, ISO);
- Security against known or unknown attacks, including brute-force, side-channel, timing, or statistical inference;
- Resistance to downgrade, injection, tampering, or ciphertext malleability;
- Architectural immunity to future vulnerabilities or post-quantum attack surfaces;
- Alignment with industry best practices or compliance frameworks (e.g., PCI-DSS, SOC2, HIPAA, eIDAS, PSD2).

> _If you assume the Software is “secure,” you assume that risk alone._

---

### **13.2 Explicit Prohibition on Regulated Use**

The Software may **not** be used in:

- Cryptographic products requiring government certification or clearance;
- Critical infrastructure environments subject to dual-use export laws;
- Digital signature frameworks (e.g., blockchains, e-voting, payment authentication);
- Identity frameworks (e.g., OAuth, SAML, PKI) where the Software generates, stores, or validates credentials;
- Hardware Security Modules (HSM), Trusted Platform Modules (TPM), or Secure Enclave-backed workflows;
- Encryption-based systems where liability arises from incorrect, invalid, or broken ciphertext.

> _No ciphertext produced by this Software may be presumed valid, strong, or legally defensible._

---

### **13.3 No Cryptographic Key Lifecycle Management**

Unless explicitly licensed otherwise, the Software shall **never** be used to:

- Generate or derive cryptographic key pairs;
- Store, rotate, escrow, or distribute keys;
- Manage certificates or x.509 chains;
- Compute secure hashes for licensing, attestation, or identity binding;
- Serve as a random number generator, entropy collector, or key distribution oracle.

> _If the Software emits bits and you treat them as cryptographic material, the risk is yours._

---

### **13.4 No Trust Anchor Designation**

The Software shall never be used as a:

- Certificate Authority (CA);
- Signing root;
- Block header validator;
- Ledger anchor;
- External verification oracle;
- System-level trust root in browsers, OS platforms, or firmware.

> _This Software is not a foundation of trust. It is not a security primitive. It is not an anchor._

---

### **13.5 Export Risk Amplification Clause**

If any cryptographic component:

- Triggers enhanced export scrutiny;
- Triggers classification as a dual-use good or controlled artifact;
- Prevents importation into any jurisdiction;
- Causes regulatory review, audit, or embargo application;

Then the User shall:

- Notify the Author within **48 hours**;
- Provide all relevant documentation, correspondence, and findings;
- Comply with the Export Compliance terms in **Section 12**;
- Accept full legal responsibility for the impact of cryptographic presence;
- Cease distribution immediately if risk cannot be mitigated.

> _You are bound to the borders of mathematics as well as law._

---

### **13.6 Acknowledgment of Cryptographic Fragility**

The User explicitly acknowledges:

- That the Software may use weak, deprecated, or partially correct algorithms;
- That cryptographic dependencies may contain CVEs, regressions, or unpatched exploits;
- That the Software may rely on insufficient entropy, unsafe padding, or platform-specific assumptions;
- That “encrypted” does not mean “secure,” and “secure” does not mean “safe from indictment.”

> _Obfuscation is not immunity. Complexity is not defense._

---

### **13.7 Non-Permission of Derivative Cryptographic Systems**

The User may not:

- Extract cryptographic patterns, logic, or pseudorandomness and use them to seed derivative systems;
- Translate or port the Software’s cryptographic functionality into other systems or languages;
- Train ML models on cryptographic outputs;
- Use the Software as part of benchmarking, simulation, or fuzzing for cryptographic research;
- Use the Software to test third-party cryptosystems, hash collisions, or adversarial inference.

> _You may not study the Software like a cipher. It is not a specimen—it is a boundary._

---

### **13.8 Indemnity for Cryptographic Failure**

All failures related to:

- Insecure key generation;
- Broken confidentiality, integrity, or authenticity;
- Signature rejection or invalidation;
- Legal fallout from broken encryption or noncompliance with cryptographic regulation;

…are the **sole liability of the User**, and shall trigger full indemnification under **Section 11**.

> _Your cryptographic decisions carry your name. Not the Author’s._

---

**Conclusion:**  

Cryptography is power, and power is restricted. This Software may touch that power—but you alone are responsible for how it flows, breaks, or spreads. Treat all cryptographic surfaces as unstable ground. And know that when it collapses, the Author will not be beneath it with you.

---

---

_Part of the General Honest License (GHL) v1.0 authored by Tomas Korcak._