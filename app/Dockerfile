# Stage 1: Hardened FastAPI Container Image
# Project: From Docker to EKS: A Security-First Progression

# ---- Build Stage ----
FROM python:3.11-slim AS builder

WORKDIR /build

# Copy and install dependencies only -- no app code yet
COPY app/requirements.txt .

RUN pip install --no-cache-dir --upgrade pip \
    && pip install --no-cache-dir -r requirements.txt --target /build/deps

# ---- Runtime Stage ----
FROM gcr.io/distroless/python3-debian12 AS runtime

# Metadata
LABEL maintainer="Nisha"
LABEL project="container-security-progression"
LABEL stage="1-docker"

WORKDIR /app

# Copy installed dependencies from builder
COPY --from=builder /build/deps /app/deps

# Copy application source
COPY app/ .

# Add deps to Python path
ENV PYTHONPATH=/app/deps

# Distroless runs as nonroot (UID 65532) by default
USER nonroot

# Expose application port
EXPOSE 8000

# Health check using Python directly
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD ["python3", "-c", "import urllib.request; urllib.request.urlopen('http://localhost:8000/health')"]

# Start uvicorn via Python module
CMD ["-m", "uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8000", "--no-access-log"]