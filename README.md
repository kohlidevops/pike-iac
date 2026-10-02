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

```
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
```

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

---

# GitHub Self-Hosted Runner on Azure Ubuntu VM

This document describes how to configure an Azure Ubuntu 24.04 VM as a GitHub Actions self-hosted runner for the `kohlidevops/pike-iac` repository.

The runner can execute GitHub Actions workflows directly on the Azure VM and can be used for Pike Infrastructure-as-Code deployments using Bicep, Azure CLI, OIDC, and other DevOps tools.

---

## 1. Architecture

The basic architecture is:

    GitHub Repository
            |
            v
    GitHub Actions Workflow
            |
            v
    Azure Ubuntu VM
            |
            v
    GitHub Self-Hosted Runner
            |
            +---- Azure CLI
            |
            +---- Bicep
            |
            +---- Terraform
            |
            +---- kubectl
            |
            +---- Other DevOps Tools
            |
            v
    Azure Subscription
            |
            +---- Resource Groups
            +---- VNets
            +---- NSGs
            +---- VMs
            +---- Storage
            +---- Key Vault
            +---- SQL
            +---- Azure OpenAI
            +---- Monitoring
            +---- Other Azure Resources

The self-hosted runner is the execution machine.

It does NOT need to be inside the application VNet that it creates.

The runner only needs appropriate network connectivity and Azure permissions.

---

## 2. Current Runner Details

GitHub Repository:

    https://github.com/kohlidevops/pike-iac

Runner Name:

    pike-ubuntu-runner-01

Runner Operating System:

    Ubuntu 24.04

Runner Architecture:

    X64

Runner Labels:

    self-hosted
    Linux
    X64
    azure
    ubuntu-24.04
    pike

Runner Installation Directory:

    ~/actions-runner

Runner Group:

    Default

---

## 3. Azure VM Requirements

Use an existing Azure Ubuntu 24.04 VM.

Recommended minimum requirements for the initial Pike setup:

    OS:
    Ubuntu 24.04 LTS

    Architecture:
    x64

    Network:
    Outbound HTTPS access

    Port:
    TCP 443 outbound

The runner must be able to communicate with GitHub.

Test connectivity:

    curl -I https://github.com

    curl -I https://api.github.com

Both should return an HTTP response.

---

## 4. Update Ubuntu

SSH into the Azure VM.

Run:

    sudo apt update

    sudo apt upgrade -y

---

## 5. Install Required Packages

Install basic packages:

    sudo apt install -y \
      curl \
      wget \
      git \
      jq \
      unzip

Verify:

    git --version

    curl --version

    jq --version

---

## 6. Create GitHub Runner Directory

Create the runner directory:

    mkdir -p ~/actions-runner

Go into the directory:

    cd ~/actions-runner

---

## 7. Create the GitHub Self-Hosted Runner

Open the GitHub repository:

    https://github.com/kohlidevops/pike-iac

Navigate to:

    Settings
    → Actions
    → Runners

Click:

    New self-hosted runner

Select:

    Linux

Select:

    X64

GitHub will display the current runner download and configuration commands.

Use the current download command displayed by GitHub instead of manually using an old runner version.

The download command will look similar to:

    curl -o actions-runner.tar.gz -L <CURRENT-GITHUB-RUNNER-DOWNLOAD-URL>

Extract the runner:

    tar xzf actions-runner.tar.gz

---

## 8. Configure the Runner

From:

    ~/actions-runner

Run the configuration command provided by GitHub.

It will look similar to:

    ./config.sh --url https://github.com/kohlidevops/pike-iac --token <TEMPORARY-RUNNER-TOKEN>

The registration token is temporary.

Do not store the registration token in GitHub Secrets or documentation.

During configuration, use the following values.

Runner Group:

    Default

Runner Name:

    pike-ubuntu-runner-01

Additional Labels:

    azure,ubuntu-24.04,pike

Work Folder:

    _work

Expected configuration flow:

    Enter the name of the runner group to add this runner to: [press Enter for Default]
    → Press Enter

    Enter the name of runner:
    → pike-ubuntu-runner-01

    Enter any additional labels:
    → azure,ubuntu-24.04,pike

    Enter name of work folder: [press Enter for _work]
    → Press Enter

