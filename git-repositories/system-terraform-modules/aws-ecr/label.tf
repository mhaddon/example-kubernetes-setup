module "label" {
  source      = "git::https://github.com/cloudposse/terraform-null-label.git?ref=tags/0.21.0"
  namespace   = var.namespace
  environment = var.environment

  tags = {
    "Environment" = var.environment,
    "Namespace"   = var.namespace,
    "Stage"       = var.stage
  }
}
