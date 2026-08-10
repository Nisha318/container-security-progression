# Threat Model: Container Security Progression
**Project:** From Docker to EKS: A Security-First Progression
**Stages Covered:** 1 (Docker) and 2 (ECS Fargate)
**Framework:** STRIDE
**Last Updated:** Stage 2 complete

---

## 1. System Description

This project produces a security-baseline container image for a Python FastAPI application and progressively deploys it across increasingly capable AWS environments. Stage 1 builds and scans the image locally. Stage 2 deploys the same image to Amazon ECS Fargate using infrastructure defined in OpenTofu.

**Assets in scope (Stage 1):**
- Developer workstation (WSL on Windows)
- Application source code (`app/app.py`, `app/requirements.txt`)
- Dockerfile and build configuration
- Container image built locally (`fastapi-app:stage1`)
- Python dependencies
- GitHub repository and Actions pipeline configuration
- Base images pulled from external registries (Docker Hub, Google Container Registry)

**Assets in scope (Stage 2, additive):**
- ECR private registry
- ECS Fargate task definition and service
- IAM roles (task execution role, task role, GitHub Actions OIDC role)
- AWS Secrets Manager
- VPC and network boundary (public/private subnets, VPC endpoints)
- OpenTofu IaC configuration and remote state (S3 + DynamoDB)
- GitHub Actions pipeline additions (Checkov, Gitleaks)
- GuardDuty runtime agent
- Application Load Balancer and ACM certificate

**Out of scope for Stage 1:**
- Container registry (introduced in Stage 2)
- Cloud infrastructure (introduced in Stage 2 and Stage 3)
- Network controls (introduced in Stage 2 and Stage 3)
- Runtime orchestration (introduced in Stage 3)

**Out of scope for Stage 2:**
- Kubernetes orchestration and cluster-level threats (introduced in Stage 3)
- Multi-account or organization-wide GuardDuty delegation (single-account project)
- Web Application Firewall (production hardening consideration, not implemented)
- Image signing (deferred to Stage 3)

---

## 2. Architecture Overview

**Stage 1 (local build and scan):**

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

**Stage 2 (cloud deployment, additive):**

```
GitHub Actions Pipeline
        |
        |-- Gitleaks (secret detection)
        |-- Trivy (image scan)
        |-- Checkov (IaC scan)
        |-- OpenTofu validate
        |
        v
ECR (private registry, immutable tags, KMS encrypted)
        |
        | image pull via VPC endpoint
        v
ECS Fargate Task (private subnet)
        |-- Secrets injected from Secrets Manager via VPC endpoint
        |-- Logs streamed to CloudWatch via VPC endpoint
        |-- GuardDuty runtime agent monitors process/network/file activity
        |
        v
Application Load Balancer (public subnet, HTTPS only)
        |
        v
End User
```

---

## 3. Data Flow Diagram

The Level 1 DFD below models Stage 2 as four processes, three data stores, two external entities, and three trust boundaries. Each arrow crossing a trust boundary is a candidate threat in the STRIDE analysis that follows.

![Stage 2 Level 1 DFD](../docs/images/stage-2/stage2-dfd.svg)

---

## 4. Threat Model

### Stage 1: Docker Threat Analysis

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
| T-012 | Denial of Service | Exploitable CVE in base image OS packages causes container crash or service disruption | Medium | Medium | Trivy blocks deployment of images with unfixed HIGH/CRITICAL CVEs; accepted CVEs are DoS-only with no code execution vector | Low -- accepted CVEs are DoS-only, not code execution; tracked pending upstream fix |
| T-013 | Spoofing | Attacker substitutes a malicious image for the legitimate application image | Low | Critical | Image built directly from source on local workstation and in pipeline; not pulled from external registry at Stage 1 | Medium -- image signing not yet implemented; addressed in Stage 3 |

### Stage 2: ECS Fargate Threat Analysis

**New attack surface introduced in Stage 2:**
- ECR private registry (image storage and pull path)
- ECS Fargate task definition and service (orchestration layer)
- IAM roles (task execution role, task role, GitHub Actions OIDC role)
- AWS Secrets Manager (app config injection)
- VPC and network boundary (public/private subnets, VPC endpoints)
- OpenTofu IaC configuration and remote state
- GitHub Actions pipeline additions (Checkov, Gitleaks)
- GuardDuty runtime agent