After configuration:

    √ Runner successfully added

---

## 9. Verify Runner Registration

Go to:

    GitHub
    → kohlidevops/pike-iac
    → Settings
    → Actions
    → Runners

The runner should appear as:

    pike-ubuntu-runner-01

Expected labels:

    self-hosted
    Linux
    X64
    azure
    ubuntu-24.04
    pike

---

## 10. Test Runner Manually

Before installing the runner as a service, test it interactively.

From:

    ~/actions-runner

Run:

    ./run.sh

Expected output should include:

    Connected to GitHub

and:

    Listening for Jobs

The runner is now waiting for GitHub Actions jobs.

Keep the terminal running while performing the initial test.

---

## 11. Create a Basic Self-Hosted Runner Test Workflow

Create:

    .github/workflows/self-hosted-runner-test.yml

Use:
```
    name: Self Hosted Runner Test

    on:
      workflow_dispatch:

    permissions:
      contents: read

    jobs:
      runner-test:
        runs-on: [self-hosted, linux, x64, pike]

        steps:
          - name: Checkout
            uses: actions/checkout@v4

          - name: Runner Information
            shell: bash
            run: |
              echo "Runner hostname:"
              hostname

              echo "Operating System:"
              cat /etc/os-release

              echo "Kernel:"
              uname -a

              echo "Architecture:"
              uname -m

              echo "Current User:"
              whoami

              echo "Working Directory:"
              pwd

          - name: Test Git
            shell: bash
            run: |
              git --version

          - name: Test Azure CLI
            shell: bash
            run: |
              az version
```
---

## 12. Run the Self-Hosted Runner Test

Go to:

    GitHub
    → Actions
    → Self Hosted Runner Test
    → Run workflow

Select:

    main

Run the workflow.

GitHub should assign the workflow to:

    pike-ubuntu-runner-01

The Azure VM should execute the workflow.

The workflow should display:

    hostname

    OS information

    uname information

    architecture

    current user

    working directory

    Git version

    Azure CLI version

---

## 13. Verify the Workflow Is Running on the Azure VM

On the Azure VM, run:

    hostname

Compare the hostname with the hostname printed by the GitHub Actions workflow.

If they match, the GitHub Actions job is executing directly on the Azure VM.

Architecture:

    GitHub Actions
          |
          v
    pike-ubuntu-runner-01
          |
          v
    Azure Ubuntu VM

---

## 14. Install Runner as a Linux Service

Once the manual test is successful, stop the interactive runner:

    Ctrl+C

Go to the runner directory:

    cd ~/actions-runner

Install the service:

    sudo ./svc.sh install

Expected behavior:

    Creating launch runner in /etc/systemd/system/

Start the service:

    sudo ./svc.sh start

Check the service:

    sudo ./svc.sh status

The service should show:

    active (running)

---

## 15. Verify the Runner Service

Run:

    sudo ./svc.sh status

You can also check systemd directly:

    sudo systemctl status actions.runner.kohlidevops-pike-iac.pike-ubuntu-runner-01.service

The exact service name is based on the repository and runner name.

The runner should be running as a system service.

---

## 16. Verify Runner From GitHub

Go to:

    GitHub
    → kohlidevops/pike-iac
    → Settings
    → Actions
    → Runners

Expected status:

    pike-ubuntu-runner-01
    Idle

Idle means the runner is online and ready to accept GitHub Actions jobs.

---

## 17. Reboot Test

A self-hosted runner should automatically start after the Azure VM reboots.

Run:

    sudo reboot

Wait for the VM to restart.

SSH into the VM again.

Check:

    sudo ./svc.sh status

The service should be:

    active (running)

Then check GitHub:

    Settings
    → Actions
    → Runners

The runner should return to:

    Idle

---

## 18. Azure OIDC Integration

The self-hosted runner can use the existing GitHub Actions → Azure OIDC configuration.

The authentication flow is:

    GitHub Actions
          |
          v
    Self-Hosted Runner
          |
          v
    GitHub OIDC Token
          |
          v
    Microsoft Entra ID
          |
          v
    Federated Identity Credential
          |
          v
    Azure App Registration
          |
          v
    Azure RBAC
          |
          v
    Azure Resources

