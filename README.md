# GitHub Actions → Azure OIDC Setup

## 1. Project Details

GitHub Repository:
kohlidevops/pike-iac

GitHub Branch:
main

Azure App Registration:
pike-github-actions

GitHub Owner:
kohlidevops

GitHub Owner ID:
111111111

GitHub Repository ID:
22222222

OIDC Issuer:
https://token.actions.githubusercontent.com

OIDC Audience:
api://AzureADTokenExchange

OIDC Subject:
repo:kohlidevops@111111111/pike-iac@22222222:ref:refs/heads/main


## 2. Architecture

GitHub Repository
    ↓
GitHub Actions
    ↓
GitHub OIDC Token
    ↓
Microsoft Entra ID
    ↓
Federated Identity Credential
    ↓
pike-github-actions App Registration
    ↓
Azure Service Principal
    ↓
Azure Subscription
    ↓
Azure Resources


## 3. Login to Azure

Run:

    az login

Verify the subscription:

    az account show --query "{SubscriptionId:id,SubscriptionName:name,TenantId:tenantId}" -o table

Record:

- Subscription ID
- Tenant ID


## 4. Create Azure App Registration

Create the App Registration:

    az ad app create --display-name "pike-github-actions"

Find the App Registration:

    az ad app list --display-name "pike-github-actions" --query "[].{AppId:appId,ObjectId:id,DisplayName:displayName}" -o table

Important:

AppId = Application (client) ID
ObjectId = Application object ID

The AppId will be used as:

    AZURE_CLIENT_ID

The ObjectId will be used when creating the federated credential.


## 5. If Multiple App Registrations Exist

Sometimes more than one App Registration may have the same display name.

Run:

    az ad app list --display-name "pike-github-actions" --query "[].{AppId:appId,ObjectId:id,DisplayName:displayName}" -o table

Check the GitHub repository secret:

    AZURE_CLIENT_ID

Find the Azure App Registration whose:

    AppId

matches:

    AZURE_CLIENT_ID

Use the ObjectId from that SAME App Registration.

Do not create the federated credential on a different App Registration.


## 6. Create Service Principal

Use the Application (client) ID:

    az ad sp create --id <APPLICATION-CLIENT-ID>

Replace:

    <APPLICATION-CLIENT-ID>

with the AppId of pike-github-actions.


## 7. Assign Azure Permissions

For the initial IaC/OIDC setup, assign Contributor at subscription scope:

    az role assignment create --assignee <APPLICATION-CLIENT-ID> --role "Contributor" --scope "/subscriptions/<SUBSCRIPTION-ID>"

Replace:

    <APPLICATION-CLIENT-ID>

with the App Registration AppId.

Replace:

    <SUBSCRIPTION-ID>

with the Azure Subscription ID.

Important:

Contributor allows the identity to manage Azure resources and create Resource Groups.

Contributor does NOT automatically allow creating Azure RBAC role assignments.

If Bicep later creates role assignments, additional permissions may be required.

Do not grant Owner unnecessarily.


## 8. Configure GitHub Secrets

Go to:

GitHub
→ kohlidevops/pike-iac
→ Settings
→ Secrets and variables
→ Actions

Create these Repository Secrets:

    AZURE_CLIENT_ID
    AZURE_TENANT_ID
    AZURE_SUBSCRIPTION_ID

Values:

    AZURE_CLIENT_ID
    = Application (client) ID of pike-github-actions

    AZURE_TENANT_ID
    = Azure Tenant ID

    AZURE_SUBSCRIPTION_ID
    = Azure Subscription ID

Do NOT create:

    AZURE_CLIENT_SECRET

OIDC does not require an Azure client secret.


## 9. Create OIDC Debug Workflow

Create:

    .github/workflows/oidc-debug.yml

Content:

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


## 10. Run OIDC Debug Workflow

Go to:

GitHub
→ kohlidevops/pike-iac
→ Actions
→ OIDC Debug
→ Run workflow

Select:

    main

Run the workflow.

Expected values:

    repository:
    kohlidevops/pike-iac

    repository_id:
    22222222

    repository_owner:
    kohlidevops

    repository_owner_id:
    111111111

    ref:
    refs/heads/main

    ref_type:
    branch

    aud:
    api://AzureADTokenExchange

    iss:
    https://token.actions.githubusercontent.com

    sub:
    repo:kohlidevops@111111111/pike-iac@22222222:ref:refs/heads/main