| Threat ID | STRIDE Category | Threat Description | Likelihood | Impact | Controls Implemented | Residual Risk |
|---|---|---|---|---|---|---|
| T-014 | Spoofing | ECS assumes a role on behalf of another account (confused deputy). A service principal like ecs-tasks.amazonaws.com could be used by a different account to assume task roles if the trust policy lacks account scoping. | Low | High | `aws:SourceAccount` condition on both task execution and task role trust policies. Restricts assumption to this account only. | Low |
| T-015 | Spoofing | GitHub Actions credentials stolen and used to impersonate CI pipeline. Long-lived access keys stored as GitHub secrets could be exfiltrated and replayed. | Medium | High | OIDC authentication: short-lived tokens issued per workflow run, scoped to specific repo. No long-lived credentials stored in GitHub. | Low |
| T-016 | Tampering | ECR image tag overwritten with compromised image. An attacker with push access replaces a known-good tagged image (e.g., v1.0.0) with a malicious one, affecting the next deployment. | Low | Critical | `image_tag_mutability = IMMUTABLE` on ECR repository. Existing tags cannot be overwritten. | Low |
| T-017 | Tampering | IaC configuration tampered in source control. A malicious commit modifies security-relevant settings (e.g., opens security groups, removes readonlyRootFilesystem) before Checkov is bypassed or fails silently. | Low | High | Checkov IaC scanning gates pipeline. Remote state with DynamoDB locking prevents concurrent modification. Branch protection recommended. Checkov findings documented in .checkovignore -- arbitrary policy changes would produce new unaccepted findings. | Medium |
| T-018 | Repudiation | Container runtime actions denied without audit trail. A compromised task executes malicious processes and the actor claims no such activity occurred. | Low | Medium | GuardDuty Runtime Monitoring captures process execution, network connections, and file access inside the running container. CloudWatch Logs captures stdout/stderr. VPC flow logs capture network-level activity. | Low |
| T-019 | Information Disclosure | App secrets exposed as plaintext environment variables. Secrets hardcoded in task definition environment blocks appear in ECS console, CloudTrail, and state files in plaintext. | Low | High | All sensitive values stored in Secrets Manager. ECS injects them at startup via the secrets block -- not the environment block. Placeholder values in code; real values set manually before deployment. lifecycle.ignore_changes prevents Tofu from resetting to placeholders. | Low |
| T-020 | Information Disclosure | Secrets exposed in transit between Secrets Manager and ECS task. If secret injection traffic traverses the public internet, it is subject to interception even if encrypted. | Low | High | VPC endpoint for Secrets Manager routes injection traffic entirely within the AWS network. Traffic never reaches the public internet. KMS encryption protects data at rest in Secrets Manager. | Low |
| T-021 | Information Disclosure | OpenTofu state file exposes sensitive infrastructure values. State files contain resource ARNs, IDs, and potentially sensitive output values in plaintext. | Low | Medium | Remote state stored in S3 with server-side encryption enabled. DynamoDB lock table. State file not stored locally. .gitignore excludes *.tfstate. | Low |
| T-022 | Denial of Service | ECS task resource exhaustion. A runaway process inside the container consumes all allocated CPU or memory, causing the task to be killed and restart looping. | Medium | Medium | Fargate enforces hard CPU (256) and memory (512MB) limits at the task definition level. Tasks cannot exceed their allocation. ECS service replaces unhealthy tasks automatically. CloudWatch alarms monitor running task count, ALB 5xx errors, and unhealthy host count, with SNS notification on state change. | Low |
| T-023 | Elevation of Privilege | Container escape to underlying host. A vulnerability in the container runtime allows a process to break out of the container namespace and access the host OS. | Low | Critical | Fargate eliminates the vulnerable host attack surface entirely -- there is no accessible host OS. readonlyRootFilesystem, non-root user (UID 65532), and drop ALL Linux capabilities reduce the blast radius of any container-level exploit. | Low |
| T-024 | Elevation of Privilege | Task role abuse enables lateral movement within AWS. An attacker with code execution inside the container uses the task role to call AWS APIs, escalate privileges, or move to other resources. | Low | High | Task role has zero IAM permissions. The FastAPI app makes no AWS API calls at runtime. An attacker inside the container gets no AWS access from the task role. Execution role is not accessible at runtime -- it is used only by the ECS agent during bootstrap. | Low |

---

## 5. Residual Risk Summary

### Stage 1

| Risk Level | Count | Threat IDs |
|---|---|---|
| Low | 10 | T-002, T-003, T-004, T-005, T-007, T-008, T-009, T-010, T-011, T-012 |
| Medium | 3 | T-001, T-006, T-013 |
| High | 0 | -- |
| Critical | 0 | -- |

