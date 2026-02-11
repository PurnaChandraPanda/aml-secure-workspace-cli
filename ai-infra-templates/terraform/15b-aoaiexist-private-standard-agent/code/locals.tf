locals {
  foundry_rg_id    = "/subscriptions/${var.subscription_id}/resourceGroups/${var.resource_group_name}"
  aoaiResourceName = regex("([^/]+)$", var.existingAoaiResourceId)[0]
  aoaiEndpoint     = "https://${local.aoaiResourceName}.openai.azure.com"
}
