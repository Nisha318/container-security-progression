# CIS Docker Benchmark Mapping
**Project:** From Docker to EKS: A Security-First Progression
**Stage:** 1 of 3 - Docker
**Benchmark:** CIS Docker Benchmark v1.7.0
**Last Updated:** Stage 1 complete

---

## Overview

This document maps the container image hardening decisions made in Stage 1 to the CIS Docker Benchmark v1.7.0. The CIS Docker Benchmark is organized into sections covering host configuration, daemon configuration, and container images. Stage 1 focuses primarily on **Section 4 (Container Images)** as it covers the Dockerfile and image build decisions that are within scope for a local development and pipeline context.

The benchmark uses two recommendation levels:
- **Level 1** -- Practical, lower-risk recommendations that can be applied in most environments
- **Level 2** -- More stringent recommendations that may impact functionality; defense in depth

---

## Section 4: Container Images and Build Files

Section 4 is the most directly relevant to Stage 1. It covers how container images are built, what they contain, and how they are configured.

### 4.1 - Ensure a user for the container has been created
**Level:** 1
**Benchmark requirement:** Ensure that a non-root user is created and used for the container to restrict the impact of container compromise.

**Status:** PASS

**Implementation:** The distroless base image `gcr.io/distroless/python3-debian12` ships with a built-in `nonroot` user at UID 65532. The Dockerfile enforces this with:
```
USER nonroot
```
The application process runs as UID 65532 with no elevated privileges. If the container is compromised, the attacker is limited to an unprivileged user account.

**Evidence:** `app/Dockerfile` - USER directive

---

### 4.2 - Ensure that containers use only trusted base images
**Level:** 1
**Benchmark requirement:** Ensure that the container image is written either from scratch or is based on another established and trusted base image downloaded over a secure channel.

**Status:** PASS

**Implementation:** The runtime base image is `gcr.io/distroless/python3-debian12` sourced from Google Container Registry (GCR), a trusted registry maintained by Google. The builder stage uses `python:3.11-slim` from Docker Hub's official Python image maintained by the Docker Official Images program. Both are pulled over HTTPS. Base image digests are verified during pull.

**Evidence:** `app/Dockerfile` - FROM statements

---

### 4.3 - Ensure that unnecessary packages are not installed in the container
**Level:** 1
**Benchmark requirement:** Do not install anything that is not required in the container image.

**Status:** PASS

**Implementation:** The distroless runtime base image contains only the Python 3.11 runtime and its minimum OS dependencies -- no shell, no package manager, no system utilities. The multi-stage build ensures that only application dependencies (FastAPI, Uvicorn, and their transitive dependencies) are present in the final image. No additional packages are installed at runtime.

**Evidence:** `app/Dockerfile` - distroless base image, multi-stage build pattern

---

### 4.4 - Ensure images are scanned and rebuilt to include security patches
**Level:** 1
**Benchmark requirement:** Images should be scanned frequently for any vulnerabilities. Rebuild the images to include patches and then instantiate new containers from it.

**Status:** PASS

**Implementation:** Trivy scans the container image on every GitHub Actions pipeline run. The pipeline is configured to fail on unfixed HIGH or CRITICAL CVEs, ensuring that vulnerable images cannot progress. Known vulnerabilities pending upstream fixes are documented in `.trivyignore` with justification and tracked for remediation when upstream patches become available.

**Evidence:** `.github/workflows/stage1-scan.yml`, `.trivyignore`

---

### 4.5 - Ensure Content Trust for Docker is enabled
**Level:** 2
**Benchmark requirement:** Enable Docker Content Trust to ensure image integrity and authenticity via digital signatures.

**Status:** NOT IMPLEMENTED - Deferred to Stage 3

**Justification:** Docker Content Trust (DCT) was officially retired by Docker. The CIS Docker Benchmark documentation acknowledges this and notes that Cosign is the recommended alternative for image signing. Image signing via Cosign is planned for Stage 3 (EKS) where the full registry and deployment pipeline is in place. This is a known gap documented as accepted risk T-013 in the threat model.

