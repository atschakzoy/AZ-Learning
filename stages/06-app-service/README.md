# Stage 6 — App Service

> **Project milestone:** The AI app runs on Azure App Service. The App Service and its Managed Identity are provisioned via Terraform. The app reads secrets from Key Vault using its Managed Identity — no credentials stored anywhere.

---

## What you'll build this stage

```
project/
└── infra/
    └── terraform/
        └── modules/
            └── app-service/     ← new: App Service Plan + App Service + Managed Identity
```

---

## What to cover

### App Service
- App Service Plans: tiers, OS (Linux vs Windows), scaling
- App Settings vs Connection Strings (environment variables for the app)
- Deployment methods: Zip deploy, GitHub Actions deploy task, deployment slots
- Managed Identity for App Service — system-assigned vs user-assigned

### Managed Identity + Key Vault
- How Managed Identity eliminates credentials: the app gets an OIDC token from Azure AD automatically
- Granting the App Service's identity `Key Vault Secrets User` on the Key Vault
- The app uses the Azure SDK's `DefaultAzureCredential` — works locally (developer login) and on App Service (Managed Identity) without code changes

---

## Project Step

1. Add `azurerm_service_plan` and `azurerm_linux_web_app` to Terraform in a new `modules/app-service/` module.
2. Enable a **system-assigned Managed Identity** on the App Service.
3. Grant the App Service's Managed Identity `Key Vault Secrets User` on the Key Vault (already in Terraform — add a role assignment).
4. Grant `Cognitive Services OpenAI User` on the Azure OpenAI resource to the same identity.
5. Update the app to use `DefaultAzureCredential` instead of an API key — it will use Managed Identity in Azure, developer CLI login locally.
6. Deploy the app to App Service. Confirm it is live at `<appname>.azurewebsites.net` and returns a response to a prompt.

---

**Next**: Stage 7 — add a CI/CD pipeline for the app itself (separate from the infra pipeline). Every push to `main` builds and deploys the latest app version automatically.
