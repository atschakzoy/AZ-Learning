# project/infra

This folder contains the infrastructure code for the Azure Platform Foundation project. It grows across stages:

| Stage | What's added |
|-------|-------------|
| 2 | `scripts/` — CLI scripts |
| 3 | `bicep/` — Bicep templates (learning pass); `terraform/` — Terraform (kept) |
| 4+ | `terraform/` extended per stage |

The active source of truth from Stage 3 onward is `terraform/`.