**Planned remediation:** Cosign image signing in Stage 3

---

### 4.6 - Ensure HEALTHCHECK instructions have been added to container images
**Level:** 1
**Benchmark requirement:** Add HEALTHCHECK instruction to the container image to allow the Docker engine to check the running container state.

**Status:** PASS

**Implementation:** The Dockerfile includes a HEALTHCHECK instruction that probes the `/health` endpoint every 30 seconds with a 5-second timeout. This allows Docker and container orchestration platforms (ECS in Stage 2, EKS in Stage 3) to detect unhealthy containers and respond automatically.

```
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD ["python3", "-c", "import urllib.request; urllib.request.urlopen('http://localhost:8000/health')"]
```

**Evidence:** `app/Dockerfile` - HEALTHCHECK instruction

---

### 4.7 - Ensure update instructions are not used alone in the Dockerfile
**Level:** 1
**Benchmark requirement:** Do not use update instructions in isolation in the Dockerfile. Combine update with install or use fixed versions to prevent caching issues.

**Status:** PASS

**Implementation:** The builder stage upgrades pip explicitly during the install step:
```
RUN pip install --no-cache-dir --upgrade pip \
    && pip install --no-cache-dir -r requirements.txt --target /build/deps
```
pip upgrade and package installation are combined in a single RUN instruction to prevent layer caching issues. All application dependencies are pinned to specific versions in `requirements.txt`.

**Evidence:** `app/Dockerfile` - combined RUN instruction, `app/requirements.txt` - pinned versions

---

### 4.8 - Ensure setuid and setgid permissions are removed
**Level:** 2
**Benchmark requirement:** Remove setuid and setgid permissions from files in the container image to prevent privilege escalation attacks.

**Status:** PARTIAL

**Justification:** The distroless base image significantly reduces the presence of setuid/setgid binaries by removing shells, system utilities, and other OS tools that typically carry these permissions. However, explicit removal of remaining setuid/setgid permissions has not been performed. The distroless image's minimal surface area substantially reduces the risk. Full verification and explicit removal is a future improvement.

---

### 4.9 - Ensure COPY is used instead of ADD in Dockerfiles
**Level:** 1
**Benchmark requirement:** Use COPY instead of ADD in Dockerfiles. ADD can fetch remote URLs and extract archives automatically, which introduces unnecessary attack surface.

**Status:** PASS

**Implementation:** All file copy operations in the Dockerfile use COPY exclusively. ADD is not used anywhere in the build.

**Evidence:** `app/Dockerfile` - COPY instructions only

---

### 4.10 - Ensure secrets are not stored in Dockerfiles
**Level:** 1
**Benchmark requirement:** Do not store any secrets in Dockerfiles. Secrets passed as environment variables during build may be exposed in image history.

**Status:** PASS

**Implementation:** No secrets, credentials, API keys, or sensitive configuration values are stored in the Dockerfile or baked into the image. The application uses environment variables at runtime for any configuration. The `.dockerignore` file excludes `.env` files and other sensitive files from the build context. Trivy secret scanning runs on every pipeline execution to verify no secrets are present in the image.

**Evidence:** `app/Dockerfile`, `.dockerignore`, `.github/workflows/stage1-scan.yml` - Trivy secret scanning enabled

---

### 4.11 - Ensure only verified packages are installed
**Level:** 1
**Benchmark requirement:** Verify the authenticity and integrity of packages installed in the container image.

**Status:** PASS

**Implementation:** All Python dependencies are installed from PyPI via pip with pinned version numbers specified in `requirements.txt`. pip verifies package integrity via hash checking during installation. No packages are installed from unverified or unofficial sources.

**Evidence:** `app/requirements.txt` - pinned dependency versions

---

## Section 5: Container Runtime (Partial - Local Testing Only)

Section 5 covers container runtime security. At Stage 1, containers run locally for testing purposes only. Full runtime controls are implemented in Stage 2 (ECS Fargate) and Stage 3 (EKS). The following runtime flags are documented as recommended practice and used during local testing.

### 5.1 - Ensure AppArmor Profile is applied (where applicable)
**Status:** NOT IN SCOPE - Stage 1 is local development only

