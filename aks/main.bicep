// pike-platform :: modules/aks
// Wraps AVM's managed-cluster (AKS) module. Deploys into a subnet produced
// by modules/network — never a standalone VNet. Workload Identity is on
// by default so pods authenticate to Azure via federated credentials,
// not stored secrets, matching the "no stored secrets" principle used in
// the CI workflow's OIDC auth.

@description('Workload name, e.g. "checkout".')
param workloadName string

@allowed(['dev', 'stg', 'prod'])
param environment string

param regionCode string = 'eastus2'
param instance string = '001'

@description('Subnet resource ID from modules/network output (subnetIds.<name>).')
param subnetId string

@description('Resource ID of the central Log Analytics workspace.')
param logAnalyticsWorkspaceId string

@description('Node VM size. Kept small by default — right-size per workload, not by copying prod.')
param nodeVmSize string = 'Standard_D2s_v5'

@description('Node count. Autoscaling is on; this is the floor, not a fixed size. Minimum 3 for system-pool HA.')
param minNodeCount int = 3

@description('Node count ceiling for autoscaling.')
param maxNodeCount int = 5

param costCenter string
param owner string
param applicationName string

var location = resourceGroup().location
var clusterName = 'aks-${workloadName}-${environment}-${regionCode}-${instance}'
var dnsPrefix = 'aks-${workloadName}-${environment}'

var mandatoryTags = {
  CostCenter: costCenter
  Environment: environment
  Owner: owner
  Application: applicationName
  ManagedBy: 'pike-platform'
}

module aks 'br/public:avm/res/container-service/managed-cluster:0.9.0' = {
  name: 'deploy-${clusterName}'
  params: {
    name: clusterName
    location: location
    tags: mandatoryTags
    dnsPrefix: dnsPrefix
    skuTier: environment == 'prod' ? 'Standard' : 'Free' // Standard SLA only where it matters
    managedIdentities: {
      systemAssigned: true
    }
    enableWorkloadIdentity: true
    enableOidcIssuerProfile: true
    disableLocalAccounts: true // Entra ID auth only — no local kubeconfig admin creds
    networkPlugin: 'azure'
    networkPolicy: 'azure' // segment pod-to-pod traffic within the cluster by default
    autoNodeOsUpgradeProfileUpgradeChannel: 'NodeImage' // auto-patch node OS images
    enableKeyvaultSecretsProvider: true // Secrets Store CSI driver — pods pull from Key Vault, not stored secrets
    enableSecretRotation: true
    enableContainerInsights: true
    monitoringWorkspaceResourceId: logAnalyticsWorkspaceId
    enableAzureDefender: true
    primaryAgentPoolProfiles: [
      {
        name: 'system'
        vmSize: nodeVmSize
        vnetSubnetResourceId: subnetId
        minCount: minNodeCount
        maxCount: maxNodeCount
        maxPods: 50
        type: 'VirtualMachineScaleSets'
        enableAutoScaling: true
        mode: 'System'
      }
    ]
    diagnosticSettings: [
      {
        workspaceResourceId: logAnalyticsWorkspaceId
        logCategoriesAndGroups: [
          { category: 'kube-audit-admin', enabled: true } // admin-action audit trail without full kube-audit request volume/cost
          { category: 'guard', enabled: true } // AAD/admission-controller audit log required alongside kube-audit-admin
          { category: 'cluster-autoscaler' }
          { category: 'kube-apiserver' }
          { category: 'kube-controller-manager' }
          { category: 'kube-scheduler' }
        ]
        metricCategories: [
          { category: 'AllMetrics' }
        ]
      }
    ]
    // Not configured — require decisions or facts this module can't supply yet:
    //  - aadProfile (Kubernetes-RBAC-via-Entra-ID): needs admin group object IDs,
    //    an RBAC design decision (AGENTS.md §3, CLAUDE.md escalation list).
    //  - authorizedIPRanges: needs real IP ranges; tenant network discovery is
    //    still pending (GAPS.md #0, #13).
    //  - maintenanceConfigurations: needs an agreed maintenance window, not yet decided.
    // See docs/ai-agent-access-model.md / GAPS.md for status; tracked as a PSRule
    // waiver in this module's PR rather than guessed at here.
    // Progressive delivery (Argo Rollouts / Flagger) and GitOps (ArgoCD / Flux)
    // are installed post-provisioning via the cluster's own bootstrap pipeline,
    // not baked into this module — keep infra provisioning and workload
    // bootstrap as separate, independently testable steps.
  }
}

output clusterId string = aks.outputs.resourceId
output clusterName string = clusterName
output oidcIssuerUrl string = aks.outputs.?oidcIssuerUrl ?? ''
