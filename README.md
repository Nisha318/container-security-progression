# 🐳 Stage 1: Docker — Image Hardening & Security Baseline

> **Project:** [From Docker to EKS: A Security-First Progression](../README.md)
> **Author:** [Nisha](https://nishacloud.com) · [Notes by Nisha](https://notesbynisha.com)

![Stage](https://img.shields.io/badge/Stage-1%20of%203-blue?style=flat-square)
![Platform](https://img.shields.io/badge/Platform-Docker-2496ED?style=flat-square&logo=docker&logoColor=white)
![CI](https://github.com/nisha318/container-security-progression/actions/workflows/stage1-scan.yml/badge.svg)
![Trivy](https://img.shields.io/badge/Scanned%20by-Trivy-1904DA?style=flat-square)
![NIST](https://img.shields.io/badge/Compliance-NIST%20800--53-green?style=flat-square)
![License](https://img.shields.io/badge/License-MIT-lightgrey?style=flat-square)

---

## Overview

This stage establishes the container image security baseline for the project. Before any cloud infrastructure is introduced, the application image is hardened, scanned, and validated through a GitHub Actions pipeline.

The same image built here is carried through **Stage 2 (ECS Fargate)** and **Stage 3 (EKS)** unchanged -- demonstrating that security starts at the image layer, not the orchestration layer.

---

## Application

A lightweight **Python FastAPI** app serving as the consistent workload across all three stages.

| Endpoint | Method | Description |
|---|---|---|
| `/health` | GET | Returns service health status |
| `/status` | GET | Returns app name, version, and current stage |
| `/docs` | GET | Auto-generated API documentation (FastAPI built-in) |

---

## Security Controls

| Control | Implementation |
|---|---|
| Non-root execution | `USER appuser` (UID 1001) enforced in Dockerfile |
| Minimal base image | `python:3.12-slim` -- reduced attack surface |
| Multi-stage build | Dependencies isolated from runtime image |
| No secrets in image | Environment variable pattern enforced |
| Sensitive file exclusion | `.dockerignore` scoped to exclude `.env`, IaC, and IDE files |
| CVE scanning | Trivy scans on every pipeline run -- fails on HIGH/CRITICAL |
| Health check | Built-in `HEALTHCHECK` instruction for runtime probing |

---

## NIST 800-53 Control Mapping

| Control ID | Control Name | Implementation |
|---|---|---|
| AC-6 | Least Privilege | Non-root user enforced at container runtime |
| CM-6 | Configuration Settings | Dockerfile enforces hardened, repeatable configuration |
| CM-7 | Least Functionality | Minimal base image, no unnecessary packages installed |
| RA-5 | Vulnerability Scanning | Trivy scans image on every pipeline run |
| SI-3 | Malicious Code Protection | CVE severity threshold gates pipeline success |

> Full cross-stage control mapping: [`compliance/nist-800-53-mapping.md`](../compliance/nist-800-53-mapping.md)

---

## CI/CD Pipeline

**Workflow:** `.github/workflows/stage1-scan.yml`
**Triggers:** Push or pull request to `app/` or `stage-1-docker/`

```
Checkout Code → Build Image → Trivy Scan → Upload Results Artifact
                                   ↓
                        Fails on HIGH/CRITICAL CVEs
```

---

## Local Usage

**Prerequisites:** Docker, Trivy

**Build the image:**
```bash
docker build -f stage-1-docker/Dockerfile -t fastapi-app:stage1 .
```

**Run the container:**
```bash
docker run -p 8000:8000 --read-only --security-opt=no-new-privileges fastapi-app:stage1
```

**Access the app:**
```
Health:   http://localhost:8000/health
Status:   http://localhost:8000/status
API Docs: http://localhost:8000/docs
```

**Run Trivy locally:**
```bash
trivy image fastapi-app:stage1
```

---

## File Structure

```
stage-1-docker/
├── README.md                          # This file
├── .dockerignore                      # Excludes secrets, IaC, and IDE files
└── .github/
    └── workflows/
        └── stage1-scan.yml            # Trivy scan pipeline

app/                                   # Shared across all stages
├── app.py                             # FastAPI application
├── requirements.txt                   # Pinned dependencies
└── Dockerfile                         # Hardened multi-stage build
```

---

## Related Writing

- 📝 [Blog: Container Security Baselines](https://notesbynisha.com) *(coming soon)*
- 💼 [Portfolio: From Docker to EKS](https://nishacloud.com) *(coming soon)*

---

## Project Navigation

| | Stage | Platform |
|---|---|---|
| ← Previous | — | — |
| **Current** | **Stage 1: Docker** | **Image hardening and baseline scanning** |
| → Next | [Stage 2: ECS Fargate](../stage-2-ecs-fargate/README.md) | AWS-native security controls and CI/CD pipeline |
