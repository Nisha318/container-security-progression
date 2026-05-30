from fastapi import FastAPI

app = FastAPI(
    title="Container Security Progression",
    description="A lightweight FastAPI app used as a consistent workload across Docker, ECS Fargate, and EKS stages.",
    version="1.0.0"
)


@app.get("/health")
def health():
    return {
        "status": "healthy"
    }


@app.get("/status")
def status():
    return {
        "app": "container-security-progression",
        "version": "1.0.0",
        "stage": "1-docker"
    }
