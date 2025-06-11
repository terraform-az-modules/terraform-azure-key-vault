##-----------------------------------------------------------------------------
## Naming convention
##-----------------------------------------------------------------------------
variable "custom_name" {
  type        = string
  default     = null
  description = "Override default naming convention"
}

variable "resource_position_prefix" {
  type        = bool
  default     = true
  description = <<EOT
Controls the placement of the resource type keyword (e.g., "vnet", "ddospp") in the resource name.

- If true, the keyword is prepended: "vnet-core-dev".
- If false, the keyword is appended: "core-dev-vnet".

This helps maintain naming consistency based on organizational preferences.
EOT
}

##-----------------------------------------------------------------------------
## Labels
##-----------------------------------------------------------------------------
variable "name" {
  type        = string
  default     = ""
  description = "Name  (e.g. `app` or `cluster`)."
}

variable "location" {
  type        = string
  default     = ""
  description = "The location/region where the key vault is created. Changing this forces a new resource to be created."
}

variable "environment" {
  type        = string
  default     = ""
  description = "Environment (e.g. `prod`, `dev`, `staging`)."
}

variable "managedby" {
  type        = string
  default     = "terraform-az-modules"
  description = "ManagedBy, eg 'terraform-az-modules'."
}

variable "label_order" {
  type        = list(any)
  default     = ["name", "environment", "location"]
  description = "Order of labels in the resource name. The order of labels in the resource name. The default order is ['name', 'environment', 'location']. You can change this to ['environment', 'name', 'location'] or any other order as per your requirements."
}

variable "repository" {
  type        = string
  default     = "https://github.com/terraform-az-modules/terraform-azure-key-vault"
  description = "Terraform current module repo"

  validation {
    # regex(...) fails if it cannot find a match
    condition     = can(regex("^https://", var.repository))
    error_message = "The module-repo value must be a valid Git repo link."
  }
}

variable "deployment_mode" {
  type        = string
  default     = "terraform"
  description = "Specifies how the infrastructure/resource is deployed"
}

variable "extra_tags" {
  type        = map(string)
  default     = null
  description = "Variable to pass extra tags."
}

##-----------------------------------------------------------------------------
## Global Variables
##-----------------------------------------------------------------------------
variable "enabled" {
  type        = bool
  default     = true
  description = "Set to false to prevent the module from creating any resources."
}

variable "resource_group_name" {
  type        = string
  description = "The name of the resource group in which to create the network security group."
}

##-----------------------------------------------------------------------------
## Key Vault
##-----------------------------------------------------------------------------
variable "enabled_for_disk_encryption" {
  type        = bool
  default     = true
  description = "Boolean flag to specify whether Azure Disk Encryption is permitted to retrieve secrets from the vault and unwrap keys. Defaults to false"
}

variable "purge_protection_enabled" {
  type        = bool
  default     = true
  description = "Boolean flag to specify whether purge protection is enabled for the Key Vault. Defaults to true. When enabled, the Key Vault cannot be permanently deleted until the purge protection is disabled."
}


variable "soft_delete_retention_days" {
  type        = number
  default     = 90
  description = "The number of days that items should be retained for once soft-deleted. The valid value can be between 7 and 90 days"
}

variable "enable_rbac_authorization" {
  type        = bool
  default     = true
  description = "(Optional) Boolean flag to specify whether Azure Key Vault uses Role Based Access Control (RBAC) for authorization of data actions."
}

variable "public_network_access_enabled" {
  type        = bool
  default     = false
  description = "(Optional) Whether public network access is allowed for this Key Vault. Defaults to true"
}

variable "sku_name" {
  type        = string
  default     = "standard"
  description = "The Name of the SKU used for this Key Vault. Possible values are standard and premium"
}

variable "enabled_for_deployment" {
  type        = bool
  default     = false
  description = "Boolean flag to specify whether Azure Virtual Machines are permitted to retrieve certificates stored as secrets from the key vault."
}

variable "enabled_for_template_deployment" {
  type        = bool
  default     = false
  description = "Boolean flag to specify whether Azure Resource Manager is permitted to retrieve secrets from the key vault."
}

variable "network_acls" {
  type = object({
    bypass                     = optional(string, "None"),
    default_action             = optional(string, "Deny"),
    ip_rules                   = optional(list(string)),
    virtual_network_subnet_ids = optional(list(string)),
  })
  default     = {}
  description = <<EOT
  Network ACLs for the Key Vault. The `bypass` attribute can be set to 'AzureServices' to allow Azure services to bypass the firewall.
  - The `default_action` attribute can be set to 'Allow' or 'Deny',
  - The `ip_rules` attribute is a list of IP addresses or CIDR ranges that are allowed access,
  - the `virtual_network_subnet_ids` attribute is a list of subnet IDs that are allowed access.
  EOT
}

