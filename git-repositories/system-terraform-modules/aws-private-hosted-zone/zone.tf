resource "aws_route53_zone" "main" {
  name = var.domain

  dynamic "vpc" {
    for_each = var.vpc_ids

    content {
      vpc_id = vpc.value
    }
  }

  comment = module.label.id
  tags = module.label.tags
}