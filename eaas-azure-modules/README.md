# Azure EaaS starter Bicep modules

Deploys into the **existing** resource group `rg-test-dev`, in **Central US**. It does not create or delete the resource group.

## Folder structure

```text
eaas-azure-modules/
├── main.bicep
├── dev.bicepparam
└── modules/
    ├── networking/network.bicep
    ├── storage/storageAccount.bicep
    ├── security/rbac.bicep
    ├── security/keyVault.bicep
    ├── compute/windowsVm.bicep
    ├── database/sqlServer.bicep
    └── apps/functionApp.bicep
```

## What this deploys

- RBAC role assignment at resource-group scope (Reader by default)
- VNet with VM subnet, NSG, and a delegated Function App integration subnet
- Storage Account
- Key Vault with RBAC authorization, soft delete and purge protection
- Windows Server 2025 Azure Edition VM with private IP only (no public IP)
- Azure SQL logical server and Basic database
- Windows Function App on the Consumption (`Y1`) plan plus its required Storage Account

## Important design notes

- **RBAC:** set `RBAC_PRINCIPAL_ID` to the Entra object ID for the intended principal. The default Reader role is intentionally least privilege. The deploying identity must have permission to create role assignments, such as Role Based Access Control Administrator or User Access Administrator at the target scope. set `RBAC_PRINCIPAL_TYPE` to `User`, `Group`, `ServicePrincipal`, or `ManagedIdentity` as appropriate.
- **Secrets:** passwords are read from environment variables; do not commit passwords to source control.
- **Function App:** this deploys the Function App host but not function code. Deploy your application package separately.
- **Function networking:** a delegated integration subnet is created, but the Function App is not attached to it. The selected classic Consumption (`Y1`) plan does not support the same VNet integration options as Premium/Flex Consumption. For private SQL connectivity, select a supported plan and design VNet integration plus SQL Private Endpoint and Private DNS. See Microsoft's [VNet integration documentation](https://learn.microsoft.com/en-us/azure/app-service/configure-vnet-integration-enable).
- **SQL access:** SQL public network access is enabled for this starter deployment, but no SQL firewall rule is added, so this alone does not grant client access. For production, prefer Private Endpoint + Private DNS and disable public access.
- **VM access:** there is no public IP and no internet-facing RDP rule. Use an approved access path such as Azure Bastion or VPN.
- **Windows image:** the module uses `MicrosoftWindowsServer:WindowsServer:2025-datacenter-azure-edition:latest`. Verify it is available in your subscription/region before deploying.
- **Names:** storage, Key Vault, SQL server, and Function App names are generated deterministically from the resource-group ID and prefix. If a global name collision occurs, change `prefix`.
- **Cost:** VM, SQL, storage, and hosting resources can incur charges. Confirm size/SKU availability and costs first.

## Commands (Bash / Azure Cloud Shell)

Run commands from the project root.

### 1. Sign in and select the subscription

```bash
az login
az account set --subscription "<SUBSCRIPTION_ID>"
az account show --query "{Subscription:name,Id:id,Tenant:tenantId}" -o table
```

### 2. Confirm the existing resource group

```bash
az group show --name rg-test-dev --query "{Name:name,Location:location}" -o table
```

### 3. Set deployment values

Use strong passwords that meet Azure policy:

```bash
export VM_ADMIN_PASSWORD='<STRONG_WINDOWS_ADMIN_PASSWORD>'
export SQL_ADMIN_PASSWORD='<STRONG_SQL_ADMIN_PASSWORD>'
export RBAC_PRINCIPAL_ID='<ENTRA_OBJECT_ID_OF_USER_GROUP_OR_SERVICE_PRINCIPAL>'
export RBAC_PRINCIPAL_TYPE='ServicePrincipal' # or User, Group, ManagedIdentity
```

`RBAC_PRINCIPAL_ID` must be an Entra object ID, not an app/client ID.

### 4. Check the Windows Server image

```bash
az vm image list \
  --location centralus \
  --publisher MicrosoftWindowsServer \
  --offer WindowsServer \
  --sku 2025-datacenter-azure-edition \
  --all \
  --query "[0].{Urn:urn,Version:version}" \
  -o table
```

If no image is returned, select a supported Windows Server SKU before deploying.

### 5. Build modules

```bash
az bicep build --file main.bicep
az bicep build --file modules/networking/network.bicep
az bicep build --file modules/storage/storageAccount.bicep
az bicep build --file modules/security/keyVault.bicep
az bicep build --file modules/security/rbac.bicep
az bicep build --file modules/compute/windowsVm.bicep
az bicep build --file modules/database/sqlServer.bicep
az bicep build --file modules/apps/functionApp.bicep
```

### 6. What-If (review before deploying)

```bash
az deployment group what-if \
  --name eaas-dev-whatif \
  --resource-group rg-test-dev \
  --template-file main.bicep \
  --parameters dev.bicepparam \
  --parameters vmAdminPassword="$VM_ADMIN_PASSWORD" sqlAdminPassword="$SQL_ADMIN_PASSWORD" rbacPrincipalId="$RBAC_PRINCIPAL_ID"
```

Review all proposed changes. This template should create resources; it should not delete the existing resource group.

### 7. Deploy

```bash
az deployment group create \
  --name eaas-dev-deployment \
  --resource-group rg-test-dev \
  --template-file main.bicep \
  --parameters dev.bicepparam \
  --parameters vmAdminPassword="$VM_ADMIN_PASSWORD" sqlAdminPassword="$SQL_ADMIN_PASSWORD" rbacPrincipalId="$RBAC_PRINCIPAL_ID"
```

### 8. Check deployment state and outputs

```bash
az deployment group show \
  --name eaas-dev-deployment \
  --resource-group rg-test-dev \
  --query "{State:properties.provisioningState,Outputs:properties.outputs}" \
  -o json
```

### 9. List resources

```bash
az resource list \
  --resource-group rg-test-dev \
  --query "[].{Name:name,Type:type,Location:location}" \
  -o table
```

### 10. Validate services

```bash
az vm list --resource-group rg-test-dev --show-details --query "[].{Name:name,PowerState:powerState,PrivateIPs:privateIps}" -o table
az sql server list --resource-group rg-test-dev --query "[].{Name:name,Location:location,PublicNetworkAccess:publicNetworkAccess}" -o table
az functionapp list --resource-group rg-test-dev --query "[].{Name:name,State:state,HostName:defaultHostName}" -o table
az keyvault list --resource-group rg-test-dev --query "[].{Name:name,Location:location}" -o table
az storage account list --resource-group rg-test-dev --query "[].{Name:name,Location:location,Kind:kind}" -o table
```

Do not delete the existing `rg-test-dev` resource group as cleanup; it may contain other resources.