No Azure client secret is required.

---

## 19. Existing Azure OIDC Configuration

GitHub Repository:

    kohlidevops/pike-iac

Branch:

    main

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

GitHub Secrets:

    AZURE_CLIENT_ID
    AZURE_TENANT_ID
    AZURE_SUBSCRIPTION_ID

No:

    AZURE_CLIENT_SECRET

---

## 20. Create Azure OIDC Test Workflow on Self-Hosted Runner

Create:

    .github/workflows/self-hosted-azure-oidc-test.yml

Use:

```
    name: Self Hosted Runner - Azure OIDC Test

    on:
      workflow_dispatch:

    permissions:
      id-token: write
      contents: read

    jobs:
      azure-test:
        runs-on: [self-hosted, linux, x64, pike]

        steps:
          - name: Checkout
            uses: actions/checkout@v4

          - name: Show Runner
            shell: bash
            run: |
              echo "Hostname:"
              hostname

              echo "Operating System:"
              cat /etc/os-release

              echo "Current User:"
              whoami

          - name: Azure Login with OIDC
            uses: azure/login@v3
            with:
              client-id: ${{ secrets.AZURE_CLIENT_ID }}
              tenant-id: ${{ secrets.AZURE_TENANT_ID }}
              subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}

          - name: Verify Azure Account
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

```
---

## 21. Run the Azure OIDC Test

Go to:

    GitHub
    → Actions
    → Self Hosted Runner - Azure OIDC Test
    → Run workflow

Select:

    main

Run the workflow.

Expected flow:

    GitHub Actions
          |
          v
    Azure Ubuntu Self-Hosted Runner
          |
          v
    azure/login
          |
          v
    GitHub OIDC
          |
          v
    Microsoft Entra ID
          |
          v
    Federated Credential
          |
          v
    Azure
          |
          v
    az account show
          |
          v
    az group list

---

## 22. Verify Azure Authentication

The workflow should successfully execute:

    az account show

and:

    az group list -o table

This proves that:

    GitHub Actions
          +
    Azure Self-Hosted Runner
          +
    GitHub OIDC
          +
    Azure Authentication

are working together.

---

## 23. Important Security Rules

Do NOT store an Azure client secret on the runner.

Do NOT run:

    az login

using a personal Azure account and leave the credentials stored on the VM.

Do NOT store:

    AZURE_CLIENT_SECRET

on the VM.

Use:

    GitHub OIDC
          +
    Federated Identity Credential
          +
    Azure RBAC

for GitHub-to-Azure authentication.

---

## 24. Runner VM Security

The self-hosted runner is a privileged deployment machine.

Recommended controls:

    [ ] Private GitHub repository

    [ ] Protected main branch

    [ ] Pull Request approval

    [ ] Required CI checks

    [ ] Restricted GitHub Actions permissions

    [ ] Least-privilege Azure RBAC

    [ ] No personal Azure credentials

    [ ] No long-lived Azure secrets

    [ ] Regular Ubuntu patching

    [ ] Restrict SSH access

    [ ] Use Azure NSG rules

    [ ] Use Azure Bastion or approved corporate access where applicable

    [ ] Monitor runner VM

    [ ] Monitor runner disk usage

    [ ] Monitor runner availability

    [ ] Remove unused runners

---

## 25. Runner Network Requirements

The runner generally needs outbound HTTPS connectivity to GitHub and Azure services.

Required:

    TCP 443 outbound

The runner does not need to expose a public inbound GitHub Actions port.

GitHub communicates with the runner through the runner's outbound connection.

Avoid opening unnecessary inbound ports.

For SSH administration, restrict TCP 22 to approved administration sources or use an approved management solution.

---

## 26. Runner Labels

Current labels:

    self-hosted
    Linux
    X64
    azure
    ubuntu-24.04
    pike

Workflows can target this runner using:

    runs-on: [self-hosted, linux, x64, pike]

This prevents the workflow from accidentally running on an unrelated runner.

---

## 27. Why Labels Are Important

Example:

    runs-on: [self-hosted, linux, x64, pike]

means the workflow requires a runner that has all matching labels.

