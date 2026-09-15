# Stage 9 — Containers

> **Project milestone:** The app runs as a Docker container in Azure Container Apps. An Azure Container Registry (ACR) stores the image. The pipeline builds the image, pushes to ACR, and deploys a new revision to Container Apps on every merge to `main`.

---

## What you'll build this stage

```
project/
├── app/
│   └── Dockerfile               ← new: containerize the app
└── infra/
    └── terraform/
        └── modules/
            ├── acr/              ← new: Azure Container Registry
            └── container-apps/  ← new: Container Apps environment + app
.github/
└── workflows/
    └── app-deploy.yml           ← updated: build image → push to ACR → deploy revision
```

---

## What to cover

### Docker
- What containers are and why they matter for reproducible deployments
- Writing a `Dockerfile`: base image, copy files, install dependencies, set entrypoint
- Core commands: `docker build`, `docker run`, `docker push`, `docker pull`
- Image layers and caching — why order of instructions matters
- Multi-stage builds for smaller production images

### Azure Container Registry (ACR)
- Creating an ACR and pushing/pulling images
- ACR authentication: admin credentials (avoid), Managed Identity (prefer)
- Geo-replication for multi-region deployments
- ACR Tasks for building images in Azure

### Azure Container Apps
- What Container Apps is: serverless containers, scale to zero, no cluster to manage
- Container Apps Environment: the shared networking and logging boundary
- Revisions: immutable snapshots — a new deploy creates a new revision
- Traffic splitting: send 90% to the current revision, 10% to the new one
- Ingress: built-in HTTPS, custom domains
- Managed Identity for pulling from ACR and accessing Key Vault / Azure OpenAI

---

## Project Step

1. Write a `Dockerfile` for the app. Build it locally and run it — confirm it works identically to the non-containerized version.
2. Add `azurerm_container_registry` to Terraform in a new `modules/acr/` module.
3. Grant the Container Apps Managed Identity `AcrPull` on the ACR.
4. Add a Container Apps Environment and Container App in a new `modules/container-apps/` module. Configure:
   - Ingress: external HTTPS
   - Managed Identity: system-assigned
   - Key Vault and Azure OpenAI access via the same identity (as in Stage 6)
5. Update the app pipeline to:
   - Build the Docker image and tag it with the Git SHA
   - Push to ACR using OIDC (no ACR admin password)
   - Deploy a new Container Apps revision pointing to the new image tag
6. Remove the App Service resources from Terraform (`terraform destroy -target=...` or delete the module). Apply and confirm everything still works via the Container Apps URL.

---

## Where to go from here

With this stage complete, you have built and automated a production-grade Azure environment from scratch. The natural next areas to explore:

| Topic | What to learn |
|-------|--------------|
| AKS | When you need more control than Container Apps — Kubernetes on Azure |
| Azure Monitor + KQL | Query logs and metrics from the environment you built |
| Defender for Cloud | Security posture, recommendations, and threat detection |
| Landing Zones | Enterprise-scale governance for multi-subscription environments |
| Terraform modules registry | Reusable, versioned modules for platform teams |
