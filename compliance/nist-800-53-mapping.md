# NIST 800-53 Control Mapping
**Project:** From Docker to EKS: A Security-First Progression
**Repo:** github.com/nisha318/container-security-progression
**Last Updated:** Stage 1 complete

---

## Overview

This document maps security controls implemented across all three stages of the project to NIST 800-53 Rev 5 control families. Controls are introduced progressively -- each stage builds on the previous and expands the compliance posture.

| Stage | Platform | Primary Controls Demonstrated |
|---|---|---|
| 1 | Docker | AC-6, CM-6, CM-7, RA-5, SA-11, SI-2 |
| 2 | ECS Fargate | AC-2, AC-3, AU-2, AU-12, IA-5, SC-7, SC-8, SC-28 |
| 3 | EKS | AC-4, CM-2, CM-3, IR-4, SA-11, SI-4, SI-7 |

---

## Stage 1: Docker - Image Hardening & Security Baseline

### AC-6 - Least Privilege
**Control:** The organization employs the principle of least privilege, allowing only authorized accesses for users and processes which are necessary to accomplish assigned tasks.

**Implementation:** Application processes execute as a non-root user account (UID 65532), restricting privileged operations within the container runtime.

**Evidence:** `app/Dockerfile` - USER directive and distroless base image

---

### CM-6 - Configuration Settings
**Control:** The organization establishes and documents configuration settings for information technology products employed within the information system.

**Implementation:** The Dockerfile establishes standardized and repeatable runtime configuration settings enforced during image creation and deployment.

**Evidence:** `app/Dockerfile`

---

### CM-7 - Least Functionality
**Control:** The organization configures the information system to provide only essential capabilities, prohibiting or restricting the use of functions, ports, protocols, and services not required.

**Implementation:** Runtime base image is `gcr.io/distroless/python3-debian12` -- contains only the Python runtime and its direct dependencies. No shell, no package manager, no utilities not required by the application. Application is designed to serve traffic on a single documented application port (8000).

**Evidence:** `app/Dockerfile` - distroless base image selection

---

### RA-5 - Vulnerability Scanning
**Control:** The organization scans for vulnerabilities in the information system and hosted applications, and when new vulnerabilities potentially affecting the system are identified.

**Implementation:** Automated vulnerability scans execute during every CI pipeline run. Builds fail when unmitigated HIGH or CRITICAL vulnerabilities are identified.

**Accepted Risk:**
| CVE | Severity | Status | Justification |
|---|---|---|---|
| CVE-2026-40356 | HIGH | Pending distroless upstream fix (krb5) | DoS only, no code execution, fix available in 1.20.1-2+deb12u5 |
| CVE-2025-13836 | HIGH | Pending distroless upstream fix (cpython) | DoS via http.client, not used directly in this application |

**Evidence:** `.github/workflows/stage1-scan.yml`, `.trivyignore`

---
### SA-11 - Developer Testing and Evaluation
**Control:** The organization requires the developer of the information system to create and implement a security assessment plan, produce evidence of the execution of the plan, and implement a verifiable flaw remediation process.

**Implementation:** Automated security testing is integrated directly into the CI/CD pipeline and executes on every code push before any artifact is considered deployable. Trivy performs container image vulnerability scanning with a defined severity threshold (HIGH/CRITICAL) that gates pipeline success. Secret scanning runs alongside vulnerability scanning on every pipeline execution. Scan results are uploaded as pipeline artifacts, creating an auditable record of every security assessment performed against the image.

**Evidence:** `.github/workflows/stage1-scan.yml` - Trivy scan step with exit-code enforcement and artifact upload
---

### SI-2 – Flaw Remediation
**Control:** The organization identifies, reports, and corrects information system flaws; tests software updates related to flaw remediation for effectiveness and potential side effects before installation; and incorporates flaw remediation into the organizational configuration management process.

**Implementation:** Automated vulnerability scanning is integrated into the CI/CD pipeline using Trivy. Container images containing unmitigated HIGH or CRITICAL vulnerabilities fail the pipeline and cannot progress to deployment. Accepted risks are documented in .trivyignore with justification and tracked pending upstream remediation.

**Evidence:** '.github/workflows/stage1-scan.yml', '.trivyignore'

---

## Stage 2: ECS Fargate *(coming soon)*

Controls to be documented upon Stage 2 completion:
- AC-2 (Account Management) -- task role vs execution role separation
- AC-3 (Access Enforcement) -- least privilege IAM policies
- AU-2 (Audit Events) -- CloudWatch Container Insights
- AU-12 (Audit Record Generation) -- CloudWatch log groups
- IA-5 (Authenticator Management) -- Secrets Manager, no hardcoded credentials
- SC-7 (Boundary Protection) -- private subnets, no public IP on tasks
- SC-8 (Transmission Confidentiality) -- HTTPS/TLS enforcement
- SC-28 (Protection of Information at Rest) -- EBS encryption, Secrets Manager

---

## Stage 3: EKS *(coming soon)*

Controls to be documented upon Stage 3 completion:
- AC-4 (Information Flow Enforcement) -- Kyverno network policies
- CM-2 (Baseline Configuration) -- OpenTofu IaC, Checkov scanning
- CM-3 (Configuration Change Control) -- GitHub Actions pipeline gates
- IR-4 (Incident Handling) -- Falco runtime threat detection
- SA-11 (Developer Security Testing) -- Checkov, Gitleaks in pipeline
- SI-4 (Information System Monitoring) -- GuardDuty for EKS
- SI-7 (Software, Firmware, and Information Integrity) -- Kyverno admission policies, image signing

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