### 5.4 - Ensure privileged containers are not used
**Status:** PASS (local testing)
**Implementation:** The container is not run with `--privileged` flag. Distroless nonroot user enforces unprivileged execution.

### 5.7 - Ensure privileged ports are not mapped within containers
**Status:** PASS
**Implementation:** Application binds to port 8000, a non-privileged port (>1024).

### 5.9 - Ensure the host network namespace is not shared
**Status:** PASS (local testing)
**Implementation:** No `--network=host` flag used. Container runs in an isolated network namespace.

### 5.25 - Ensure the container is restricted from acquiring additional privileges
**Status:** PASS (local testing)
**Implementation:** Local testing uses `--security-opt=no-new-privileges` flag:
```
docker run -p 8000:8000 --read-only --security-opt=no-new-privileges fastapi-app:stage1
```

---

## Compliance Summary

| Section | Control | Status | Notes |
|---|---|---|---|
| 4.1 | Non-root user | PASS | USER nonroot (UID 65532) |
| 4.2 | Trusted base images | PASS | GCR distroless, Docker Official python:3.11-slim |
| 4.3 | No unnecessary packages | PASS | Distroless runtime, multi-stage build |
| 4.4 | Image scanning | PASS | Trivy on every pipeline run |
| 4.5 | Content Trust / Image signing | DEFERRED | Cosign planned for Stage 3 |
| 4.6 | HEALTHCHECK | PASS | 30s interval, /health endpoint |
| 4.7 | No isolated update instructions | PASS | Combined RUN, pinned versions |
| 4.8 | setuid/setgid removal | PARTIAL | Distroless reduces risk; explicit removal not yet performed |
| 4.9 | COPY not ADD | PASS | COPY used exclusively |
| 4.10 | No secrets in Dockerfile | PASS | .dockerignore + Trivy secret scanning |
| 4.11 | Verified packages only | PASS | Pinned versions from PyPI |
| 5.4 | No privileged containers | PASS | Nonroot enforced |
| 5.7 | No privileged ports | PASS | Port 8000 |
| 5.9 | No host network sharing | PASS | Isolated network namespace |
| 5.25 | No new privileges | PASS | --security-opt=no-new-privileges |

**Total Stage 1 scope:** 15 controls evaluated
**PASS:** 12
**PARTIAL:** 1 (4.8 setuid/setgid)
**DEFERRED:** 1 (4.5 image signing - Stage 3)
**NOT IN SCOPE:** 1 (5.1 AppArmor - local dev only)

---

## CIS to NIST 800-53 Cross-Reference

| CIS Control | NIST 800-53 Control | Description |
|---|---|---|
| 4.1 Non-root user | AC-6 Least Privilege | Both require minimum necessary access |
| 4.2 Trusted base images | SI-2 Flaw Remediation | Trusted sources reduce inherited vulnerability risk |
| 4.3 No unnecessary packages | CM-7 Least Functionality | Both require removing unnecessary capabilities |
| 4.4 Image scanning | RA-5 Vulnerability Scanning | Both require regular scanning and patching |
| 4.5 Image signing | IA-5 Authenticator Management | Both address integrity and authenticity |
| 4.6 HEALTHCHECK | SI-2 Flaw Remediation | Health monitoring supports resilience and recovery |
| 4.10 No secrets in image | IA-5 Authenticator Management | Both address credential protection |
| 4.11 Verified packages | SA-11 Developer Testing | Both address supply chain integrity |

---

## Notes

- CIS Docker Benchmark v1.7.0 (August 2024) was used for this mapping
- Section 1 (Host Configuration) and Section 2 (Docker Daemon) are out of scope for Stage 1 -- these apply to the Docker host environment, not the container image
- Section 3 (Docker Daemon Configuration Files) is out of scope for Stage 1
- Full runtime controls (Section 5) are implemented in Stage 2 and Stage 3
- This mapping is a learning artifact and portfolio reference, not a formal compliance assessment
- CIS Benchmark PDF available at: https://www.cisecurity.org/benchmark/docker
