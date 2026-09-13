# Azure Cloud Learning Path — New Graduate Edition

A structured, progressive curriculum for new graduates entering the Azure Cloud space. Skills are ordered from foundational to advanced, with each stage building on the previous.

---

## Stages Overview

| Stage | Topic | Estimated Time |
|-------|-------|----------------|
| 1 | Azure Basics | 3–4 weeks |
| 2 | General IT Skills | 2–3 weeks |
| 3 | Infrastructure as Code (IaC) | 3–4 weeks |
| 4 | Intermediate Skills | 4–6 weeks |
| 5 | Advanced Skills | 6–8 weeks |

---

## Stage 1 — Azure Basics

> Goal: Understand the Azure platform structure, identity, access control, and how to interact with it.

### 1.1 Azure Resource Hierarchy & Management
- Tenant → Management Groups → Subscriptions → Resource Groups → Resources
- Naming conventions and tagging strategies
- Resource locking and policies (Azure Policy)
- Cost management and budgets (Azure Cost Management)
- Azure regions, availability zones, and paired regions

### 1.2 Entra ID (formerly Azure AD)
- What Entra ID is and why it exists (cloud identity provider)
- Users, Groups, Service Principals, and Managed Identities
- Conditional Access basics
- Multi-Factor Authentication (MFA)

### 1.3 Authorization — Azure RBAC
- Role-Based Access Control model (who, what, where)
- Built-in roles: Owner, Contributor, Reader, and domain-specific roles
- Role assignment scope (management group, subscription, resource group, resource)
- Principle of least privilege
- Azure Policy vs RBAC: when to use each

### 1.4 Azure CLI & Azure Portal
- Installing and configuring `az` CLI
- Authentication: `az login`, service principal login
- Core commands: `az group`, `az resource`, `az storage` etc.
- Output formats: JSON, table, TSV; using `--query` (JMESPath)
- Azure Cloud Shell
- Navigating the Azure Portal effectively
- Azure PowerShell module (`Az`) as an alternative

### 1.5 Core Azure Services (Awareness)
- **Compute**: Virtual Machines, App Service, Azure Functions, Container Apps
- **Storage**: Blob, File, Queue, Table storage; storage tiers
- **Networking**: VNet, Subnet, NSG, Azure Firewall, Load Balancer, Application Gateway
- **Databases**: Azure SQL, Cosmos DB, PostgreSQL Flexible Server
- **Monitoring**: Azure Monitor, Log Analytics, Application Insights, Alerts
- **Security**: Key Vault (secrets, keys, certificates), Defender for Cloud

