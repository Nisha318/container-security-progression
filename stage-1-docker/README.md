# 🐳 Stage 1: Docker - Container Image Security Baseline

> **Project:** [From Docker to EKS: A Security-First Progression](../README.md)
> **Author:** [Nisha](https://nishacloud.com) · [Notes by Nisha](https://notesbynisha.com)

![Stage](https://img.shields.io/badge/Stage-1%20of%203-blue?style=flat-square)
![Platform](https://img.shields.io/badge/Platform-Docker-2496ED?style=flat-square&logo=docker&logoColor=white)
![CI](https://github.com/nisha318/container-security-progression/actions/workflows/stage1-scan.yml/badge.svg)
![Trivy](https://img.shields.io/badge/Scanned%20by-Trivy-1904DA?style=flat-square)
![NIST](https://img.shields.io/badge/Compliance-NIST%20800--53-green?style=flat-square)
![CIS](https://img.shields.io/badge/Compliance-CIS%20Docker-orange?style=flat-square)
![Threat Model](https://img.shields.io/badge/Threat%20Model-STRIDE%20v1.7-purple?style=flat-square)
![License](https://img.shields.io/badge/License-MIT-lightgrey?style=flat-square)

---

## Overview

This stage establishes the container image security baseline for the project. Before any cloud infrastructure is introduced, the application image is the application image is secured, scanned, and validated through a GitHub Actions pipeline.

The same image built here is carried through **Stage 2 (ECS Fargate)** and **Stage 3 (EKS)** unchanged to demonstrate that security starts at the image layer, not the orchestration layer.

---

## Application

A lightweight **Python FastAPI** app serving as the workload across all three stages.

| Endpoint | Method | Description |
|---|---|---|
| `/health` | GET | Returns service health status |
| `/status` | GET | Returns app name, version, and current stage |
| `/docs` | GET | Auto-generated API documentation (FastAPI built-in) |

<!-- screenshot: fastapi-health-endpoint.png -->
![FastAPI health endpoint](../docs/images/stage-1/fastapi-health-endpoint.png)

<!-- screenshot: fastapi-status-endpoint.png -->
![FastAPI status endpoint](../docs/images/stage-1/fastapi-status-endpoint.png)

<!-- screenshot: fastapi-docs-ui.png -->
![FastAPI docs UI](../docs/images/stage-1/fastapi-docs-ui.png)

---

## Security Controls

| Control | Implementation |
|---|---|
| Non-root execution | `USER nonroot` (UID 65532) enforced in Dockerfile |
| Minimal base image | `gcr.io/distroless/python3-debian12` -- no shell, no package manager |
| Multi-stage build | Dependencies isolated from runtime image |
| No secrets in image | Environment variable pattern enforced |
| Sensitive file exclusion | `.dockerignore` scoped to exclude `.env`, IaC, and IDE files |
| CVE scanning | Trivy scans on every pipeline run -- fails on unfixed HIGH/CRITICAL |
| Accepted risk documented | `.trivyignore` records known CVEs pending upstream fix with justification |
| Health check | Built-in `HEALTHCHECK` instruction for runtime probing |

<!-- screenshot: trivy-scan-clean.png -->
![Trivy clean scan](../docs/images/stage-1/trivy-scan-clean.png)

---

## Security Controls and Compliance Mapping

| Control ID | Control Name | Implementation |
|---|---|---|
| AC-6 | Least Privilege | Non-root user (UID 65532) enforced at container runtime |
| CM-6 | Configuration Settings | Dockerfile enforces hardened, repeatable configuration |
| CM-7 | Least Functionality | Distroless base image, no unnecessary packages or shell |
| RA-5 | Vulnerability Scanning | Trivy scans image on every pipeline run |
| SA-11 | Developer Testing and Evaluation | Automated security testing gates every pipeline run, results uploaded as artifacts |
| SI-2 | Flaw Remediation | CVE severity threshold gates pipeline success, accepted risks documented in .trivyignore |

> Full cross-stage control mapping: [`compliance/nist-800-53-mapping.md`](../compliance/nist-800-53-mapping.md)
> CIS Docker Benchmark mapping: [`compliance/cis-docker-benchmark-mapping.md`](../compliance/cis-docker-benchmark-mapping.md)
> Threat model: [`compliance/threat-model.md`](../compliance/threat-model.md)

---

## CI/CD Pipeline

**Workflow:** `.github/workflows/stage1-scan.yml`
**Triggers:** Push or pull request to `app/` or `stage-1-docker/`

```mermaid
flowchart TD
    A["Code Push to main"] --> B["GitHub Actions Triggered"]
    B --> C["Checkout Code"]
    C --> D["Build Docker Image\ngcr.io/distroless/python3-debian12"]
    D --> E["Run Trivy Scan\nSeverity: HIGH, CRITICAL\nignore-unfixed: true\n.trivyignore applied"]
    E --> F{{"CVEs Found?"}}
    F -->|"YES - unfixed HIGH/CRITICAL"| G["Pipeline Fails\nImage not deployable"]
    F -->|"NO - clean scan"| H["Pipeline Passes"]
    H --> I["Upload Scan Results\nas Pipeline Artifact"]
    I --> J["Image ready for\nStage 2 deployment"]
```

<!-- screenshot: github-actions-pipeline-success.png -->
![GitHub Actions pipeline success](../docs/images/stage-1/github-actions-pipeline-success.png)

---

## Local Usage

**Prerequisites:** Docker, Trivy

**Build the image:**
```bash
docker build -f app/Dockerfile -t fastapi-app:stage1 .
```

**Run the container:**
```bash
docker run -p 8000:8000 --read-only --security-opt=no-new-privileges fastapi-app:stage1
```

<!-- screenshot: docker-desktop-running-container.png -->
![Docker Desktop running container](../docs/images/stage-1/docker-desktop-running-container.png)

**Access the app:**
```
Health:   http://localhost:8000/health
Status:   http://localhost:8000/status
API Docs: http://localhost:8000/docs
```

**Run Trivy locally:**
```bash
trivy image --ignore-unfixed --severity HIGH,CRITICAL --ignorefile .trivyignore fastapi-app:stage1
```

---

## File Structure

```
container-security-progression/
├── .trivyignore                           # Documented CVE exceptions with justification
├── .github/
│   └── workflows/
│       └── stage1-scan.yml                # Trivy scan pipeline (root level)
├── app/                                   # Shared across all stages
│   ├── app.py                             # FastAPI application
│   ├── requirements.txt                   # Pinned dependencies
│   └── Dockerfile                         # Multi-stage distroless build
├── stage-1-docker/
│   ├── README.md                          # This file
│   └── .dockerignore                      # Excludes secrets, IaC, and IDE files
└── docs/
    └── images/
        └── stage-1/                       # Screenshots for this stage
```

---

## Related Writing

- 📝 [Blog: Container Security Starts Before the Cloud](https://notesbynisha.com/blog/container-security-starts-before-the-cloud/) 
- 💼 [Portfolio: From Docker to EKS](https://nishacloud.com) *(coming soon)*

---

## Project Navigation

| | Stage | Platform |
|---|---|---|
| **Current** | **Stage 1: Docker** | **Container image security baseline and CVE scanning** |
[Stage 2: ECS Fargate](../stage-2-ecs-fargate/README.md) | AWS-native security controls and CI/CD pipeline |
