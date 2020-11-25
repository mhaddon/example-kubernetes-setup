resource "aws_ecr_repository" "main" {
  count = length(var.repositories)

  name                 = "${module.label.id}-${element(var.repositories, count.index)}"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = module.label.tags
}