### 1.6 Recommended Certifications
- [AZ-900: Azure Fundamentals](https://learn.microsoft.com/en-us/credentials/certifications/azure-fundamentals/) — first milestone

---

## Stage 2 — General IT Skills

> Goal: Be comfortable with source control, collaboration platforms, and basic developer workflows.

### 2.1 Git & Source Control
- Git fundamentals: init, clone, add, commit, push, pull
- Branching strategies: feature branches, GitFlow, trunk-based development
- Merging vs rebasing
- Pull requests and code review workflow
- `.gitignore` and handling secrets in repos
- Resolving merge conflicts

### 2.2 GitHub
- Repository management, Issues, Projects
- Pull request workflows and branch protection rules
- GitHub Actions: workflow basics (triggers, jobs, steps)
- GitHub Packages and container registry (GHCR)
- Secrets and environment variables in GitHub Actions
- GitHub CLI (`gh`)

### 2.3 Azure DevOps
- Organization → Project → Repos → Pipelines → Boards structure
- Azure Repos (Git-based, same concepts as GitHub)
- Azure Boards: work items, sprints, backlogs
- Azure Artifacts: package feeds (NuGet, npm, PyPI)
- Azure Pipelines: YAML-based pipelines, agents, stages, jobs
- Service connections for deploying to Azure
- Comparison with GitHub (when to use which)

### 2.4 Package & Dependency Management (Basics)
- Understanding package managers: `npm`, `pip`, `nuget`, `apt`
- Why dependency pinning and lock files matter
- Security scanning for dependencies (Dependabot, Renovate)

---

## Stage 3 — Infrastructure as Code (IaC)

> Goal: Provision and manage Azure resources declaratively, using code instead of clicking.

### 3.1 IaC Concepts
- Why IaC? Repeatability, drift prevention, auditability
- Declarative vs imperative IaC
- Idempotency
- State management concepts

### 3.2 Bicep
- Bicep syntax: parameters, variables, resources, outputs, modules
- Deploying: `az deployment group/sub/mg create`
- What-if deployments
- Bicep modules and module registry
- Linting with `az bicep lint`
- Converting ARM templates to Bicep
- Bicep vs ARM: when and why

### 3.3 Terraform
- HCL syntax: providers, resources, data sources, variables, outputs, locals
- Terraform workflow: `init → plan → apply → destroy`
- State files and remote state (Azure Blob backend)
- Modules: writing and consuming from the Terraform Registry
- `terraform fmt`, `terraform validate`, `tflint`
- AzureRM provider and AzAPI provider
- Terraform vs Bicep: when to choose each


---

## Stage 4 — Intermediate Skills

> Goal: Automate, script, and build end-to-end deployment workflows.

### 4.1 Shell Scripting (Bash)
- Variables, conditionals, loops, functions
- Error handling: `set -euo pipefail`
- Working with files and processes
- String manipulation and text processing (`grep`, `awk`, `sed`, `jq`)
- Environment variables and `.env` files
- Writing maintainable scripts (readability, comments for the non-obvious)

### 4.2 PowerShell
- PowerShell vs Bash: when to use which (cross-platform, Windows environments)
- Cmdlets, pipelines, objects (vs text streams in Bash)
- Variables, loops, conditionals, functions
- Error handling: `try/catch`, `$ErrorActionPreference`
- Az PowerShell module for Azure automation
- Running PowerShell in Azure Automation Accounts and GitHub Actions

### 4.3 CI/CD Pipelines for IaC
- CI: linting, validation, security scanning (tfsec, checkov, PSRule for Azure)
- CD: deploying Bicep/Terraform via GitHub Actions or Azure Pipelines
- Environment promotion: dev → staging → prod
- Pull request validation: plan/what-if as PR checks
- Handling secrets in pipelines: Key Vault integration, OIDC/Workload Identity Federation (no static secrets)
- Approval gates for production deployments
- Drift detection: scheduled pipeline runs

### 4.4 Containers & Docker Basics
- What containers are and why they matter
- Dockerfile: build an image, layers, caching
- Core commands: `build`, `run`, `push`, `pull`, `exec`
- Container registries: Docker Hub, Azure Container Registry (ACR)
- Docker Compose for local multi-container development

### 4.5 Recommended Certifications
- [AZ-104: Azure Administrator Associate](https://learn.microsoft.com/en-us/credentials/certifications/azure-administrator/)

---

## Stage 5 — Advanced Skills

> Goal: Operate at scale, secure workloads, and contribute to platform engineering.

### 5.1 Kubernetes & AKS
- Kubernetes concepts: Pods, Deployments, Services, ConfigMaps, Secrets, Namespaces
- `kubectl` basics
- Azure Kubernetes Service (AKS): creating and managing clusters
- Helm charts: installing, writing, and templating
- Ingress controllers and cert-manager
- AKS-specific: Managed Identity integration, ACR pull access, Azure CNI/Cilium networking

### 5.2 Networking Deep Dive
- Hub-and-spoke topology
- VNet peering and Azure Virtual WAN
- Private Endpoints and Private DNS Zones
- Azure Firewall and routing (UDRs)
- VPN Gateway and ExpressRoute (concepts)
- Network security: NSG flow logs, DDoS protection

### 5.3 Security & Compliance
- Microsoft Defender for Cloud: secure score, recommendations
- Azure Security Benchmark and MCSB
- Key Vault best practices: access policies vs RBAC, soft delete, purge protection
- Workload Identity Federation (OIDC) — eliminating static credentials
- Security scanning: tfsec, Checkov, Microsoft Defender for DevOps
- Just-in-Time (JIT) VM access
- Privileged Identity Management (PIM) for elevated access

### 5.4 Observability & Site Reliability
- Azure Monitor: metrics, logs, dashboards
- Log Analytics KQL (Kusto Query Language) basics
- Application Insights: distributed tracing, dependency maps
- Alerting: action groups, alert rules, smart detection
- Azure Service Health and resource health
- Runbooks in Azure Automation

### 5.5 Platform Engineering Concepts
- Landing Zones: Azure Landing Zone (ALZ) accelerator
- Enterprise-scale governance (Management Group hierarchy, policies at scale)
- GitOps principles (Flux, ArgoCD awareness)
- Internal Developer Platforms (IDP): Backstage, Port
- Cost optimization: rightsizing, reserved instances, spot VMs, Azure Advisor

### 5.6 Recommended Certifications
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
| [terraform-azurerm provider docs](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs) | Reference | Terraform AzureRM |
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

## Skill Files

- [01-azure-basics.md](01-azure-basics.md) — Azure fundamentals detail
- [02-it-basics.md](02-it-basics.md) — Git, GitHub, Azure DevOps detail