This allows future Pike runners to be separated.

Example:

    pike-dev-runner

    pike-prod-runner

    pike-linux-runner

    pike-windows-runner

Production workflows should be deliberately restricted to the appropriate runner/environment.

---

## 28. Runner Service Commands

Go to:

    cd ~/actions-runner

Install:

    sudo ./svc.sh install

Start:

    sudo ./svc.sh start

Stop:

    sudo ./svc.sh stop

Restart:

    sudo ./svc.sh stop
    sudo ./svc.sh start

Status:

    sudo ./svc.sh status

Uninstall:

    sudo ./svc.sh uninstall

Do not uninstall the runner unless you intentionally want to remove the system service.

---

## 29. Runner Troubleshooting

Check service:

    sudo ./svc.sh status

Check systemd:

    sudo systemctl status actions.runner.kohlidevops-pike-iac.pike-ubuntu-runner-01.service

Check running processes:

    ps -ef | grep Runner

Check network:

    curl -I https://github.com

    curl -I https://api.github.com

Check disk:

    df -h

Check memory:

    free -h

Check CPU:

    nproc

Check OS:

    cat /etc/os-release

Check Azure CLI:

    az version

Check Git:

    git --version

---

## 30. Common Error: Service Not Found

Error:

    Failed to start actions.runner.kohlidevops-pike-iac.pike-ubuntu-runner-01.service:
    Unit ...service not found.

Cause:

The runner was registered but the systemd service was not installed.

Solution:

    cd ~/actions-runner

    sudo ./svc.sh install

    sudo ./svc.sh start

    sudo ./svc.sh status

---

## 31. Common Error: Runner Group Not Found

If configuration shows:

    Enter the name of the runner group to add this runner to:
    [press Enter for Default]

Press:

    Enter

Do not enter the runner name here.

Then GitHub will ask:

    Enter the name of runner:

Enter:

    pike-ubuntu-runner-01

Runner Group:

    Default

Runner Name:

    pike-ubuntu-runner-01

These are different values.

---

## 32. Common Error: Runner Offline

If GitHub shows:

    Offline

Check:

    sudo ./svc.sh status

Check network:

    curl -I https://github.com

Check the system log:

    sudo journalctl -u actions.runner.kohlidevops-pike-iac.pike-ubuntu-runner-01.service -n 100 --no-pager

Restart:

    sudo ./svc.sh stop

    sudo ./svc.sh start

---

## 33. Common Error: Runner Busy

If the runner shows:

    Busy

another workflow is currently executing on the runner.

Check:

    GitHub
    → Actions

Wait for the current workflow to complete.

For production, consider multiple runners or an autoscaling architecture instead of relying on one runner.

---

## 34. Common Error: Azure OIDC Login Failed

If:

    azure/login

fails with an OIDC error, verify:

    AZURE_CLIENT_ID

    AZURE_TENANT_ID

    AZURE_SUBSCRIPTION_ID

Also verify that the federated credential is configured on the SAME App Registration whose AppId is:

    AZURE_CLIENT_ID

Verify the federated credential:

    az ad app federated-credential list \
      --id <CORRECT-APP-OBJECT-ID> \
      -o table

Verify:

    Issuer:
    https://token.actions.githubusercontent.com

    Audience:
    api://AzureADTokenExchange

    Subject:
    repo:kohlidevops@111111111/pike-iac@22222222:ref:refs/heads/main

---

## 35. Pike Deployment Model

The self-hosted runner is the execution layer.

The actual Pike infrastructure is created by Bicep.

Example:

    Jira Request
          |
          v
    GitHub Actions
          |
          v
    Self-Hosted Runner
          |
          v
    Azure OIDC
          |
          v
    Bicep
          |
          v
    What-If
          |
          v
    Approval
          |
          v
    Azure Deployment
          |
          +---- Resource Group
          |
          +---- VNet
          |
          +---- Subnets
          |
          +---- NSGs
          |
          +---- Route Tables
          |
          +---- NAT Gateway
          |
          +---- VMs
          |
          +---- Storage
          |
          +---- Key Vault
          |
          +---- Azure SQL
          |
          +---- Azure OpenAI
          |
          +---- Monitoring