**T-001 (Compromised Workstation):** No automated integrity verification of the local developer workstation exists at Stage 1. Mitigated partially by GitHub commit history providing a change audit trail. Full supply chain security is addressed progressively in later stages.

**T-006 (Pipeline Tampering):** Branch protection rules are not enforced at Stage 1. Recommended remediation: enable branch protection on main, require pull request reviews before merging, and restrict who can modify workflow files.

**T-013 (Image Spoofing):** Image signing is not implemented at Stage 1. This is a known gap. Cosign image signing is planned for Stage 3 (EKS) where the full supply chain security story is completed.

### Stage 2

| Risk Level | Count | Threat IDs |
|---|---|---|
| Low | 10 | T-014, T-015, T-016, T-018, T-019, T-020, T-021, T-022, T-023, T-024 |
| Medium | 1 | T-017 |
| High | 0 | -- |
| Critical | 0 | -- |

**T-017 (IaC Tampering):** Residual risk is Medium because branch protection and mandatory code review are outside the scope of this project. In a production environment, these would be enforced at the GitHub repository level.

---

## 6. STRIDE to NIST 800-53 Mapping

| Threat ID | STRIDE Category | NIST 800-53 Controls |
|---|---|---|
| T-001 to T-006 | Tampering | CM-6, CM-7, RA-5, SA-11 |
| T-007, T-008 | Elevation of Privilege | AC-6 |
| T-009, T-010 | Information Disclosure | AC-6, SI-2 |
| T-011 | Repudiation | AU-2, AU-12 |
| T-012 | Denial of Service | RA-5, SI-2 |
| T-013 | Spoofing | IA-5 |
| T-014, T-024 | Spoofing / Elevation of Privilege | AC-3, AC-6 |
| T-015 | Spoofing | IA-5, SA-11 |
| T-016, T-017 | Tampering | CM-6, SA-11 |
| T-018 | Repudiation | SI-4 |
| T-019 | Information Disclosure | IA-5, SC-28 |
| T-020 | Information Disclosure | SC-7, SC-8 |
| T-021 | Information Disclosure | SC-28 |
| T-022 | Denial of Service | CM-6, SI-4 |
| T-023 | Elevation of Privilege | CM-6, CM-7 |

---

## 7. Assumptions and Constraints

- The GitHub repository is assumed to be private
- The developer workstation is assumed to be a trusted but unverified environment
- Stage 1 built and tested the image locally only; Stage 2 pushes the image to a private ECR registry and deploys it to ECS Fargate
- Branch protection and code review policies are outside the scope of this project but recommended
- Image signing is deferred to Stage 3 where the full registry and deployment pipeline is in place
- Base images are pulled from Docker Hub and Google Container Registry and are trusted but not cryptographically verified
- This threat model covers local build, cloud deployment, and pipeline scan stages through Stage 2
- GuardDuty is deployed at the single-account level; multi-account/organization delegation is out of scope
- Container security decisions are grounded in NIST SP 800-190 (Application Container Security Guide)

---

## 8. Threat Model Evolution

This threat model grows with each stage as new components are introduced.

| Stage | New Threats Introduced | Status |
|---|---|---|
| Stage 1 (Docker) | Workstation compromise, dependency vulnerabilities, base image trust, privilege escalation, secret exposure in build context | Complete -- T-001 to T-013 |
| Stage 2 (ECS Fargate) | Registry tampering, confused deputy, IaC misconfiguration, secrets in transit, state file exposure, task role abuse, container escape, resource exhaustion | Complete -- T-014 to T-024 |
| Stage 3 (EKS) | Container escape, lateral movement within the cluster, API server exposure, admission control bypass, runtime threats | Planned |

---

## Notes

- Likelihood and impact ratings are qualitative (Low/Medium/High/Critical) based on the threat landscape for containerized workloads
- Likelihood ratings informed by NIST SP 800-30 Rev 1 Appendix D qualitative likelihood tables; impact ratings for CVE-specific threats cross-referenced against CVSS base scores from NVD
- This threat model is a living document reviewed and updated at the start of each stage
- This document is intended as a learning artifact and portfolio reference, not a formal security assessment
- Threat modeling framework: STRIDE (Spoofing, Tampering, Repudiation, Information Disclosure, Denial of Service, Elevation of Privilege)
- CIS Docker Benchmark v1.7.0 was used as a supplementary reference alongside NIST 800-53; full CIS mapping is documented in `compliance/cis-docker-benchmark-mapping.md`
- Data flow diagram methodology: Yourdon-DeMarco, with trust boundaries added per STRIDE-per-element practice
