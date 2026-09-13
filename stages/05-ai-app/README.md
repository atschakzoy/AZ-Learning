# Stage 5 — The AI Application

> **Project milestone:** A simple application that sends a prompt to Azure OpenAI and returns the response runs locally. The Azure OpenAI resource is provisioned via Terraform as an extension to the existing foundation infra.

---

## What you'll build this stage

This stage introduces the workload. The app is intentionally minimal — a single HTTP endpoint that accepts a prompt and returns an Azure OpenAI completion. The complexity will come from the infrastructure around it in later stages.

```
project/
├── app/
│   └── api/                     ← simple prompt → response API (Python or Node)
└── infra/
    └── terraform/
        ├── main.tf               ← extended with Azure OpenAI resource
        └── modules/
            └── openai/           ← new module
```

---

## What to cover

### Azure OpenAI
- What Azure OpenAI is vs the public OpenAI API (same models, private endpoint, compliance boundary)
- Creating an Azure OpenAI resource and deploying a model (e.g. `gpt-4o-mini`)
- Authentication: API key vs Managed Identity (prefer Managed Identity)
- Quotas and model availability by region

### App concepts (minimal — focus stays on Azure)
- What the app does: POST /chat → Azure OpenAI → response
- Running locally with a `.env` file holding the endpoint and key
- Why you should not hardcode credentials — Key Vault integration preview

---

## Project Step

1. Add `azurerm_cognitive_account` (kind = `OpenAI`) to your Terraform in a new `modules/openai/` module. Deploy via your pipeline.
2. Deploy a `gpt-4o-mini` model using `azurerm_cognitive_deployment`.
3. Build the minimal app — a single endpoint that calls the Azure OpenAI REST API.
4. Run the app locally using the Azure OpenAI endpoint and API key from the Portal.
5. Store the API key in Key Vault (already provisioned). Update the app to fetch the secret from Key Vault at startup instead of reading it from `.env`.

---

**Next**: Stage 6 — host the app on Azure App Service. Extend Terraform to provision the App Service Plan and App Service. Grant it a Managed Identity so it can read from Key Vault without any credentials.