The runner itself does not need to be inside the application VNet.


## 36. Recommended Pike Repository Structure

    pike-iac/
    |
    +-- .github/
    |   |
    |   +-- workflows/
    |       |
    |       +-- self-hosted-runner-test.yml
    |       +-- self-hosted-azure-oidc-test.yml
    |       +-- deploy-dev.yml
    |       +-- deploy-test.yml
    |       +-- deploy-uat.yml
    |       +-- deploy-prod.yml
    |
    +-- bicep/
    |   |
    |   +-- modules/
    |   |   +-- vnet/
    |   |   +-- nsg/
    |   |   +-- vm/
    |   |   +-- storage/
    |   |   +-- keyvault/
    |   |   +-- sql/
    |   |   +-- azure-openai/
    |   |
    |   +-- environments/
    |       +-- dev/
    |       +-- test/
    |       +-- uat/
    |       +-- prod/
    |
    +-- docs/
    |
    +-- README.md


## 37. Recommended Deployment Flow

    Jira
      |
      v
    Request
      |
      v
    Jira Automation
      |
      v
    GitHub Actions
      |
      v
    Self-Hosted Runner
      |
      v
    Azure OIDC
      |
      v
    Bicep Lint
      |
      v
    Bicep Build
      |
      v
    What-If
      |
      v
    Approval
      |
      v
    Bicep Deployment
      |
      v
    Health Check
      |
      v
    Jira Update
      |
      v
    Requester Notification


## 38. Final Validation Checklist

Azure VM:

    [x] Ubuntu 24.04 installed

    [x] Network connectivity verified

    [x] Git installed

    [x] Curl installed

    [x] jq installed

    [x] Azure CLI installed

GitHub Runner:

    [x] Runner registered

    [x] Runner group = Default

    [x] Runner name = pike-ubuntu-runner-01

    [x] Linux label

    [x] X64 label

    [x] azure label

    [x] ubuntu-24.04 label

    [x] pike label

    [x] Runner connected to GitHub

    [x] Basic workflow tested

System Service:

    [x] Runner service installed

    [x] Runner service started

    [x] Runner status verified

    [x] VM reboot tested

    [x] Runner automatically reconnects

Azure:

    [x] Azure OIDC configured

    [x] Federated identity credential configured

    [x] GitHub Azure secrets configured

    [x] Azure login tested from self-hosted runner

    [x] Azure Resource Groups listed successfully


## 39. Final Architecture

    +-------------------------------------------------------+
    |                   GitHub Repository                   |
    |                                                       |
    |                 kohlidevops/pike-iac                  |
    +---------------------------+---------------------------+
                                |
                                v
                     +----------------------+
                     |    GitHub Actions    |
                     +----------+-----------+
                                |
                                v
              +-----------------------------------+
              | Azure Ubuntu 24.04 VM             |
              |                                   |
              | pike-ubuntu-runner-01             |
              |                                   |
              | GitHub Self-Hosted Runner         |
              +----------------+------------------+
                               |
                               | OIDC
                               v
                    +----------------------+
                    | Microsoft Entra ID   |
                    +----------+-----------+
                               |
                               v
                    +----------------------+
                    | Federated Credential  |
                    +----------+-----------+
                               |
                               v
                    +----------------------+
                    | Azure RBAC            |
                    +----------+-----------+
                               |
                               v
                    +----------------------+
                    | Azure Subscription    |
                    +----------+-----------+
                               |
                +--------------+--------------+
                |              |              |
                v              v              v
             DEV RG         UAT RG         PROD RG
                |              |              |
                v              v              v
             Azure          Azure          Azure
            Resources      Resources      Resources


## 40. Important Note

A single self-hosted runner is suitable for the initial Pike implementation and learning environment.

For a larger corporate production platform, consider:

    Multiple isolated runners

or:

    VM Scale Sets

or:

    AKS + GitHub Actions Runner Controller (ARC)

and use ephemeral runners where appropriate.

The initial Pike architecture can therefore start with:

    Azure Ubuntu VM
          +
    GitHub Self-Hosted Runner
          +
    GitHub OIDC
          +
    Bicep
          +
    Azure RBAC

and evolve to an autoscaling runner architecture later.
