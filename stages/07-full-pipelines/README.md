# Stage 7 — Full Pipelines & Multi-Environment

> **Project milestone:** The project has two independent pipelines — one for infrastructure, one for the app. Both support dev → prod promotion with approval gates. Secrets never appear in pipeline logs or variables.

---

## What you'll build this stage

```
.github/
└── workflows/
    ├── tf-plan.yml              ← from Stage 4, extended for environments
    ├── tf-apply.yml             ← from Stage 4, extended for environments
    ├── app-ci.yml               ← new: build + test on every PR
    └── app-deploy.yml           ← new: deploy app to dev → prod
```

---

## What to cover

### Pipeline separation
- Infra pipeline and app pipeline are independent — a code change does not re-apply Terraform, and an infra change does not redeploy the app
- When they should be coupled: if an infra change adds a new App Setting the app depends on, coordinate the rollout

### Environment promotion (dev → prod)
- Separate Terraform workspaces or var files per environment (`dev.tfvars`, `prod.tfvars`)
- Approval gate before prod: a human confirms the plan looks correct before apply runs
- App deployment slots for zero-downtime deployments (staging slot → swap to prod)

### Secrets in pipelines — the right way
- OIDC for Azure auth (already done in Stage 4) — no secrets for Azure
- Any remaining secrets (third-party APIs, etc.) go in GitHub Secrets or ADO Key Vault-linked variable groups
- Never echo secrets, never store them in pipeline outputs

### PR validation for the app
- Lint and format checks
- Unit tests (if any)
- Build verification — the artifact that would be deployed

---

## Project Step

1. Extend the Terraform workflows to support `dev` and `prod` environments using separate var files. The prod apply requires a manual approval.
2. Create `app-ci.yml`: triggers on every PR, runs any linting or tests, builds the deployment artifact.
3. Create `app-deploy.yml`: triggers on merge to `main`, deploys to the dev App Service automatically, then waits for approval before deploying to prod.
4. Add a deployment slot (`staging`) to the prod App Service. The pipeline deploys to staging first, then swaps to prod after approval.
5. Verify secrets never appear in pipeline logs — check the GitHub Actions run output for any accidental echoing.

---

**Next**: Stage 8 — add networking. Lock down the environment so Azure OpenAI and Key Vault are only reachable from within a VNet. The App Service accesses them over private endpoints, not the public internet.
