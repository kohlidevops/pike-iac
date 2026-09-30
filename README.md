# GitHub Actions → Azure OIDC Setup

Complete step-by-step setup for passwordless authentication between GitHub Actions and Azure using OpenID Connect (OIDC).

## Project Details

GitHub Repository: `kohlidevops/pike-iac`  
GitHub Branch: `main`  
Azure App Registration: `pike-github-actions`

GitHub Owner: `kohlidevops`  
GitHub Owner ID: `111111111`  
Repository ID: `22222222`

OIDC Issuer: `https://token.actions.githubusercontent.com`  
OIDC Audience: `api://AzureADTokenExchange`

OIDC Subject:

`repo:kohlidevops@111111111/pike-iac@22222222:ref:refs/heads/main`

---

## 1. Architecture

GitHub Repository  
→ GitHub Actions  
→ GitHub OIDC Token  
→ Microsoft Entra ID  
→ Federated Identity Credential  
→ `pike-github-actions` App Registration  
→ Azure Service Principal  
→ Azure Subscription  
→ Azure Resources

No Azure client secret is required.

---

## 2. Login to Azure

Run:

`az login`

Verify the subscription:

`az account show --query "{SubscriptionId:id,SubscriptionName:name,TenantId:tenantId}" -o table`

Record:

- Subscription ID
- Tenant ID

---

## 3. Create Azure App Registration

Create the App Registration:

`az ad app create --display-name "pike-github-actions"`

Get the App ID and Object ID:

`az ad app list --display-name "pike-github-actions" --query "[].{AppId:appId,ObjectId:id,DisplayName:displayName}" -o table`

Important:

- `AppId` = Application (client) ID = used as `AZURE_CLIENT_ID`
- `ObjectId` = Application object ID = used with `az ad app federated-credential` commands

If multiple App Registrations have the same display name, use the App Registration whose `AppId` matches the GitHub `AZURE_CLIENT_ID`.

---

## 4. Create Service Principal

Run:

`az ad sp create --id <APPLICATION-CLIENT-ID>`

Replace `<APPLICATION-CLIENT-ID>` with the App Registration `AppId`.

---

## 5. Assign Azure Permissions

For the initial IaC/OIDC setup, if GitHub Actions needs to create Resource Groups and Azure resources, assign Contributor at subscription scope:

`az role assignment create --assignee <APPLICATION-CLIENT-ID> --role "Contributor" --scope "/subscriptions/<SUBSCRIPTION-ID>"`

Replace:

- `<APPLICATION-CLIENT-ID>` with the App Registration client ID
- `<SUBSCRIPTION-ID>` with the Azure subscription ID

Contributor can manage Azure resources and create Resource Groups.

Contributor does not automatically allow creation of Azure RBAC role assignments. If Bicep later creates RBAC role assignments or Managed Identity permissions, additional permissions may be required.

Do not grant Owner unnecessarily.

---

## 6. Configure GitHub Secrets

Go to:

GitHub → `kohlidevops/pike-iac` → Settings → Secrets and variables → Actions

Create these repository secrets:

- `AZURE_CLIENT_ID`
- `AZURE_TENANT_ID`
- `AZURE_SUBSCRIPTION_ID`

Values:

- `AZURE_CLIENT_ID` = Application (client) ID of `pike-github-actions`
- `AZURE_TENANT_ID` = Azure Tenant ID
- `AZURE_SUBSCRIPTION_ID` = Azure Subscription ID

Do NOT create:

`AZURE_CLIENT_SECRET`

OIDC removes the need for a long-lived Azure client secret.

---

## 7. Create OIDC Debug Workflow

Create this file:

`.github/workflows/oidc-debug.yml`

Use the following workflow:

```text
name: OIDC Debug

on:
  workflow_dispatch:

permissions:
  id-token: write
  contents: read

jobs:
  debug:
    runs-on: ubuntu-latest

    steps:
      - name: Get OIDC claims
        shell: bash
        run: |
          RESPONSE=$(curl -sSf \
            -H "Authorization: bearer $ACTIONS_ID_TOKEN_REQUEST_TOKEN" \
            "$ACTIONS_ID_TOKEN_REQUEST_URL")

          TOKEN=$(echo "$RESPONSE" | jq -r '.value')

          PAYLOAD=$(echo "$TOKEN" | cut -d '.' -f 2)

          case $((${#PAYLOAD} % 4)) in
            2) PAYLOAD="${PAYLOAD}==" ;;
            3) PAYLOAD="${PAYLOAD}=" ;;
          esac

          echo "$PAYLOAD" | base64 -d 2>/dev/null | jq '{
            sub,
            repository,
            repository_id,
            repository_owner,
            repository_owner_id,
            ref,
            ref_type,
            aud,
            iss
          }'
