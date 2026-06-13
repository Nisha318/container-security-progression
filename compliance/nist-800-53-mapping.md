# NIST 800-53 Control Mapping
**Project:** From Docker to EKS: A Security-First Progression
**Repo:** github.com/nisha318/container-security-progression
**Last Updated:** Stage 1 complete

---

## Overview

This document maps security controls implemented across all three stages of the project to NIST 800-53 Rev 5 control families. Controls are introduced progressively. Each stage builds on the previous and expands the compliance posture.

| Stage | Platform | Controls Introduced |
|---|---|---|
| 1 | Docker | AC-6, CM-6, CM-7, RA-5, SA-11, SI-2 |
| 2 | ECS Fargate | AC-2, AC-3, AU-2, AU-12, IA-5, SC-7, SC-8, SC-28 |
| 3 | EKS | AC-4, CM-2, CM-3, IR-4, SA-11, SI-4, SI-7 |

---

## Stage 1: Docker - Container Image Security Baseline

### AC-6 - Least Privilege
**Control:** The organization employs the principle of least privilege, allowing only authorized accesses for users and processes which are necessary to accomplish assigned tasks.

**Implementation:** Container runtime enforces non-root execution via `USER nonroot` (UID 65532) in the Dockerfile. The application process has no elevated privileges at runtime.

**Evidence:** `app/Dockerfile` - USER directive and distroless base image

---

### CM-6 - Configuration Settings
**Control:** The organization establishes and documents configuration settings for information technology products employed within the information system.

**Implementation:** Dockerfile defines a standardized, repeatable configuration enforced at every build. Multi-stage build separates dependency installation from runtime. No mutable configuration at runtime.

**Evidence:** `app/Dockerfile`

---

### CM-7 - Least Functionality
**Control:** The organization configures the information system to provide only essential capabilities, prohibiting or restricting the use of functions, ports, protocols, and services not required.

**Implementation:** Runtime base image is `gcr.io/distroless/python3-debian12`. It contains only the Python runtime and its direct dependencies. No shell, no package manager, no utilities not required by the application. Only port 8000 exposed.

**Evidence:** `app/Dockerfile` - distroless base image selection

---

### RA-5 - Vulnerability Scanning
**Control:** The organization scans for vulnerabilities in the information system and hosted applications, and when new vulnerabilities potentially affecting the system are identified.

**Implementation:** Trivy scans the container image on every pipeline run. Pipeline fails on unfixed HIGH or CRITICAL CVEs. Known findings pending upstream fix are documented in `.trivyignore` with justification and tracked for resolution.

**Accepted Risk:**
| CVE | Severity | Status | Justification |
|---|---|---|---|
| CVE-2026-40356 | HIGH | Pending distroless upstream fix (krb5) | DoS only, no code execution, fix available in 1.20.1-2+deb12u5 |
| CVE-2025-13836 | HIGH | Pending distroless upstream fix (cpython) | DoS via http.client, not used directly in this application |

**Evidence:** `.github/workflows/stage1-scan.yml`, `.trivyignore`

---

## Stage 2: ECS Fargate *(coming soon)*

Controls to be documented upon Stage 2 completion:
- AC-2 (Account Management): task role vs execution role separation
- AC-3 (Access Enforcement): least privilege IAM policies
- AU-2 (Audit Events): CloudWatch Container Insights
- AU-12 (Audit Record Generation): CloudWatch log groups
- IA-5 (Authenticator Management): Secrets Manager, no hardcoded credentials
- SC-7 (Boundary Protection): private subnets, no public IP on tasks
- SC-8 (Transmission Confidentiality): HTTPS/TLS enforcement
- SC-28 (Protection of Information at Rest): EBS encryption, Secrets Manager

---

## Stage 3: EKS *(coming soon)*

Controls to be documented upon Stage 3 completion:
- AC-4 (Information Flow Enforcement): Kyverno network policies
- CM-2 (Baseline Configuration): OpenTofu IaC, Checkov scanning
- CM-3 (Configuration Change Control): GitHub Actions pipeline gates
- IR-4 (Incident Handling): Falco runtime threat detection
- SA-11 (Developer Security Testing): Checkov, Gitleaks in pipeline
- SI-4 (Information System Monitoring): GuardDuty for EKS
- SI-7 (Software, Firmware, and Information Integrity): Kyverno admission policies, image signing

---

## Control Family Summary

| Family | Controls | Stages |
|---|---|---|
| AC - Access Control | AC-2, AC-3, AC-4, AC-6 | 1, 2, 3 |
| AU - Audit and Accountability | AU-2, AU-12 | 2 |
| CM - Configuration Management | CM-2, CM-3, CM-6, CM-7 | 1, 2, 3 |
| IA - Identification and Authentication | IA-5 | 2 |
| IR - Incident Response | IR-4 | 3 |
| RA - Risk Assessment | RA-5 | 1 |
| SA - System and Services Acquisition | SA-11 | 3 |
| SC - System and Communications Protection | SC-7, SC-8, SC-28 | 2 |
| SI - System and Information Integrity | SI-2, SI-4, SI-7 | 1, 3 |

---

## Notes

- Control mappings reflect implementation at the time each stage is completed
- Accepted risk entries in RA-5 are reviewed at the start of each subsequent stage
- This mapping is intended as a learning artifact and portfolio reference, not a formal ATO package
- All controls mapped to NIST SP 800-53 Rev 5
- Container image security baseline decisions are grounded in **NIST SP 800-190 (Application Container Security Guide)**, which is the NIST publication specifically focused on container security, and the CIS Docker Benchmark v1.7.0.