IMPORTANT:

Always use the exact "sub" value returned by the GitHub OIDC token.

Do not manually guess the subject.


## 11. Check Existing Federated Credentials

First identify the correct App Registration ObjectId.

Then run:

    az ad app federated-credential list --id <CORRECT-APP-OBJECT-ID> -o table

If the result is empty:

    []

then the correct App Registration does not have a federated credential.


## 12. Create Federated Identity Credential

Use the ObjectId of the CORRECT App Registration:

    az ad app federated-credential create \
      --id <CORRECT-APP-OBJECT-ID> \
      --parameters '{
        "name": "github-pike-iac-main",
        "issuer": "https://token.actions.githubusercontent.com",
        "subject": "repo:kohlidevops@111111111/pike-iac@22222222:ref:refs/heads/main",
        "audiences": [
          "api://AzureADTokenExchange"
        ]
      }'

Replace only:

    <CORRECT-APP-OBJECT-ID>

with the ObjectId of the App Registration whose AppId matches:

    AZURE_CLIENT_ID


## 13. Verify Federated Credential

Run:

    az ad app federated-credential list \
      --id <CORRECT-APP-OBJECT-ID> \
      -o table

Expected credential:

    github-pike-iac-main

For detailed verification:

    az ad app federated-credential list \
      --id <CORRECT-APP-OBJECT-ID> \
      -o json

Verify:

Issuer:

    https://token.actions.githubusercontent.com

Subject:

    repo:kohlidevops@111111111/pike-iac@22222222:ref:refs/heads/main

Audience:

    api://AzureADTokenExchange


## 14. Create Azure OIDC Test Workflow

Create:

    .github/workflows/azure-oidc-test.yml

Content:

    name: Azure OIDC Test

    on:
      workflow_dispatch:

    permissions:
      id-token: write
      contents: read

    jobs:
      azure-login:
        runs-on: ubuntu-latest

        steps:
          - name: Checkout
            uses: actions/checkout@v4

          - name: Azure Login with OIDC
            uses: azure/login@v3
            with:
              client-id: ${{ secrets.AZURE_CLIENT_ID }}
              tenant-id: ${{ secrets.AZURE_TENANT_ID }}
              subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}

          - name: Verify Azure Login
            uses: azure/cli@v2
            with:
              inlineScript: |
                az account show

          - name: List Resource Groups
            uses: azure/cli@v2
            with:
              inlineScript: |
                az group list \
                  --query "[].{Name:name,Location:location}" \
                  -o table


## 15. Run Azure OIDC Test

Go to:

GitHub
→ kohlidevops/pike-iac
→ Actions
→ Azure OIDC Test
→ Run workflow

Select:

    main

Run the workflow.

Expected:

    Attempting Azure CLI login by using OIDC...

Azure login should succeed.

Then:

    az account show

should display the Azure subscription.

And:

    az group list -o table

should list the Resource Groups.


## 16. Optional Resource Group Test

If the App Registration has Contributor permission:

Create a test Resource Group:

    az group create \
      --name rg-pike-oidc-test \
      --location centralindia

Verify:

    az group show \
      --name rg-pike-oidc-test \
      -o table

After testing, delete it:

    az group delete \
      --name rg-pike-oidc-test \
      --yes


## 17. Troubleshooting AADSTS70025

Error:

    AADSTS70025: The client has no configured federated identity credentials.

Check the following in order:

1. Get GitHub OIDC claims using oidc-debug.yml.

2. Get the GitHub client ID:

    AZURE_CLIENT_ID

3. Find the Azure App Registration:

    az ad app list \
      --display-name "pike-github-actions" \
      --query "[].{AppId:appId,ObjectId:id,DisplayName:displayName}" \
      -o table

4. Find the row where:

    AppId == AZURE_CLIENT_ID

5. Take the ObjectId from that SAME row.

6. Check federated credentials:

    az ad app federated-credential list \
      --id <CORRECT-APP-OBJECT-ID> \
      -o table

7. If no credential exists, create it.

