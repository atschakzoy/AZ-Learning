# Azure Cloud Learning Path

A project-based curriculum for learning Azure and cloud infrastructure skills. Rather than studying topics in isolation, you build a single real-world project that grows more complete and production-grade at each stage.

---

## The Project

You will build an **Azure Platform Foundation** — the kind of baseline infrastructure a real platform team maintains. It starts as a few manually created resources and ends as a fully automated, pipeline-deployed, securely networked environment hosting a real workload.

**Stages 1–4** focus purely on infrastructure skills: learning the Azure platform, putting everything in source control, expressing it as code, and automating deployments.

**Stage 5 onward** introduces a simple AI application as the workload — something concrete for the infrastructure to host, enabling you to learn networking, containers, and deployment pipelines in context.

---

## Learning Path

| Stage | Focus | Project Milestone |
|-------|-------|-------------------|
| [1 — Azure Basics](stages/01-azure-basics/README.md) | Portal, CLI, Entra ID, RBAC | Foundation infra created manually, then via CLI |
| [2 — Git & DevOps](stages/02-git-devops/README.md) | Git, GitHub, Azure DevOps | Scripts in source control, ADO wired up |
| [3 — Infrastructure as Code](stages/03-iac/README.md) | Bicep, Terraform | Infra rewritten as Terraform with remote state |
| [4 — CI/CD for Infra](stages/04-cicd-infra/README.md) | Bash, Pipelines | Infra auto-deployed by pipeline on every merge |
| [5 — AI App](stages/05-ai-app/README.md) | Azure OpenAI | Simple app added, runs locally, OpenAI in Terraform |
| [6 — App Service](stages/06-app-service/README.md) | App Service, IaC extension | App live on App Service |
| [7 — Full Pipelines](stages/07-full-pipelines/README.md) | App CI/CD, environments | App + infra pipelines, dev → prod promotion |
| [8 — Networking](stages/08-networking/README.md) | VNet, Private Endpoints | Backend services locked behind private network |
| [9 — Containers](stages/09-containers/README.md) | Docker, ACR, Container Apps | App containerized, App Service replaced |

---

## Repository Structure

```
README.md                        ← you are here
project/
└── infra/                       ← the growing Terraform/Bicep codebase
stages/
├── 01-azure-basics/
│   ├── README.md                ← concepts + exercises + project step
│   └── exercises/               ← standalone scripts to practice
├── 02-git-devops/
├── 03-iac/
├── 04-cicd-infra/
├── 05-ai-app/
├── 06-app-service/
├── 07-full-pipelines/
├── 08-networking/
└── 09-containers/
```

Each stage `README.md` has three sections:
- **Concepts** — minimal theory to unblock the project step
- **Exercises** — short isolated drills to build tool familiarity
- **Project Step** — what to add or change in `project/` this stage

---

## The Foundation Infra (Stages 1–4)

The project builds and automates this set of resources:

| Resource | Purpose |
|----------|---------|
| Resource Group | Container for all project resources |
| Storage Account | General-purpose blob storage |
| Key Vault | Secret and certificate storage |
| Log Analytics Workspace | Centralized logging and monitoring |

These are simple enough to understand on day one, but real enough to appear in every production Azure environment.

---

## Resources

| Resource | Notes |
|----------|-------|
| [Microsoft Learn](https://learn.microsoft.com/en-us/azure/) | Official, follows cert paths |
| [John Savill's YouTube](https://www.youtube.com/@NTFAQGuy) | Excellent Azure deep dives |
| [AzAdvertizer](https://www.azadvertizer.net/) | RBAC roles and policy reference |
| [Azure Architecture Center](https://learn.microsoft.com/en-us/azure/architecture/) | Patterns and best practices |
| [Terraform AzureRM docs](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs) | Provider reference |
| [Bicep playground](https://bicepdemo.z22.web.core.windows.net/) | Live Bicep-to-ARM conversion |
