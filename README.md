# Azure Cloud Learning Path

A project-based curriculum for learning Azure and cloud infrastructure skills. Rather than studying topics in isolation, you build a single real-world project that grows more complete and production-grade at each stage.

---

## The Project

You will build an **Azure Platform Foundation** — the kind of baseline infrastructure a real platform team maintains. It starts as a few manually created resources and ends as a fully automated, pipeline-deployed, securely networked environment hosting a real workload.

**Stages 1–4** focus purely on infrastructure skills: learning the Azure platform, putting everything in source control, expressing it as code, and automating deployments.

**Stage 5 onward** introduces a simple AI application as the workload — something concrete for the infrastructure to host, enabling you to learn networking, containers, and deployment pipelines in context.

---

## Learning Path

| Stage | Focus | Project Milestone | Est. Time |
|-------|-------|-------------------|-----------|
| [1 — Azure Basics](stages/01-azure-basics/README.md) | Portal, CLI, Entra ID, RBAC | Foundation infra created manually, then via CLI | 3–4 weeks |
| [2 — Git & DevOps](stages/02-git-devops/README.md) | Git, GitHub, Azure DevOps | Scripts in source control, ADO wired up | 2–3 weeks |
| [3 — Infrastructure as Code](stages/03-iac/README.md) | Bicep, Terraform | Infra rewritten as Terraform with remote state | 3–4 weeks |
| [4 — CI/CD for Infra](stages/04-cicd-infra/README.md) | Bash, Pipelines | Infra auto-deployed by pipeline on every merge | 4–6 weeks |
| [5 — AI App](stages/05-ai-app/README.md) | Azure OpenAI | Simple app added, runs locally, OpenAI in Terraform | 6–8 weeks |
| [6 — App Service](stages/06-app-service/README.md) | App Service, IaC extension | App live on App Service | |
| [7 — Full Pipelines](stages/07-full-pipelines/README.md) | App CI/CD, environments | App + infra pipelines, dev → prod promotion | |
| [8 — Networking](stages/08-networking/README.md) | VNet, Private Endpoints | Backend services locked behind private network | |
| [9 — Containers](stages/09-containers/README.md) | Docker, ACR, Container Apps | App containerized, App Service replaced | |

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

## Curriculum Detail

What you will learn at each stage. Each topic links to the stage README for exercises and the project step.

### Stage 1 — Azure Basics

#### 1.1 Azure Resource Hierarchy & Management
- Tenant → Management Groups → Subscriptions → Resource Groups → Resources
- Naming conventions and tagging strategies
- Resource locking and policies (Azure Policy)
- Cost management and budgets (Azure Cost Management)
- Azure regions, availability zones, and paired regions

#### 1.2 Entra ID (formerly Azure AD)
- What Entra ID is and why it exists (cloud identity provider)
- Users, Groups, Service Principals, and Managed Identities
- Conditional Access basics
- Multi-Factor Authentication (MFA)

#### 1.3 Authorization — Azure RBAC
- Role-Based Access Control model (who, what, where)
- Built-in roles: Owner, Contributor, Reader, and domain-specific roles
- Role assignment scope (management group, subscription, resource group, resource)
- Principle of least privilege
- Azure Policy vs RBAC: when to use each

#### 1.4 Azure CLI & Azure Portal
- Installing and configuring `az` CLI
- Authentication: `az login`, service principal login
- Core commands: `az group`, `az resource`, `az storage`, `az keyvault` etc.
- Output formats: JSON, table, TSV; using `--query` (JMESPath)
- Azure Cloud Shell
- Navigating the Azure Portal effectively
- Azure PowerShell module (`Az`) as an alternative

#### 1.5 Core Azure Services (Awareness)
- **Compute**: Virtual Machines, App Service, Azure Functions, Container Apps
- **Storage**: Blob, File, Queue, Table storage; storage tiers
- **Networking**: VNet, Subnet, NSG, Azure Firewall, Load Balancer, Application Gateway
- **Databases**: Azure SQL, Cosmos DB, PostgreSQL Flexible Server
- **Monitoring**: Azure Monitor, Log Analytics, Application Insights, Alerts
- **Security**: Key Vault (secrets, keys, certificates), Defender for Cloud