8. Verify the issuer.

9. Verify the subject.

10. Verify the audience.

11. Run Azure OIDC Test again.


## 18. Most Common Mistake

Incorrect:

GitHub:

    AZURE_CLIENT_ID = App Registration A

Azure federated credential:

    App Registration B

This will fail.

Correct:

GitHub:

    AZURE_CLIENT_ID = App Registration A AppId

Azure federated credential:

    App Registration A ObjectId

The federated credential MUST belong to the same App Registration whose AppId is configured as AZURE_CLIENT_ID.


## 19. AppId vs ObjectId

AppId:

    Application (client) ID

Used as:

    AZURE_CLIENT_ID

ObjectId:

    Application object ID

Used with:

    az ad app federated-credential list

and:

    az ad app federated-credential create

Example:

    AppId    → AZURE_CLIENT_ID

    ObjectId → Federated Credential CLI


## 20. Azure Portal Federated Credential

The federated credential can also be created from:

Azure Portal
→ Microsoft Entra ID
→ App registrations
→ pike-github-actions
→ Certificates & secrets
→ Federated credentials
→ Add credential

Use:

Issuer:

    https://token.actions.githubusercontent.com

Organization:

    kohlidevops

Organization ID:

    111111111

Repository:

    pike-iac

Repository ID:

    22222222

Entity type:

    Branch

Branch:

    main

Subject:

    repo:kohlidevops@111111111/pike-iac@22222222:ref:refs/heads/main

Audience:

    api://AzureADTokenExchange

IMPORTANT:

The Azure Portal credential must be created on the SAME App Registration whose client ID is stored in GitHub as:

    AZURE_CLIENT_ID


## 21. Final Validation Checklist

GitHub:

    [x] Repository = kohlidevops/pike-iac
    [x] Branch = main
    [x] id-token: write
    [x] AZURE_CLIENT_ID configured
    [x] AZURE_TENANT_ID configured
    [x] AZURE_SUBSCRIPTION_ID configured
    [x] No AZURE_CLIENT_SECRET

OIDC:

    [x] Issuer = https://token.actions.githubusercontent.com
    [x] Audience = api://AzureADTokenExchange
    [x] Owner = kohlidevops
    [x] Owner ID = 111111111
    [x] Repository = pike-iac
    [x] Repository ID = 22222222
    [x] Branch = main
    [x] Subject verified from GitHub OIDC token

Azure:

    [x] App Registration = pike-github-actions
    [x] Correct AppId identified
    [x] Correct ObjectId identified
    [x] Service Principal created
    [x] Azure RBAC permissions assigned
    [x] Federated credential created
    [x] Federated credential attached to correct App Registration
    [x] Issuer matches
    [x] Subject matches exactly
    [x] Audience matches exactly

GitHub Actions:

    [x] Azure Login with OIDC succeeds
    [x] az account show succeeds
    [x] az group list succeeds
    [x] Azure resource creation test succeeds


## 22. Final OIDC Flow

GitHub Actions
    ↓
OIDC Token
    ↓
Issuer:
https://token.actions.githubusercontent.com
    ↓
Subject:
repo:kohlidevops@111111111/pike-iac@22222222:ref:refs/heads/main
    ↓
Microsoft Entra ID
    ↓
Federated Identity Credential
    ↓
pike-github-actions
    ↓
Service Principal
    ↓
Azure Subscription
    ↓
Azure Resources


## 23. Final Pike IaC Flow

Business Request
    ↓
Jira
    ↓
Jira Automation
    ↓
GitHub Actions
    ↓
GitHub OIDC
    ↓
Microsoft Entra ID
    ↓
Federated Identity
    ↓
Azure Authentication
    ↓
Bicep
    ↓
What-If
    ↓
Approval
    ↓
Azure Deployment
    ↓
Health Check
    ↓
Jira Update
    ↓
Requester Notification


## 24. Security Principle

GitHub Actions authenticates to Azure using OIDC.

No long-lived Azure client secret is stored in GitHub.

Authentication is based on:

    GitHub OIDC Token
        +
    Federated Identity Credential
        +
    Azure App Registration
        +
    Azure RBAC

This is the authentication foundation for the Pike GitHub Actions CI/CD and IaC self-service implementation.