variable "certificate_contacts" {
  type = list(object({
    email = string
    name  = optional(string)
    phone = optional(string)
  }))
  default     = []
  description = "Contact information to send notifications triggered by certificate lifetime events"
}

variable "enable_access_policies" {
  type        = bool
  default     = false
  description = "Boolean flag to specify whether access policies should be enabled for the Key Vault. Defaults to true."

}
variable "access_policies" {
  type = map(object({
    tenant_id               = string
    object_id               = string
    application_id          = optional(string, null)
    key_permissions         = optional(list(string), [])
    secret_permissions      = optional(list(string), [])
    certificate_permissions = optional(list(string), [])
    storage_permissions     = optional(list(string), [])
  }))
  default     = {}
  description = "List of access policies to be applied to the Key Vault. Each policy can specify permissions for keys, secrets, certificates, and storage."
}

##-----------------------------------------------------------------------------
## key Vault Secrets
##-----------------------------------------------------------------------------
variable "secrets" {
  type = list(object({
    name            = string
    value           = string
    content_type    = optional(string)
    not_before_date = optional(string)
    expiration_date = optional(string)
  }))
  default     = []
  description = "List of objects that represent the configuration of each secrect."
}

##-----------------------------------------------------------------------------
## key Vault Access Policies and Role assignments (RBAC)
##-----------------------------------------------------------------------------
variable "managed_hardware_security_module_enabled" {
  description = "Create a KeyVault Managed HSM resource if enabled. Changing this forces a new resource to be created."
  type        = bool
  default     = false
}

variable "reader_objects_ids" {
  description = "IDs of the objects that can read all keys, secrets and certificates."
  type = map(object({
    role_definition_name = string
    principal_id         = string
  }))
  default = {}
}

variable "admin_objects_ids" {
  description = "IDs of the objects that can do all operations on all keys, secrets and certificates."
  type        = list(string)
  default     = []
}

##-----------------------------------------------------------------------------
## Private Endpoint
##-----------------------------------------------------------------------------
variable "enable_private_endpoint" {
  type        = bool
  default     = true
  description = "Manages a Private Endpoint to Azure database for MySQL"
}

variable "existing_private_dns_zone" {
  type        = string
  default     = null
  description = "Name of the existing private DNS zone"
}

variable "existing_private_dns_zone_id" {
  description = "The ID of an existing private DNS zone."
  type        = string
  default     = null
}

variable "private_dns_zone_ids" {
  type        = string
  default     = null
  description = "The ID of the private DNS zone."
}
variable "subnet_id" {
  type        = string
  default     = ""
  description = "The resource ID of the subnet"
}

##-----------------------------------------------------------------------------
# Diagnostic Settings
##-----------------------------------------------------------------------------
variable "diagnostic_setting_enable" {
  type        = bool
  default     = false
  description = "Boolean flag to specify whether Diagnostic Settings should be enabled for the Key Vault. Defaults to false."
}

variable "storage_account_id" {
  type        = string
  default     = null
  description = "The ID of the Storage Account where logs should be sent."
}

variable "eventhub_name" {
  type        = string
  default     = null
  description = "Specifies the name of the Event Hub where Diagnostics Data should be sent."
}

variable "eventhub_authorization_rule_id" {
  type        = string
  default     = null
  description = "Specifies the ID of an Event Hub Namespace Authorization Rule used to send Diagnostics Data."
}

variable "log_analytics_workspace_id" {
  type        = string
  default     = null
  description = "The ID of the Log Analytics Workspace where logs should be sent."
}

variable "log_analytics_destination_type" {
  type        = string
  default     = "AzureDiagnostics"
  description = "Possible values are AzureDiagnostics and Dedicated, default to AzureDiagnostics. When set to Dedicated, logs sent to a Log Analytics workspace will go into resource specific tables, instead of the legacy AzureDiagnostics table."
}

variable "metric_enabled" {
  type        = bool
  default     = true
  description = "Boolean flag to specify whether Metrics should be enabled for the Key Vault. Defaults to true."
}

variable "kv_logs" {
  type = object({
    enabled        = bool
    category       = optional(list(string))
    category_group = optional(list(string))
  })

  default = {
    enabled        = true
    category_group = ["AllLogs"]
  }
  description = "values for Key Vault logs. The `category` attribute is optional and can be used to specify which categories of logs to enable. If not specified, all categories will be enabled."
}

##-----------------------------------------------------------------------------
# Key Vault HSM
##-----------------------------------------------------------------------------
variable "sku_name_hsm" {
  type        = string
  default     = "Standard_B1"
  description = "The Name of the SKU used for this Key Vault hsm."
}


