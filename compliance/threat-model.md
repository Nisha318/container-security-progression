# Threat Model: Stage 1 - Docker Container Image Security Baseline
**Project:** From Docker to EKS: A Security-First Progression
**Stage:** 1 of 3 - Docker
**Framework:** STRIDE
**Last Updated:** Stage 1 complete

---

## 1. System Description

This stage produces a security-baseline container image for a Python FastAPI application. The image is built locally on a developer workstation running WSL (Windows Subsystem for Linux) on Windows. The image is scanned for vulnerabilities using Trivy both locally and through a GitHub Actions CI/CD pipeline. At Stage 1, the image is not pushed to any registry and is not deployed to any cloud environment.

**Assets in scope:**
- Developer workstation (WSL on Windows)
- Application source code (`app/app.py`, `app/requirements.txt`)
- Dockerfile and build configuration
- Container image built locally (`fastapi-app:stage1`)
- Python dependencies
- GitHub repository and Actions pipeline configuration
- Base images pulled from external registries (Docker Hub, Google Container Registry)

**Out of scope for Stage 1:**
- Container registry (introduced in Stage 2)
- Cloud infrastructure (introduced in Stage 2 and Stage 3)
- Network controls (introduced in Stage 2 and Stage 3)
- Runtime orchestration (introduced in Stage 3)

---

## 2. Architecture Overview

```
External Registries
(Docker Hub, GCR)
        |
        | docker pull (base images)
        v
Developer Workstation (WSL on Windows)
        |
        |-- docker build (multi-stage build)
        |-- trivy image (local scan)
        |-- docker run (local testing)
        |
        | git push
        v
GitHub Repository
        |
        | triggers on push to app/ or stage-1-docker/
        v
GitHub Actions Pipeline
        |
        |-- Checkout Code
        |-- docker build (rebuilds image from source)
        |-- Trivy Scan (HIGH/CRITICAL threshold, .trivyignore applied)
        |-- Upload Scan Artifact
        |
        v
Validated Image (local only -- no registry push at Stage 1)
```

---

## 3. Threat Model

### STRIDE Threat Analysis

| Threat ID | STRIDE Category | Threat Description | Likelihood | Impact | Controls Implemented | Residual Risk |
|---|---|---|---|---|---|---|
| T-001 | Tampering | Compromised developer workstation introduces malicious code into the application source or Dockerfile during local build | Low | Critical | Source code committed to GitHub providing change history; .dockerignore prevents unintended files from entering build context | Medium -- no automated integrity verification of local workstation at Stage 1 |
| T-002 | Tampering | Unverified base image pulled from Docker Hub or GCR contains malicious or vulnerable content | Low | High | Trivy scans the built image on every pipeline run catching known CVEs in pulled base images; distroless base from Google GCR reduces trust surface | Low -- Trivy catches known vulnerabilities; image digest pinning recommended as future improvement |
| T-003 | Tampering | Vulnerable OS packages in base image contain exploitable CVEs | Medium | High | Trivy scans image on every pipeline run with HIGH/CRITICAL threshold; distroless eliminates unnecessary OS packages | Low -- unfixed CVEs formally documented in .trivyignore with justification and tracked pending upstream fix |
| T-004 | Tampering | Vulnerable Python dependencies introduced via requirements.txt | Medium | High | Trivy scans Python packages on every pipeline run; dependency versions pinned in requirements.txt | Low -- all Python package findings resolved at time of publication |
| T-005 | Tampering | Build tools or package managers included in production image expand attack surface | Medium | Medium | Multi-stage build isolates build tools in builder stage; only compiled dependencies copied to distroless runtime image (also satisfies CIS 4.3 - No unnecessary packages) | Low -- distroless runtime contains no pip, no package manager, no build tools |
| T-006 | Tampering | Pipeline configuration modified to bypass security scan controls | Low | High | Pipeline defined as code in .github/workflows/; exit-code enforcement prevents silent failures; changes require a commit and are visible in git history | Medium -- branch protection rules not yet enforced; pipeline integrity not cryptographically verified at Stage 1 |
| T-007 | Elevation of Privilege | Container process runs as root allowing attacker to gain full system access if container is compromised | Medium | Critical | USER nonroot (UID 65532) enforced in Dockerfile; distroless nonroot user has no sudo or elevated privileges (also satisfies CIS 4.1 - Non-root user) | Low -- non-root enforced at image layer |
| T-008 | Elevation of Privilege | Shell access enables attacker to execute arbitrary commands inside a compromised container | Medium | Critical | Distroless base image contains no shell (/bin/bash, /bin/sh); no shell interpreter available at runtime | Low -- no shell present in runtime image |
| T-009 | Information Disclosure | Secrets or credentials baked into the container image during local build | Low | Critical | .dockerignore excludes .env files and sensitive configurations from build context; environment variable pattern enforced; Trivy secret scanning runs on every pipeline execution | Low -- no secrets present in image; verified by Trivy secret scanning |
| T-010 | Information Disclosure | Sensitive local files accidentally included in the Docker build context | Low | Medium | .dockerignore configured to exclude IDE files, .env files, IaC directories, and non-application files from the build context sent to Docker daemon | Low -- .dockerignore scoped to include only necessary application files |
| T-011 | Repudiation | No record of what the image looked like at build time or what vulnerabilities were present | Low | Medium | Trivy scan results uploaded as pipeline artifact on every run; git commit history provides source code audit trail | Low -- every pipeline run produces a downloadable scan report tied to a specific commit |
| T-012 | Denial of Service | Exploitable CVE in base image OS packages causes container crash or service disruption | Medium | Medium | Trivy blocks deployment of images with unfixed HIGH/CRITICAL CVEs; accepted CVEs are DoS-only with no code execution vector | Low -- accepted CVEs (CVE-2026-40356, CVE-2025-13836) are DoS-only, not code execution; tracked pending upstream fix |
| T-013 | Spoofing | Attacker substitutes a malicious image for the legitimate application image | Low | Critical | Image built directly from source on local workstation and in pipeline; not pulled from external registry at Stage 1 | Medium -- image signing not yet implemented; addressed in Stage 3 |

