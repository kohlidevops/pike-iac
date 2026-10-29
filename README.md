# PikeHex Cloud Migration — Reusable Bicep Template

This repository uses subscription-scope orchestration with reusable modules. Resource configuration lives in `environments/*.bicepparam`; resource modules consume parameters and do not own environment-specific names, locations, SKUs, CIDRs, tags, or resource counts.

## Included dev resources

`environments/dev.bicepparam` contains one configured instance of each requested resource type:

- Resource group
- Virtual network
- Subnet (separate module)
- Network security group
- Route table
- Windows virtual machine and NIC
- Key Vault
- Storage account and blob container
- Azure SQL logical server and database

The arrays in `landingZones` are the configuration feed. To create more resources, add more objects to the corresponding array and ensure references such as VM-to-subnet and subnet-to-NSG/route-table use the intended names. The same modules are reused for each array item.

## Before deployment

1. Review `config/subscriptions.json`; it identifies the subscription used for each environment. The workflow currently selects the single `dev` entry.
2. Confirm resource names are available and unique:
   - Storage account names are globally unique, lowercase, and 3–24 characters.
   - Key Vault and SQL server names must also be globally unique.
3. Confirm the selected subscription has resource providers registered and sufficient permissions.
4. Configure `VM_ADMIN_PASSWORD` and `SQL_ADMIN_PASSWORD` as secure environment variables or GitHub Actions secrets. Do not commit passwords.
5. The sample Windows VM has no public IP and the NSG starts with no inbound rules. Add approved access paths before expecting remote administration.
6. The SQL server public network access is disabled in the sample configuration. Add private connectivity/firewall configuration if an application needs access.

## Local validation — PowerShell

Run from the repository root in PowerShell. These commands do not deploy resources until the deployment command is run.

```powershell
$ErrorActionPreference = 'Stop'

# Sign in and select the dev subscription from config/subscriptions.json.
az login
$dev = Get-Content 'config/subscriptions.json' -Raw |
  ConvertFrom-Json |
  Where-Object { $_.environment -eq 'dev' }

if (@($dev).Count -ne 1) {
  throw "Expected exactly one dev subscription entry."
}

az account set --subscription $dev.sub_id
if ($LASTEXITCODE -ne 0) { throw "Could not select dev subscription." }

# Prompt securely; passwords are not echoed to the terminal.
$vmSecure = Read-Host 'Windows VM admin password' -AsSecureString
$sqlSecure = Read-Host 'SQL admin password' -AsSecureString
$env:VM_ADMIN_PASSWORD = [System.Net.NetworkCredential]::new('', $vmSecure).Password
$env:SQL_ADMIN_PASSWORD = [System.Net.NetworkCredential]::new('', $sqlSecure).Password

# Build, lint, and validate parameter file.
az bicep build --file modules/main.bicep
if ($LASTEXITCODE -ne 0) { throw "Bicep build failed." }

az bicep lint --file modules/main.bicep
if ($LASTEXITCODE -ne 0) { throw "Bicep lint failed." }

az bicep build-params --file environments/dev.bicepparam
if ($LASTEXITCODE -ne 0) { throw "Parameter-file validation failed." }
```

## Preview before deployment

```powershell
az deployment sub what-if `
  --name 'pikehex-dev-whatif' `
  --location eastus `
  --template-file modules/main.bicep `
  --parameters environments/dev.bicepparam `
  --result-format FullResourcePayloads

if ($LASTEXITCODE -ne 0) { throw "What-If failed." }
```

Review the complete What-If output before continuing.

## Deploy

Only run after reviewing the preview and confirming that resource names, region, subscription, SKUs, and costs are acceptable.

```powershell
az deployment sub create `
  --name "pikehex-dev-$(Get-Date -Format yyyyMMddHHmmss)" `
  --location eastus `
  --template-file modules/main.bicep `
  --parameters environments/dev.bicepparam `
  --output table

if ($LASTEXITCODE -ne 0) { throw "Deployment failed." }
```

Clear local password variables after use:

```powershell
Remove-Item Env:VM_ADMIN_PASSWORD -ErrorAction SilentlyContinue
Remove-Item Env:SQL_ADMIN_PASSWORD -ErrorAction SilentlyContinue
```

## Git commands

From the repository root:

```powershell
git status
git add .
git commit -m "Refactor Bicep into reusable parameter-driven modules"
git push origin Dev
```

Change `Dev` if your working branch has a different name. Review `git status` before committing so generated ARM JSON or secrets are not accidentally committed.

## Subscription configuration

`config/subscriptions.json` is kept as the source for environment-to-subscription and environment-to-parameter-file mapping. The workflow currently deploys only the `dev` entry. Add other environments only after their parameter files are populated and reviewed.