#### 1.6 Recommended Certifications
- [AZ-900: Azure Fundamentals](https://learn.microsoft.com/en-us/credentials/certifications/azure-fundamentals/) — first milestone

---

### Stage 2 — Git & DevOps

#### 2.1 Git & Source Control
- Git fundamentals: init, clone, add, commit, push, pull
- Branching strategies: feature branches, GitFlow, trunk-based development
- Merging vs rebasing
- Pull requests and code review workflow
- `.gitignore` and handling secrets in repos
- Resolving merge conflicts

#### 2.2 GitHub
- Repository management, Issues, Projects
- Pull request workflows and branch protection rules
- GitHub Actions: workflow basics (triggers, jobs, steps)
- GitHub Packages and container registry (GHCR)
- Secrets and environment variables in GitHub Actions
- GitHub CLI (`gh`)

#### 2.3 Azure DevOps
- Organization → Project → Repos → Pipelines → Boards structure
- Azure Repos (Git-based, same concepts as GitHub)
- Azure Boards: work items, sprints, backlogs
- Azure Pipelines: YAML-based pipelines, agents, stages, jobs
- Service connections for deploying to Azure
- Comparison with GitHub (when to use which)

#### 2.4 Package & Dependency Management
- Understanding package managers: `npm`, `pip`, `nuget`, `apt`
- Why dependency pinning and lock files matter
- Security scanning for dependencies (Dependabot, Renovate)

---

### Stage 3 — Infrastructure as Code (IaC)

#### 3.1 IaC Concepts
- Why IaC? Repeatability, drift prevention, auditability
- Declarative vs imperative IaC
- Idempotency
- State management concepts

#### 3.2 Bicep
- Bicep syntax: parameters, variables, resources, outputs, modules
- Deploying: `az deployment group/sub/mg create`
- What-if deployments
- Bicep modules and module registry
- Linting with `az bicep lint`
- Converting ARM templates to Bicep

#### 3.3 Terraform
- HCL syntax: providers, resources, data sources, variables, outputs, locals
- Terraform workflow: `init → plan → apply → destroy`
- State files and remote state (Azure Blob backend)
- Modules: writing and consuming from the Terraform Registry
- `terraform fmt`, `terraform validate`, `tflint`
- AzureRM provider and AzAPI provider
- Terraform vs Bicep: when to choose each

---

### Stage 4 — CI/CD & Automation

#### 4.1 Shell Scripting (Bash)
- Variables, conditionals, loops, functions
- Error handling: `set -euo pipefail`
- Working with files and processes
- String manipulation and text processing (`grep`, `awk`, `sed`, `jq`)
- Environment variables and `.env` files
- Writing maintainable scripts

#### 4.2 PowerShell
- PowerShell vs Bash: when to use which
- Cmdlets, pipelines, objects (vs text streams in Bash)
- Variables, loops, conditionals, functions
- Error handling: `try/catch`, `$ErrorActionPreference`
- Az PowerShell module for Azure automation

#### 4.3 CI/CD Pipelines for IaC
- CI: linting, validation, security scanning (tfsec, checkov, PSRule for Azure)
- CD: deploying Bicep/Terraform via GitHub Actions or Azure Pipelines
- Environment promotion: dev → staging → prod
- Pull request validation: plan/what-if as PR checks
- Handling secrets in pipelines: Key Vault integration, OIDC/Workload Identity Federation
- Approval gates for production deployments
- Drift detection: scheduled pipeline runs

#### 4.4 Containers & Docker Basics
- What containers are and why they matter
- Dockerfile: build an image, layers, caching
- Core commands: `build`, `run`, `push`, `pull`, `exec`
- Container registries: Docker Hub, Azure Container Registry (ACR)
- Docker Compose for local multi-container development

#### 4.5 Recommended Certifications
- [AZ-104: Azure Administrator Associate](https://learn.microsoft.com/en-us/credentials/certifications/azure-administrator/)

---

### Stage 5 — Advanced Skills

#### 5.1 Kubernetes & AKS
- Kubernetes concepts: Pods, Deployments, Services, ConfigMaps, Secrets, Namespaces
- `kubectl` basics
- Azure Kubernetes Service (AKS): creating and managing clusters
- Helm charts: installing, writing, and templating
- Ingress controllers and cert-manager
- AKS-specific: Managed Identity integration, ACR pull access, Azure CNI/Cilium networking

#### 5.2 Networking Deep Dive
- Hub-and-spoke topology
- VNet peering and Azure Virtual WAN
- Private Endpoints and Private DNS Zones
- Azure Firewall and routing (UDRs)
- VPN Gateway and ExpressRoute (concepts)
- Network security: NSG flow logs, DDoS protection

#### 5.3 Security & Compliance
- Microsoft Defender for Cloud: secure score, recommendations
- Azure Security Benchmark and MCSB
- Key Vault best practices: access policies vs RBAC, soft delete, purge protection
- Workload Identity Federation (OIDC) — eliminating static credentials
- Security scanning: tfsec, Checkov, Microsoft Defender for DevOps
- Just-in-Time (JIT) VM access
- Privileged Identity Management (PIM) for elevated access

#### 5.4 Observability & Site Reliability
- Azure Monitor: metrics, logs, dashboards
- Log Analytics KQL (Kusto Query Language) basics
- Application Insights: distributed tracing, dependency maps
- Alerting: action groups, alert rules, smart detection
- Azure Service Health and resource health
- Runbooks in Azure Automation

#### 5.5 Platform Engineering Concepts
- Landing Zones: Azure Landing Zone (ALZ) accelerator
- Enterprise-scale governance (Management Group hierarchy, policies at scale)
- GitOps principles (Flux, ArgoCD awareness)
- Internal Developer Platforms (IDP): Backstage, Port
- Cost optimization: rightsizing, reserved instances, spot VMs, Azure Advisor

#### 5.6 Recommended Certifications
- [AZ-400: DevOps Engineer Expert](https://learn.microsoft.com/en-us/credentials/certifications/devops-engineer/)
- [AZ-305: Azure Solutions Architect Expert](https://learn.microsoft.com/en-us/credentials/certifications/azure-solutions-architect/)

---

## Learning Resources

| Resource | Type | Notes |
|----------|------|-------|
| [Microsoft Learn](https://learn.microsoft.com/en-us/azure/) | Free, self-paced | Official, follows cert paths |
| [Azure Docs](https://docs.microsoft.com/en-us/azure/) | Reference | Always up to date |
| [A Cloud Guru / Pluralsight](https://acloudguru.com/) | Video course | Good for structured learning |
| [John Savill's YouTube](https://www.youtube.com/@NTFAQGuy) | Free video | Excellent Azure deep dives |
| [AzAdvertizer](https://www.azadvertizer.net/) | Reference tool | RBAC roles, policies, built-ins |
| [Azure Architecture Center](https://learn.microsoft.com/en-us/azure/architecture/) | Reference | Patterns and best practices |
| [Terraform AzureRM docs](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs) | Reference | Terraform provider reference |
| [Bicep playground](https://bicepdemo.z22.web.core.windows.net/) | Tool | Live Bicep-to-ARM conversion |

---

## Suggested Milestone Projects

| Project | Skills Practiced |
|---------|-----------------|
| Deploy a static website to Azure Blob Storage + CDN via CLI | Azure CLI, Storage, Networking |
| Provision a VNet + VM using Bicep with parameterized environments | Bicep, IaC concepts |
| Mirror the same infra in Terraform with remote state in Azure Blob | Terraform, state management |
| Build a GitHub Actions pipeline that lints and deploys Bicep to dev/prod | CI/CD, IaC, Secrets, OIDC |
| Deploy a containerized app to Azure Container Apps via pipeline | Docker, ACR, CI/CD, Container Apps |
| Set up a Log Analytics workspace and write KQL queries for a deployed resource | Monitoring, KQL |
| Implement RBAC and Key Vault for a multi-environment setup | RBAC, Security, Entra ID |

---

## Notes & Reference Files

- [AZ-Notes/Cli-Portal.md](AZ-Notes/Cli-Portal.md) — Azure CLI & Portal: install, auth, core commands, JMESPath, Cloud Shell, PowerShell
- [Yall-Notes/IT-Notes.md](Yall-Notes/IT-Notes.md) — General IT: Homebrew, terminal, shell, Zsh vs Bash
