# Stage 8 — Networking

> **Project milestone:** The environment is locked down. Key Vault and Azure OpenAI are accessible only via private endpoints inside a VNet. The App Service is VNet-integrated and routes all outbound traffic through the VNet. Public access to backend services is disabled.

---

## What you'll build this stage

```
project/
└── infra/
    └── terraform/
        └── modules/
            ├── networking/          ← new: VNet, subnets, NSGs
            ├── private-endpoints/   ← new: private endpoints + private DNS zones
            └── app-service/         ← updated: VNet integration added
```

---

## What to cover

### Azure Virtual Network (VNet)
- VNets, subnets, CIDR ranges
- Network Security Groups (NSGs): inbound/outbound rules, association to subnets
- Why subnet sizing matters — you cannot resize a subnet with resources in it

### Private Endpoints
- What a private endpoint is: a NIC inside your VNet with a private IP, connected to a PaaS service
- Private DNS Zones: required for DNS resolution to resolve the service name to the private IP instead of the public one
- How to link a Private DNS Zone to a VNet

### App Service VNet Integration
- Outbound VNet integration: App Service sends outbound traffic through a delegated subnet in your VNet
- This means the app can reach private endpoints inside the VNet
- `WEBSITE_VNET_ROUTE_ALL=1` — route all outbound traffic (including internet) through the VNet

### What to lock down in this project
- Key Vault: disable public access, add private endpoint
- Azure OpenAI: disable public access, add private endpoint
- App Service: add VNet integration (inbound can stay public for now — the app is user-facing)

---

## Project Step

1. Add `azurerm_virtual_network` and subnets to a new `modules/networking/` Terraform module:
   - `snet-private-endpoints` — for private endpoints (no delegation)
   - `snet-app-service-integration` — delegated to `Microsoft.Web/serverFarms`
2. Add private endpoints for Key Vault and Azure OpenAI. Add Private DNS Zones (`privatelink.vaultcore.azure.net`, `privatelink.openai.azure.com`) and link them to the VNet.
3. Disable public network access on Key Vault and Azure OpenAI.
4. Add VNet integration to the App Service using the `snet-app-service-integration` subnet.
5. Run `terraform plan` — review all the new resources before applying. After apply, confirm the app still works end-to-end (it must now route through the VNet to reach Key Vault and OpenAI).
6. Verify public access is blocked: try to reach the Key Vault data plane from your laptop (outside the VNet) — it should be denied.

---

**Next**: Stage 9 — containerize the app. Replace App Service with Azure Container Apps, which has better support for microservices patterns and scales to zero.
