# Pike IaC - reusable Azure Bicep library

This starter library provisions a resource group at subscription scope, then deploys shared resource-group-scope modules for a VNet, subnet, NSG, Windows VM, Storage Account, Key Vault, Azure SQL server/database, and an optional configured RBAC assignment.

## Layout

- `eaas-azure-modules/main.bicep`: subscription-scope entry point; creates the target resource group.
- `eaas-azure-modules/modules/resource-group/workload.bicep`: composes resource-group-scoped modules.
- `eaas-azure-modules/modules/**`: reusable resource modules.
- `eaas-azure-modules/dev.bicepparam`: Dev-only configuration and environment-variable references for secrets.
- `.github/workflows/deploy-eaas-dev.yml`: OIDC, build, lint, Checkov, Gitleaks, subscription validate/What-If, and gated deployment.

## Required GitHub repository secrets

Keep these repository secrets configured:

- `AZURE_CLIENT_ID`
- `AZURE_TENANT_ID`
- `AZURE_SUBSCRIPTION_ID`
- `VM_ADMIN_PASSWORD`
- `SQL_ADMIN_PASSWORD`
- `RBAC_PRINCIPAL_ID`
- `RBAC_PRINCIPAL_TYPE`

`AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, and `AZURE_SUBSCRIPTION_ID` are used by `azure/login` with OIDC. No client secret is required. The VM and SQL passwords are passed as secure Bicep parameters via environment variables and must never be committed to files.

## Permissions

The Azure identity used by GitHub Actions needs permission to create/update resource groups at subscription scope and deploy resources into the target group. Because this template creates a role assignment, it also needs `Microsoft.Authorization/roleAssignments/write` at the target resource group (for example, a suitably scoped Role Based Access Control Administrator assignment). Follow your organization's least-privilege policy.

## Run locally on an authenticated Azure CLI session

Set the same environment variables (do not put secret values into the parameter file):

```bash
export VM_ADMIN_PASSWORD='REPLACE_WITH_SECURE_VALUE'
export SQL_ADMIN_PASSWORD='REPLACE_WITH_SECURE_VALUE'
export RBAC_PRINCIPAL_ID='ENTRA_OBJECT_ID'
export RBAC_PRINCIPAL_TYPE='ServicePrincipal'
```

Build and lint:

```bash
az bicep build --file eaas-azure-modules/main.bicep
az bicep lint --file eaas-azure-modules/main.bicep
```

Validate and preview. The location is the subscription deployment metadata location; the actual resource location comes from `dev.bicepparam`:

```bash
az deployment sub validate --location centralus --template-file eaas-azure-modules/main.bicep --parameters eaas-azure-modules/dev.bicepparam
az deployment sub what-if --location centralus --template-file eaas-azure-modules/main.bicep --parameters eaas-azure-modules/dev.bicepparam
```

Only after reviewing What-If, deploy:

```bash
az deployment sub create --location centralus --template-file eaas-azure-modules/main.bicep --parameters eaas-azure-modules/dev.bicepparam
```

## Security notes

- The NSG defaults to no inbound rules. Add only approved source-restricted rules in the environment parameter file when needed; do not expose RDP to `*`.
- SQL public network access is configurable. Dev currently sets it to `Enabled`, but no broad firewall rule is created. For production, prefer `Disabled` with private connectivity.
- Key Vault has RBAC authorization, purge protection, soft delete, and a deny-by-default network ACL. Access to its data plane must be granted separately according to policy.
- This template does not automatically write VM/SQL passwords into Key Vault. Secrets are supplied as secure deployment parameters from GitHub Actions secrets. If the SOW requires runtime Key Vault retrieval, implement that separately with least-privilege identity and secret access.
- The VM module creates a NIC without a public IP; inbound access is not exposed by this template.
- Verify VM size and SQL SKU availability/quotas in the selected region before deployment.
