
##-----------------------------------------------------------------------------
## Locals declaration for determining the local variables
##-----------------------------------------------------------------------------
locals {
  name = var.custom_name != null ? var.custom_name : module.labels.id
}