---

## 4. Residual Risk Summary

| Risk Level | Count | Threat IDs |
|---|---|---|
| Low | 10 | T-002, T-003, T-004, T-005, T-007, T-008, T-009, T-010, T-011, T-012 |
| Medium | 3 | T-001, T-006, T-013 |
| High | 0 | -- |
| Critical | 0 | -- |

**Medium risks accepted for Stage 1 with planned remediation:**

**T-001 (Compromised Workstation):** No automated integrity verification of the local developer workstation exists at Stage 1. Mitigated partially by GitHub commit history providing a change audit trail. Full supply chain security is addressed progressively in later stages.

**T-006 (Pipeline Tampering):** Branch protection rules are not enforced at Stage 1. Recommended remediation: enable branch protection on main, require pull request reviews before merging, and restrict who can modify workflow files.

**T-013 (Image Spoofing):** Image signing is not implemented at Stage 1. This is a known gap. Cosign image signing is planned for Stage 3 (EKS) where the full supply chain security story is completed.

---

## 5. STRIDE to NIST 800-53 Mapping

| STRIDE Category | NIST 800-53 Controls | Stage 1 Implementation |
|---|---|---|
| Spoofing | IA-5 (Authenticator Management) | Not yet implemented -- planned Stage 2/3 |
| Tampering | CM-6, CM-7, RA-5, SA-11 | Dockerfile security controls, Trivy scanning, pinned dependencies, .dockerignore |
| Repudiation | AU-2, AU-12 | Pipeline artifacts and git history provide build-time audit record |
| Information Disclosure | AC-6, SI-2 | Non-root user, .dockerignore, Trivy secret scanning |
| Denial of Service | RA-5, SI-2 | CVE threshold gates pipeline, accepted DoS-only CVEs documented in .trivyignore |
| Elevation of Privilege | AC-6 | Non-root user (UID 65532), no shell in distroless runtime |

---

## 6. Assumptions and Constraints

- The GitHub repository is assumed to be private
- The developer workstation is assumed to be a trusted but unverified environment
- At Stage 1 the image is built and tested locally only -- no registry push, no cloud deployment
- Branch protection and code review policies are outside the scope of Stage 1 but recommended
- Image signing is deferred to Stage 3 where the full registry and deployment pipeline is in place
- Base images are pulled from Docker Hub and Google Container Registry and are trusted but not cryptographically verified at Stage 1
- This threat model covers the local build, local testing, and pipeline scan stages only
- Container security decisions are grounded in NIST SP 800-190 (Application Container Security Guide).

---

## 7. Threat Model Evolution

This threat model grows with each stage as new components are introduced.

| Stage | New Threats Introduced |
|---|---|
| Stage 1 (Docker) | Workstation compromise, dependency vulnerabilities, base image trust, privilege escalation, secret exposure in build context |
| Stage 2 (ECS Fargate) | Registry compromise, image pull tampering, task role abuse, secrets in environment variables, network exposure, IaC misconfiguration |
| Stage 3 (EKS) | Container escape, lateral movement within the cluster, API server exposure, admission control bypass, runtime threats |

---

## Notes

- Likelihood and impact ratings are qualitative (Low/Medium/High/Critical) based on the threat landscape for containerized workloads
- Likelihood ratings informed by NIST SP 800-30 Rev 1 Appendix D qualitative likelihood tables; impact ratings for CVE-specific threats cross-referenced against CVSS base scores from NVD
- This threat model is a living document reviewed and updated at the start of each stage
- This document is intended as a learning artifact and portfolio reference, not a formal security assessment
- Threat modeling framework: STRIDE (Spoofing, Tampering, Repudiation, Information Disclosure, Denial of Service, Elevation of Privilege)
- CIS Docker Benchmark v1.7.0 was used as a supplementary reference alongside NIST 800-53; full CIS mapping is documented in `compliance/cis-docker-benchmark-mapping.md`
